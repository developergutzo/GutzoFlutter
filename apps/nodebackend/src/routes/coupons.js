import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate, optionalAuth } from '../middleware/auth.js';

const router = express.Router();

// GET ALL ACTIVE COUPONS
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const { vendor_id } = req.query;

  let query = supabaseAdmin
    .from('coupons')
    .select('id, code, name, description, discount_type, discount_value, minimum_order, maximum_discount, valid_until')
    .eq('is_active', true)
    .or('valid_until.is.null,valid_until.gte.' + new Date().toISOString().split('T')[0])
    .order('created_at', { ascending: false });

  if (vendor_id) {
    query = query.or(`vendor_id.is.null,vendor_id.eq.${vendor_id}`);
  } else {
    query = query.is('vendor_id', null);
  }

  const { data, error } = await query;
  if (error) throw new ApiError(500, 'Failed to fetch coupons');

  successResponse(res, data);
}));

// VALIDATE/APPLY COUPON
router.post('/apply', authenticate, asyncHandler(async (req, res) => {
  const { code, vendor_id, order_total } = req.body;

  if (!code) throw new ApiError(400, 'Coupon code required');
  if (!order_total) throw new ApiError(400, 'Order total required');

  const { data: coupon, error } = await supabaseAdmin
    .from('coupons')
    .select('*')
    .eq('code', code.toUpperCase())
    .eq('is_active', true)
    .single();

  if (error || !coupon) throw new ApiError(404, 'Invalid coupon code');

  // Check vendor restriction
  if (coupon.vendor_id && coupon.vendor_id !== vendor_id) {
    throw new ApiError(400, 'Coupon not valid for this vendor');
  }

  // Check validity dates
  const today = new Date().toISOString().split('T')[0];
  if (coupon.valid_from && coupon.valid_from > today) {
    throw new ApiError(400, 'Coupon not yet active');
  }
  if (coupon.valid_until && coupon.valid_until < today) {
    throw new ApiError(400, 'Coupon expired');
  }

  // Check usage limit
  if (coupon.usage_limit && coupon.used_count >= coupon.usage_limit) {
    throw new ApiError(400, 'Coupon usage limit reached');
  }

  // Check per-user limit
  if (coupon.usage_per_user) {
    const { count } = await supabaseAdmin
      .from('coupon_usage')
      .select('*', { count: 'exact', head: true })
      .eq('coupon_id', coupon.id)
      .eq('user_id', req.user.id);

    if (count >= coupon.usage_per_user) {
      throw new ApiError(400, 'You have already used this coupon');
    }
  }

  // Check first order only
  if (coupon.first_order_only && req.user.total_orders > 0) {
    throw new ApiError(400, 'Coupon valid for first order only');
  }

  // Check minimum order
  if (coupon.minimum_order && order_total < coupon.minimum_order) {
    throw new ApiError(400, `Minimum order ₹${coupon.minimum_order} required`);
  }

  // Calculate discount
  let discount = 0;
  if (coupon.discount_type === 'percentage') {
    discount = (order_total * coupon.discount_value) / 100;
    if (coupon.maximum_discount) {
      discount = Math.min(discount, coupon.maximum_discount);
    }
  } else {
    discount = coupon.discount_value;
  }

  discount = Math.min(discount, order_total);

  successResponse(res, {
    valid: true,
    coupon: {
      id: coupon.id,
      code: coupon.code,
      name: coupon.name,
      discount_type: coupon.discount_type,
      discount_value: coupon.discount_value
    },
    discount,
    final_total: order_total - discount
  });
}));

// GET COUPON BY CODE
router.get('/code/:code', asyncHandler(async (req, res) => {
  const { data: coupon, error } = await supabaseAdmin
    .from('coupons')
    .select('id, code, name, description, discount_type, discount_value, minimum_order, maximum_discount, valid_until')
    .eq('code', req.params.code.toUpperCase())
    .eq('is_active', true)
    .single();

  if (error || !coupon) throw new ApiError(404, 'Coupon not found');
  successResponse(res, coupon);
}));

export default router;

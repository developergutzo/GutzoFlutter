import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, paginatedResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';
import { validate, schemas } from '../middleware/validate.js';

const router = express.Router();

// All subscription routes require authentication
router.use(authenticate);

// ============================================
// GET USER SUBSCRIPTIONS
// GET /api/subscriptions
// ============================================
router.get('/', asyncHandler(async (req, res) => {
  const { status, page = 1, limit = 20 } = req.query;

  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let query = supabaseAdmin
    .from('product_subscriptions')
    .select(`
      *,
      vendor:vendors(id, name, image),
      items:subscription_items(
        *,
        product:products(id, name, image, price)
      ),
      deliveries:subscription_deliveries(*)
    `, { count: 'exact' })
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false })
    .range(from, to);

  if (status) query = query.eq('status', status);

  const { data: subscriptions, error, count } = await query;

  if (error) throw new ApiError(500, 'Failed to fetch subscriptions');

  paginatedResponse(res, subscriptions, page, limit, count);
}));

// ============================================
// GET SUBSCRIPTION BY ID
// GET /api/subscriptions/:id
// ============================================
router.get('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: subscription, error } = await supabaseAdmin
    .from('product_subscriptions')
    .select(`
      *,
      vendor:vendors(*),
      items:subscription_items(
        *,
        product:products(*)
      ),
      deliveries:subscription_deliveries(*)
    `)
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !subscription) throw new ApiError(404, 'Subscription not found');

  successResponse(res, subscription);
}));

// ============================================
// CREATE SUBSCRIPTION
// POST /api/subscriptions
// ============================================
router.post('/', validate(schemas.createSubscription), asyncHandler(async (req, res) => {
  const {
    vendor_id,
    products,
    frequency,
    delivery_days,
    delivery_time,
    start_date,
    end_date,
    delivery_address,
    auto_renew
  } = req.body;

  // Verify vendor
  const { data: vendor, error: vendorError } = await supabaseAdmin
    .from('vendors')
    .select('*')
    .eq('id', vendor_id)
    .eq('is_active', true)
    .single();

  if (vendorError || !vendor) throw new ApiError(404, 'Vendor not found');

  // Calculate total amount
  let totalAmount = 0;
  const productDetails = [];

  for (const item of products) {
    const { data: product } = await supabaseAdmin
      .from('products')
      .select('id, name, price')
      .eq('id', item.product_id)
      .single();

    if (product) {
      const itemTotal = product.price * item.quantity;
      totalAmount += itemTotal;
      productDetails.push({
        product_id: item.product_id,
        product_name: product.name,
        quantity: item.quantity,
        unit_price: product.price,
        total_price: itemTotal
      });
    }
  }

  // Create subscription
  const { data: subscription, error: subError } = await supabaseAdmin
    .from('product_subscriptions')
    .insert({
      user_id: req.user.id,
      user_phone: req.user.phone,
      vendor_id,
      frequency,
      delivery_days,
      delivery_time,
      start_date,
      end_date,
      delivery_address: JSON.stringify(delivery_address),
      total_amount: totalAmount,
      per_delivery_amount: totalAmount, // Will be divided by delivery count later
      status: 'active',
      auto_renew,
      next_delivery_date: start_date
    })
    .select()
    .single();

  if (subError) throw new ApiError(500, 'Failed to create subscription');

  // Create subscription items
  const subscriptionItems = productDetails.map(item => ({
    subscription_id: subscription.id,
    product_id: item.product_id,
    product_name: item.product_name,
    quantity: item.quantity,
    unit_price: item.unit_price,
    total_price: item.total_price
  }));

  await supabaseAdmin
    .from('subscription_items')
    .insert(subscriptionItems);

  // Create notification
  await supabaseAdmin
    .from('notifications')
    .insert({
      user_id: req.user.id,
      type: 'subscription_renewed',
      title: 'Subscription Created!',
      message: `Your ${frequency} subscription has been activated.`,
      data: { subscription_id: subscription.id }
    });

  successResponse(res, {
    subscription,
    items: productDetails
  }, 'Subscription created successfully', 201);
}));

// ============================================
// PAUSE SUBSCRIPTION
// POST /api/subscriptions/:id/pause
// ============================================
router.post('/:id/pause', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { pause_start_date, pause_end_date, reason } = req.body;

  const { data: subscription, error } = await supabaseAdmin
    .from('product_subscriptions')
    .select('*')
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !subscription) throw new ApiError(404, 'Subscription not found');

  if (subscription.status !== 'active') {
    throw new ApiError(400, 'Can only pause active subscriptions');
  }

  const { data: updated, error: updateError } = await supabaseAdmin
    .from('product_subscriptions')
    .update({
      status: 'paused',
      pause_start_date,
      pause_end_date,
      pause_reason: reason,
      updated_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single();

  if (updateError) throw new ApiError(500, 'Failed to pause subscription');

  // Create notification
  await supabaseAdmin
    .from('notifications')
    .insert({
      user_id: req.user.id,
      type: 'subscription_paused',
      title: 'Subscription Paused',
      message: `Your subscription has been paused until ${pause_end_date}.`,
      data: { subscription_id: id }
    });

  successResponse(res, updated, 'Subscription paused');
}));

// ============================================
// RESUME SUBSCRIPTION
// POST /api/subscriptions/:id/resume
// ============================================
router.post('/:id/resume', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: subscription, error } = await supabaseAdmin
    .from('product_subscriptions')
    .select('*')
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !subscription) throw new ApiError(404, 'Subscription not found');

  if (subscription.status !== 'paused') {
    throw new ApiError(400, 'Can only resume paused subscriptions');
  }

  const { data: updated, error: updateError } = await supabaseAdmin
    .from('product_subscriptions')
    .update({
      status: 'active',
      pause_start_date: null,
      pause_end_date: null,
      pause_reason: null,
      updated_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single();

  if (updateError) throw new ApiError(500, 'Failed to resume subscription');

  successResponse(res, updated, 'Subscription resumed');
}));

// ============================================
// CANCEL SUBSCRIPTION
// POST /api/subscriptions/:id/cancel
// ============================================
router.post('/:id/cancel', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  const { data: subscription, error } = await supabaseAdmin
    .from('product_subscriptions')
    .select('*')
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !subscription) throw new ApiError(404, 'Subscription not found');

  if (subscription.status === 'cancelled') {
    throw new ApiError(400, 'Subscription already cancelled');
  }

  const { data: updated, error: updateError } = await supabaseAdmin
    .from('product_subscriptions')
    .update({
      status: 'cancelled',
      cancelled_at: new Date().toISOString(),
      cancellation_reason: reason,
      updated_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single();

  if (updateError) throw new ApiError(500, 'Failed to cancel subscription');

  successResponse(res, updated, 'Subscription cancelled');
}));

// ============================================
// SKIP DELIVERY DATE
// POST /api/subscriptions/:id/skip
// ============================================
router.post('/:id/skip', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { date } = req.body;

  if (!date) throw new ApiError(400, 'Date is required');

  const { data: subscription, error } = await supabaseAdmin
    .from('product_subscriptions')
    .select('*')
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !subscription) throw new ApiError(404, 'Subscription not found');

  const skipDates = subscription.skip_dates || [];
  
  if (skipDates.includes(date)) {
    throw new ApiError(400, 'This date is already skipped');
  }

  skipDates.push(date);

  const { data: updated, error: updateError } = await supabaseAdmin
    .from('product_subscriptions')
    .update({
      skip_dates: skipDates,
      updated_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single();

  if (updateError) throw new ApiError(500, 'Failed to skip date');

  successResponse(res, updated, `Delivery skipped for ${date}`);
}));

// ============================================
// GET UPCOMING DELIVERIES
// GET /api/subscriptions/:id/deliveries
// ============================================
router.get('/:id/deliveries', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { upcoming = 'true' } = req.query;

  const { data: deliveries, error } = await supabaseAdmin
    .from('subscription_deliveries')
    .select('*')
    .eq('subscription_id', id)
    .order('delivery_date', { ascending: true });

  if (error) throw new ApiError(500, 'Failed to fetch deliveries');

  let filtered = deliveries;
  if (upcoming === 'true') {
    const today = new Date().toISOString().split('T')[0];
    filtered = deliveries.filter(d => d.delivery_date >= today);
  }

  successResponse(res, filtered);
}));

export default router;

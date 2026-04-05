import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, paginatedResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate, optionalAuth } from '../middleware/auth.js';

const router = express.Router();

// ============================================
// GET ALL PRODUCTS
// GET /api/products
// ============================================
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const { 
    page = 1, 
    limit = 20, 
    vendor_id,
    category,
    type, // veg, non-veg
    featured,
    bestseller,
    search,
    min_price,
    max_price,
    sort = 'created_at',
    order = 'desc'
  } = req.query;

  let query = supabaseAdmin
    .from('products')
    .select(`
      *,
      vendor:vendors(id, name, image, rating, delivery_time, is_open),
      variants:product_variants(*),
      addons:product_addons(*)
    `, { count: 'exact' })
    .eq('is_available', true);

  // Filters
  if (vendor_id) query = query.eq('vendor_id', vendor_id);
  if (category) query = query.eq('category', category);
  if (type) query = query.eq('type', type);
  if (featured === 'true') query = query.eq('is_featured', true);
  if (bestseller === 'true') query = query.eq('is_bestseller', true);
  if (min_price) query = query.gte('price', parseFloat(min_price));
  if (max_price) query = query.lte('price', parseFloat(max_price));
  if (search) query = query.ilike('name', `%${search}%`);

  // Sorting
  const validSorts = ['price', 'name', 'created_at', 'rating', 'calories'];
  const sortField = validSorts.includes(sort) ? sort : 'created_at';
  query = query.order(sortField, { ascending: order === 'asc' });

  // Pagination
  const from = (page - 1) * limit;
  const to = from + limit - 1;
  query = query.range(from, to);

  const { data: products, error, count } = await query;

  if (error) throw new ApiError(500, 'Failed to fetch products');

  paginatedResponse(res, products, page, limit, count);
}));

// ============================================
// GET FEATURED PRODUCTS
// GET /api/products/featured
// ============================================
router.get('/featured', asyncHandler(async (req, res) => {
  const { limit = 10 } = req.query;

  const { data: products, error } = await supabaseAdmin
    .from('products')
    .select(`
      *,
      vendor:vendors(id, name, image, rating, is_open)
    `)
    .eq('is_available', true)
    .eq('is_featured', true)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw new ApiError(500, 'Failed to fetch featured products');

  successResponse(res, products);
}));

// ============================================
// GET BESTSELLER PRODUCTS
// GET /api/products/bestsellers
// ============================================
router.get('/bestsellers', asyncHandler(async (req, res) => {
  const { limit = 10 } = req.query;

  const { data: products, error } = await supabaseAdmin
    .from('products')
    .select(`
      *,
      vendor:vendors(id, name, image, rating, is_open)
    `)
    .eq('is_available', true)
    .eq('is_bestseller', true)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw new ApiError(500, 'Failed to fetch bestsellers');

  successResponse(res, products);
}));

// ============================================
// GET PRODUCT BY ID
// GET /api/products/:id
// ============================================
router.get('/:id', optionalAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: product, error } = await supabaseAdmin
    .from('products')
    .select(`
      *,
      vendor:vendors(id, name, image, rating, delivery_time, is_open, minimum_order, delivery_fee),
      variants:product_variants(*),
      addons:product_addons(*)
    `)
    .eq('id', id)
    .single();

  if (error || !product) throw new ApiError(404, 'Product not found');

  // Log activity if user is logged in
  if (req.user) {
    await supabaseAdmin
      .from('activity_logs')
      .insert({
        user_id: req.user.id,
        action: 'view_product',
        entity_type: 'product',
        entity_id: id,
        metadata: { product_name: product.name, vendor_id: product.vendor_id }
      });
  }

  // Get related products from same vendor/category
  const { data: related } = await supabaseAdmin
    .from('products')
    .select('id, name, price, image, category')
    .eq('category', product.category)
    .eq('is_available', true)
    .neq('id', id)
    .limit(6);

  successResponse(res, { product, related: related || [] });
}));

// ============================================
// GET PRODUCTS BY CATEGORY
// GET /api/products/category/:category
// ============================================
router.get('/category/:category', asyncHandler(async (req, res) => {
  const { category } = req.params;
  const { page = 1, limit = 20 } = req.query;

  const from = (page - 1) * limit;
  const to = from + limit - 1;

  const { data: products, error, count } = await supabaseAdmin
    .from('products')
    .select(`
      *,
      vendor:vendors(id, name, image, rating, is_open)
    `, { count: 'exact' })
    .eq('category', category)
    .eq('is_available', true)
    .order('sort_order', { ascending: true })
    .range(from, to);

  if (error) throw new ApiError(500, 'Failed to fetch products');

  paginatedResponse(res, products, page, limit, count);
}));

// ============================================
// GET PRODUCT VARIANTS
// GET /api/products/:id/variants
// ============================================
router.get('/:id/variants', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: variants, error } = await supabaseAdmin
    .from('product_variants')
    .select('*')
    .eq('product_id', id)
    .eq('is_available', true)
    .order('sort_order', { ascending: true });

  if (error) throw new ApiError(500, 'Failed to fetch variants');

  successResponse(res, variants);
}));

// ============================================
// GET PRODUCT ADDONS
// GET /api/products/:id/addons
// ============================================
router.get('/:id/addons', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: addons, error } = await supabaseAdmin
    .from('product_addons')
    .select('*')
    .eq('product_id', id)
    .eq('is_available', true)
    .order('sort_order', { ascending: true });

  if (error) throw new ApiError(500, 'Failed to fetch addons');

  successResponse(res, addons);
}));

// ============================================
// GET PRODUCT SUBSCRIPTION STATUS
// GET /api/products/:id/subscription
// ============================================
router.get('/:id/subscription', optionalAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;

  if (!req.user) {
    return successResponse(res, { has_subscription: false });
  }

  // Check for active subscription for this product
  // Note: structured somewhat differently than standard subscriptions
  // This mimics the specific behavior expected by the frontend
  const { data: subscription } = await supabaseAdmin
    .from('product_subscriptions')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('status', 'active')
    .contains('delivery_address', { product_id: id }) // This is a guess on structure, or we check items
    // Actually, let's checking subscription_items
    .limit(1);

    // Alternative: Check subscription_items directly
    const { data: items } = await supabaseAdmin
      .from('subscription_items')
      .select('subscription_id, subscription:product_subscriptions!inner(status)')
      .eq('product_id', id)
      .eq('subscription.user_id', req.user.id)
      .eq('subscription.status', 'active')
      .limit(1);

  const hasSubscription = items && items.length > 0;
  
  successResponse(res, { 
    id: hasSubscription ? items[0].subscription_id : null,
    product_id: id,
    has_subscription: hasSubscription 
  });
}));

// ============================================
// TOGGLE PRODUCT SUBSCRIPTION
// POST /api/products/:id/subscription
// ============================================
router.post('/:id/subscription', authenticate, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { has_subscription } = req.body;

  if (has_subscription) {
    // Logic to create a default subscription
    // This is a simplification. Ideally, we should ask for details.
    // For now, we create a daily subscription for 30 days.
    
    // 1. Get Product
    const { data: product } = await supabaseAdmin
      .from('products')
      .select('*, vendor:vendors(*)')
      .eq('id', id)
      .single();
      
    if (!product) throw new ApiError(404, 'Product not found');

    // 2. Create Subscription
    const startDate = new Date().toISOString().split('T')[0];
    const endDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]; // 30 days
    
    const { data: sub, error } = await supabaseAdmin
      .from('product_subscriptions')
      .insert({
        user_id: req.user.id,
        user_phone: req.user.phone,
        vendor_id: product.vendor_id,
        frequency: 'daily',
        delivery_days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        start_date: startDate,
        end_date: endDate,
        status: 'active',
        total_amount: product.price * 30, 
        delivery_address: '{}' // Placeholder
      })
      .select()
      .single();

    if (error) throw new ApiError(500, 'Failed to create subscription');
    
    // 3. Add Item
    await supabaseAdmin
      .from('subscription_items')
      .insert({
        subscription_id: sub.id,
        product_id: id,
        product_name: product.name,
        quantity: 1,
        unit_price: product.price,
        total_price: product.price
      });

    successResponse(res, { has_subscription: true, subscription_id: sub.id });

  } else {
    // Cancel existing active subscriptions for this product
    const { data: items } = await supabaseAdmin
      .from('subscription_items')
      .select('subscription_id, subscription:product_subscriptions!inner(id, user_id, status)')
      .eq('product_id', id)
      .eq('subscription.user_id', req.user.id)
      .eq('subscription.status', 'active');
      
    if (items && items.length > 0) {
      const subIds = items.map(i => i.subscription_id);
      
      await supabaseAdmin
        .from('product_subscriptions')
        .update({ status: 'cancelled', cancelled_at: new Date().toISOString() })
        .in('id', subIds);
    }
    
    successResponse(res, { has_subscription: false });
  }
}));

export default router;

import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, paginatedResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate, optionalAuth } from '../middleware/auth.js';
import { validate, schemas } from '../middleware/validate.js';

const router = express.Router();

// ============================================
// CREATE VENDOR
// POST /api/vendors
// ============================================
router.post('/', authenticate, validate(schemas.createVendor || {}), asyncHandler(async (req, res) => {
  const { name, email, phone, is_active } = req.body; // Basic fields

  // Check if vendor exists
  const { data: existing } = await supabaseAdmin
    .from('vendors')
    .select('id')
    .eq('email', email)
    .single();

  if (existing) throw new ApiError(400, 'Vendor with this email already exists');

  const { data: vendor, error } = await supabaseAdmin
    .from('vendors')
    .insert({
      ...req.body,
      is_active: is_active ?? true,
      rating: 0,
      is_open: true
    })
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to create vendor');

  successResponse(res, vendor, 'Vendor created successfully', 201);
}));

// ============================================
// GET ALL VENDORS
// GET /api/vendors
// ============================================
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const { 
    page = 1, 
    limit = 20, 
    cuisine, 
    featured,
    open,
    sort = 'rating',
    order = 'desc'
  } = req.query;

  let query = supabaseAdmin
    .from('vendors')
    .select('*', { count: 'exact' })
    .eq('is_active', true);

  // Filters
  if (cuisine) query = query.eq('cuisine_type', cuisine);
  if (featured === 'true') query = query.eq('is_featured', true);
  if (open === 'true') query = query.eq('is_open', true);

  // Sorting
  const validSorts = ['rating', 'total_orders', 'minimum_order', 'created_at', 'name'];
  const sortField = validSorts.includes(sort) ? sort : 'rating';
  query = query.order(sortField, { ascending: order === 'asc' });

  // Pagination
  const from = (page - 1) * limit;
  const to = from + limit - 1;
  query = query.range(from, to);

  const { data: vendors, error, count } = await query;

  if (error) throw new ApiError(500, 'Failed to fetch vendors');

  // Enrich vendors with dynamic ratings
  if (vendors && vendors.length > 0) {
    const vendorIds = vendors.map(v => v.id);
    const { data: allProductStats } = await supabaseAdmin
      .from('products')
      .select('vendor_id, rating, review_count')
      .in('vendor_id', vendorIds)
      .gt('rating', 0);

    if (allProductStats) {
      vendors.forEach(vendor => {
        const stats = allProductStats.filter(p => p.vendor_id === vendor.id);
        if (stats.length > 0) {
          const totalRating = stats.reduce((sum, p) => sum + p.rating, 0);
          const totalReviews = stats.reduce((sum, p) => sum + (p.review_count || 0), 0);
          const calculatedAvg = (totalRating / stats.length).toFixed(1);
          vendor.rating = parseFloat(calculatedAvg);
          vendor.review_count = totalReviews;
        }
      });
    }
  }

  paginatedResponse(res, vendors, page, limit, count);
}));

// ============================================
// GET FEATURED VENDORS
// GET /api/vendors/featured
// ============================================
router.get('/featured', asyncHandler(async (req, res) => {
  const { limit = 10 } = req.query;

  const { data: vendors, error } = await supabaseAdmin
    .from('vendors')
    .select('*')
    .eq('is_active', true)
    .eq('is_featured', true)
    .eq('is_open', true)
    .order('rating', { ascending: false })
    .limit(limit);

  if (error) throw new ApiError(500, 'Failed to fetch featured vendors');

  // Enrich vendors with dynamic ratings
  if (vendors && vendors.length > 0) {
    const vendorIds = vendors.map(v => v.id);
    const { data: allProductStats } = await supabaseAdmin
      .from('products')
      .select('vendor_id, rating, review_count')
      .in('vendor_id', vendorIds)
      .gt('rating', 0);

    if (allProductStats) {
      vendors.forEach(vendor => {
        const stats = allProductStats.filter(p => p.vendor_id === vendor.id);
        if (stats.length > 0) {
          const totalRating = stats.reduce((sum, p) => sum + p.rating, 0);
          const totalReviews = stats.reduce((sum, p) => sum + (p.review_count || 0), 0);
          const calculatedAvg = (totalRating / stats.length).toFixed(1);
          vendor.rating = parseFloat(calculatedAvg);
          vendor.review_count = totalReviews;
        }
      });
    }
  }

  successResponse(res, vendors);
}));

// ============================================
// GET VENDOR BY ID
// GET /api/vendors/:id
// ============================================
router.get('/:id', optionalAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: vendor, error } = await supabaseAdmin
    .from('vendors')
    .select(`
      *,
      products(*),
      schedules:vendor_schedules(*),
      delivery_zones:vendor_delivery_zones(
        *,
        zone:delivery_zones(*)
      )
    `)
    .eq('id', id)
    .eq('is_active', true)
    .single();

  if (error || !vendor) throw new ApiError(404, 'Vendor not found');

  // Get reviews summary (based on product ratings as per user request)
  const { data: productStats } = await supabaseAdmin
    .from('products')
    .select('rating, review_count')
    .eq('vendor_id', id)
    .gt('rating', 0);

  if (productStats && productStats.length > 0) {
    const totalRating = productStats.reduce((sum, p) => sum + p.rating, 0);
    const totalReviews = productStats.reduce((sum, p) => sum + (p.review_count || 0), 0);
    const calculatedAvg = (totalRating / productStats.length).toFixed(1);
    
    // console.log(`[Rating Debug] Vendor: ${vendor.name}, Total: ${totalRating}, Count: ${productStats.length}, Avg: ${calculatedAvg}`);
    
    vendor.rating = parseFloat(calculatedAvg); // Keeping it as number for consistency but ensure precision
    vendor.calculated_rating = calculatedAvg; // String variant
    vendor.review_count = totalReviews;
  }

  successResponse(res, vendor);
}));

// ============================================
// GET VENDOR PRODUCTS
// GET /api/vendors/:id/products
// ============================================
router.get('/:id/products', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { category, available = 'true' } = req.query;

  let query = supabaseAdmin
    .from('products')
    .select(`
      *,
      vendor:vendors(*),
      variants:product_variants(*),
      addons:product_addons(*)
    `)
    .eq('vendor_id', id);

  if (available === 'true') query = query.eq('is_available', true);
  if (category) query = query.eq('category', category);

  query = query.order('sort_order', { ascending: true });

  const { data: products, error } = await query;

  if (error) throw new ApiError(500, 'Failed to fetch products');

  // Group by category
  const grouped = products.reduce((acc, product) => {
    const cat = product.category || 'Other';
    if (!acc[cat]) acc[cat] = [];
    acc[cat].push(product);
    return acc;
  }, {});

  successResponse(res, { products, grouped });
}));

// ============================================
// CREATE VENDOR PRODUCT
// POST /api/vendors/:id/products
// ============================================
router.post('/:id/products', authenticate, validate(schemas.createProduct || {}), asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Verify vendor ownership or admin status (skipping complex auth for now, assuming authorized vendor)
  
  const { data: product, error } = await supabaseAdmin
    .from('products')
    .insert({
      ...req.body,
      vendor_id: id,
      is_available: true,
      rating: 0
    })
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to create product');

  successResponse(res, product, 'Product created successfully', 201);
}));

// ============================================
// GET VENDOR REVIEWS
// GET /api/vendors/:id/reviews
// ============================================
router.get('/:id/reviews', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { page = 1, limit = 20 } = req.query;

  const from = (page - 1) * limit;
  const to = from + limit - 1;

  const { data: reviews, error, count } = await supabaseAdmin
    .from('reviews')
    .select(`
      *,
      user:users(name, profile_image)
    `, { count: 'exact' })
    .eq('vendor_id', id)
    .eq('status', 'published')
    .order('created_at', { ascending: false })
    .range(from, to);

  if (error) throw new ApiError(500, 'Failed to fetch reviews');

  // Get rating breakdown
  const { data: breakdown } = await supabaseAdmin
    .from('reviews')
    .select('rating')
    .eq('vendor_id', id)
    .eq('status', 'published');

  const ratingBreakdown = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
  let avgRating = 0;

  if (breakdown && breakdown.length > 0) {
    breakdown.forEach(r => ratingBreakdown[r.rating]++);
    avgRating = (breakdown.reduce((sum, r) => sum + r.rating, 0) / breakdown.length).toFixed(1);
  }

  paginatedResponse(res, { 
    reviews, 
    summary: { avgRating, total: count, breakdown: ratingBreakdown }
  }, page, limit, count);
}));

// ============================================
// GET VENDOR SCHEDULE
// GET /api/vendors/:id/schedule
// ============================================
router.get('/:id/schedule', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: schedule, error } = await supabaseAdmin
    .from('vendor_schedules')
    .select('*')
    .eq('vendor_id', id)
    .order('day_of_week', { ascending: true });

  if (error) throw new ApiError(500, 'Failed to fetch schedule');

  // Get special hours for next 30 days
  const today = new Date().toISOString().split('T')[0];
  const thirtyDaysLater = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

  const { data: specialHours } = await supabaseAdmin
    .from('vendor_special_hours')
    .select('*')
    .eq('vendor_id', id)
    .gte('special_date', today)
    .lte('special_date', thirtyDaysLater);

  successResponse(res, { schedule, specialHours: specialHours || [] });
}));

// ============================================
// CHECK IF VENDOR IS OPEN
// GET /api/vendors/:id/is-open
// ============================================
router.get('/:id/is-open', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: vendor, error } = await supabaseAdmin
    .from('vendors')
    .select('is_open, is_active')
    .eq('id', id)
    .single();

  if (error || !vendor) throw new ApiError(404, 'Vendor not found');

  // TODO: Check actual schedule based on current time and day

  successResponse(res, { 
    isOpen: vendor.is_open && vendor.is_active,
    message: vendor.is_open ? 'Currently accepting orders' : 'Currently closed'
  });
}));

export default router;

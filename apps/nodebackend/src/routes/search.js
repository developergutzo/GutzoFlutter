import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { optionalAuth } from '../middleware/auth.js';

const router = express.Router();

// SEARCH PRODUCTS AND VENDORS
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const { q, type = 'all', limit = 20 } = req.query;

  if (!q || q.length < 2) throw new ApiError(400, 'Search query min 2 characters');

  const results = { products: [], vendors: [] };

  // Search products
  if (type === 'all' || type === 'products') {
    const { data: products } = await supabaseAdmin
      .from('products')
      .select('id, name, price, image, category, vendor_id, vendor:vendors(id, name)')
      .eq('is_available', true)
      .or(`name.ilike.%${q}%,description.ilike.%${q}%,category.ilike.%${q}%`)
      .limit(limit);

    results.products = products || [];
  }

  // Search vendors
  if (type === 'all' || type === 'vendors') {
    const { data: vendors } = await supabaseAdmin
      .from('vendors')
      .select('id, name, image, rating, cuisine_type, is_open')
      .eq('is_active', true)
      .or(`name.ilike.%${q}%,cuisine_type.ilike.%${q}%,description.ilike.%${q}%`)
      .limit(limit);

    results.vendors = vendors || [];
  }

  // Log search
  await supabaseAdmin
    .from('search_logs')
    .insert({
      user_id: req.user?.id,
      query: q,
      results_count: results.products.length + results.vendors.length,
      device_type: req.headers['user-agent']
    });

  successResponse(res, results);
}));

// GET POPULAR SEARCHES
router.get('/popular', asyncHandler(async (req, res) => {
  const { limit = 10 } = req.query;

  // Get most common queries from last 7 days
  const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  const { data: searches } = await supabaseAdmin
    .from('search_logs')
    .select('query')
    .gte('created_at', weekAgo);

  // Count frequencies
  const counts = {};
  (searches || []).forEach(s => {
    const q = s.query.toLowerCase().trim();
    counts[q] = (counts[q] || 0) + 1;
  });

  // Sort by frequency
  const popular = Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([query, count]) => ({ query, count }));

  successResponse(res, popular);
}));

// GET SEARCH SUGGESTIONS (Autocomplete)
router.get('/suggest', asyncHandler(async (req, res) => {
  const { q, limit = 8 } = req.query;

  if (!q || q.length < 1) return successResponse(res, []);

  // Get matching products
  const { data: products } = await supabaseAdmin
    .from('products')
    .select('name')
    .eq('is_available', true)
    .ilike('name', `${q}%`)
    .limit(limit);

  // Get matching categories
  const { data: categories } = await supabaseAdmin
    .from('categories')
    .select('name')
    .eq('is_active', true)
    .ilike('name', `${q}%`)
    .limit(4);

  const suggestions = [
    ...new Set([
      ...(products || []).map(p => p.name),
      ...(categories || []).map(c => c.name)
    ])
  ].slice(0, limit);

  successResponse(res, suggestions);
}));

// LOG SEARCH CLICK
router.post('/click', optionalAuth, asyncHandler(async (req, res) => {
  const { query, product_id, vendor_id } = req.body;

  await supabaseAdmin
    .from('search_logs')
    .insert({
      user_id: req.user?.id,
      query: query || '',
      clicked_product_id: product_id,
      clicked_vendor_id: vendor_id
    });

  successResponse(res, null, 'Click logged');
}));

export default router;

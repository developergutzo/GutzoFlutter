import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticate);

// GET USER FAVORITES
router.get('/', asyncHandler(async (req, res) => {
  const { type } = req.query; // 'vendor' or 'product'

  let query = supabaseAdmin
    .from('user_favorites')
    .select(`
      *,
      vendor:vendors(id, name, image, rating, cuisine_type, is_open),
      product:products(id, name, price, image, category, vendor_id)
    `)
    .eq('user_id', req.user.id);

  if (type === 'vendor') query = query.not('vendor_id', 'is', null);
  if (type === 'product') query = query.not('product_id', 'is', null);

  const { data, error } = await query.order('created_at', { ascending: false });
  if (error) throw new ApiError(500, 'Failed to fetch favorites');

  successResponse(res, data);
}));

// ADD TO FAVORITES
router.post('/', asyncHandler(async (req, res) => {
  const { vendor_id, product_id } = req.body;

  if (!vendor_id && !product_id) throw new ApiError(400, 'Vendor or product ID required');

  // Check if already favorited
  const { data: existing } = await supabaseAdmin
    .from('user_favorites')
    .select('id')
    .eq('user_id', req.user.id)
    .eq('vendor_id', vendor_id || null)
    .eq('product_id', product_id || null)
    .single();

  if (existing) throw new ApiError(400, 'Already in favorites');

  const { data, error } = await supabaseAdmin
    .from('user_favorites')
    .insert({ user_id: req.user.id, vendor_id, product_id })
    .select().single();

  if (error) throw new ApiError(500, 'Failed to add to favorites');
  successResponse(res, data, 'Added to favorites', 201);
}));

// REMOVE FROM FAVORITES
router.delete('/:id', asyncHandler(async (req, res) => {
  const { error } = await supabaseAdmin
    .from('user_favorites')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) throw new ApiError(500, 'Failed to remove');
  successResponse(res, null, 'Removed from favorites');
}));

// TOGGLE FAVORITE (Convenience endpoint)
router.post('/toggle', asyncHandler(async (req, res) => {
  const { vendor_id, product_id } = req.body;

  const { data: existing } = await supabaseAdmin
    .from('user_favorites')
    .select('id')
    .eq('user_id', req.user.id)
    .eq('vendor_id', vendor_id || null)
    .eq('product_id', product_id || null)
    .single();

  if (existing) {
    await supabaseAdmin.from('user_favorites').delete().eq('id', existing.id);
    return successResponse(res, { is_favorite: false }, 'Removed from favorites');
  }

  const { data, error } = await supabaseAdmin
    .from('user_favorites')
    .insert({ user_id: req.user.id, vendor_id, product_id })
    .select().single();

  if (error) throw new ApiError(500, 'Failed to add');
  successResponse(res, { is_favorite: true, favorite: data }, 'Added to favorites');
}));

// CHECK IF FAVORITE
router.get('/check', asyncHandler(async (req, res) => {
  const { vendor_id, product_id } = req.query;

  const { data } = await supabaseAdmin
    .from('user_favorites')
    .select('id')
    .eq('user_id', req.user.id)
    .eq('vendor_id', vendor_id || null)
    .eq('product_id', product_id || null)
    .single();

  successResponse(res, { is_favorite: !!data });
}));

export default router;

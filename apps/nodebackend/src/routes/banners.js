import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';

const router = express.Router();

// GET ACTIVE BANNERS
router.get('/', asyncHandler(async (req, res) => {
  const { position = 'hero' } = req.query;
  const now = new Date().toISOString();

  const { data: banners, error } = await supabaseAdmin
    .from('promo_banners')
    .select('*')
    .eq('is_active', true)
    .eq('position', position)
    .or(`start_date.lte.${now},start_date.is.null`)
    .or(`end_date.gte.${now},end_date.is.null`)
    .order('sort_order', { ascending: true });

  if (error) throw new ApiError(500, 'Failed to fetch banners');

  // Increment impressions
  const ids = banners?.map(b => b.id) || [];
  if (ids.length > 0) {
    await supabaseAdmin.rpc('increment_banner_impressions', { banner_ids: ids });
  }

  successResponse(res, banners || []);
}));

// GET ALL POSITIONS
router.get('/all', asyncHandler(async (req, res) => {
  const now = new Date().toISOString();

  const { data: banners, error } = await supabaseAdmin
    .from('promo_banners')
    .select('*')
    .eq('is_active', true)
    .or(`start_date.lte.${now},start_date.is.null`)
    .or(`end_date.gte.${now},end_date.is.null`)
    .order('sort_order', { ascending: true });

  if (error) throw new ApiError(500, 'Failed to fetch banners');

  // Group by position
  const grouped = {
    hero: [],
    middle: [],
    bottom: []
  };

  (banners || []).forEach(b => {
    if (grouped[b.position]) grouped[b.position].push(b);
  });

  successResponse(res, grouped);
}));

// TRACK BANNER CLICK
router.post('/:id/click', asyncHandler(async (req, res) => {
  await supabaseAdmin
    .from('promo_banners')
    .update({ clicks: supabaseAdmin.sql`clicks + 1` })
    .eq('id', req.params.id);

  successResponse(res, null, 'Click tracked');
}));

export default router;

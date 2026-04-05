import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';

const router = express.Router();

/**
 * @route   GET /api/mood-categories
 * @desc    Get all mood categories
 * @access  Public
 */
router.get('/', asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('MoodCategory')
    .select('*')
    .eq('is_active', true)
    .order('sort_order', { ascending: true });

  if (error) {
    console.error('Error fetching mood categories:', error);
    throw new ApiError(500, 'Failed to fetch mood categories');
  }

  successResponse(res, data);
}));

export default router;

import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, paginatedResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate, optionalAuth } from '../middleware/auth.js';

const router = express.Router();

// GET REVIEWS FOR VENDOR/PRODUCT
router.get('/', asyncHandler(async (req, res) => {
  const { vendor_id, product_id, page = 1, limit = 20 } = req.query;

  let query = supabaseAdmin
    .from('reviews')
    .select('*, user:users(name, profile_image)', { count: 'exact' })
    .eq('status', 'published')
    .order('created_at', { ascending: false });

  if (vendor_id) query = query.eq('vendor_id', vendor_id);
  if (product_id) query = query.eq('product_id', product_id);

  const from = (page - 1) * limit;
  query = query.range(from, from + limit - 1);

  const { data, error, count } = await query;
  if (error) throw new ApiError(500, 'Failed to fetch reviews');

  // Get rating stats
  const { data: stats } = await supabaseAdmin
    .from('reviews')
    .select('rating')
    .eq('vendor_id', vendor_id)
    .eq('status', 'published');

  const breakdown = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
  let avgRating = 0;
  if (stats?.length) {
    stats.forEach(r => breakdown[r.rating]++);
    avgRating = (stats.reduce((s, r) => s + r.rating, 0) / stats.length).toFixed(1);
  }

  paginatedResponse(res, { reviews: data, summary: { avgRating, breakdown, total: count } }, page, limit, count);
}));

// CREATE REVIEW
router.post('/', authenticate, asyncHandler(async (req, res) => {
  const { vendor_id, product_id, order_id, rating, comment, images } = req.body;

  if (!rating || rating < 1 || rating > 5) throw new ApiError(400, 'Rating 1-5 required');

  // Check if already reviewed
  const { data: existing } = await supabaseAdmin
    .from('reviews')
    .select('id')
    .eq('user_id', req.user.id)
    .eq('vendor_id', vendor_id)
    .eq('order_id', order_id)
    .single();

  if (existing) throw new ApiError(400, 'You already reviewed this order');

  // Check if verified purchase
  let isVerified = false;
  if (order_id) {
    const { data: order } = await supabaseAdmin
      .from('orders')
      .select('id')
      .eq('id', order_id)
      .eq('user_id', req.user.id)
      .eq('status', 'delivered')
      .single();
    isVerified = !!order;
  }

  const { data: review, error } = await supabaseAdmin
    .from('reviews')
    .insert({
      user_id: req.user.id, vendor_id, product_id, order_id,
      rating, comment, images: images || [],
      is_verified_purchase: isVerified, status: 'published'
    })
    .select().single();

  if (error) throw new ApiError(500, 'Failed to create review');

  // Update vendor/product rating
  const { data: allReviews } = await supabaseAdmin
    .from('reviews')
    .select('rating')
    .eq('vendor_id', vendor_id)
    .eq('status', 'published');

  if (allReviews?.length) {
    const avg = allReviews.reduce((s, r) => s + r.rating, 0) / allReviews.length;
    await supabaseAdmin
      .from('vendors')
      .update({ rating: avg.toFixed(1), total_reviews: allReviews.length })
      .eq('id', vendor_id);
  }

  successResponse(res, review, 'Review submitted', 201);
}));

// UPDATE REVIEW
router.put('/:id', authenticate, asyncHandler(async (req, res) => {
  const { rating, comment, images } = req.body;

  const { data, error } = await supabaseAdmin
    .from('reviews')
    .update({ rating, comment, images, updated_at: new Date().toISOString() })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .select().single();

  if (error) throw new ApiError(404, 'Review not found');
  successResponse(res, data, 'Review updated');
}));

// DELETE REVIEW
router.delete('/:id', authenticate, asyncHandler(async (req, res) => {
  const { error } = await supabaseAdmin
    .from('reviews')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) throw new ApiError(404, 'Review not found');
  successResponse(res, null, 'Review deleted');
}));

// VOTE HELPFUL
router.post('/:id/vote', authenticate, asyncHandler(async (req, res) => {
  const { is_helpful } = req.body;

  // Check existing vote
  const { data: existing } = await supabaseAdmin
    .from('review_votes')
    .select('id')
    .eq('review_id', req.params.id)
    .eq('user_id', req.user.id)
    .single();

  if (existing) {
    await supabaseAdmin.from('review_votes').update({ is_helpful }).eq('id', existing.id);
  } else {
    await supabaseAdmin.from('review_votes').insert({
      review_id: req.params.id, user_id: req.user.id, is_helpful
    });
  }

  // Update helpful count
  const { count } = await supabaseAdmin
    .from('review_votes')
    .select('*', { count: 'exact', head: true })
    .eq('review_id', req.params.id)
    .eq('is_helpful', true);

  await supabaseAdmin
    .from('reviews')
    .update({ helpful_count: count })
    .eq('id', req.params.id);

  successResponse(res, { helpful_count: count }, 'Vote recorded');
}));

export default router;

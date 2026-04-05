import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticate);

// GET ALL NOTIFICATIONS
router.get('/', asyncHandler(async (req, res) => {
  const { page = 1, limit = 50, unread_only } = req.query;
  const from = (page - 1) * limit;

  let query = supabaseAdmin
    .from('notifications')
    .select('*', { count: 'exact' })
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false })
    .range(from, from + limit - 1);

  if (unread_only === 'true') query = query.eq('is_read', false);

  const { data, error, count } = await query;
  if (error) throw new ApiError(500, 'Failed to fetch notifications');

  // Get unread count
  const { count: unreadCount } = await supabaseAdmin
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', req.user.id)
    .eq('is_read', false);

  successResponse(res, { notifications: data, unread_count: unreadCount, page, limit, total: count });
}));

// MARK AS READ
router.post('/:id/read', asyncHandler(async (req, res) => {
  const { error } = await supabaseAdmin
    .from('notifications')
    .update({ is_read: true, read_at: new Date().toISOString() })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) throw new ApiError(500, 'Failed to mark as read');
  successResponse(res, null, 'Marked as read');
}));

// MARK ALL AS READ
router.post('/read-all', asyncHandler(async (req, res) => {
  const { error } = await supabaseAdmin
    .from('notifications')
    .update({ is_read: true, read_at: new Date().toISOString() })
    .eq('user_id', req.user.id)
    .eq('is_read', false);

  if (error) throw new ApiError(500, 'Failed to mark all as read');
  successResponse(res, null, 'All notifications marked as read');
}));

// DELETE NOTIFICATION
router.delete('/:id', asyncHandler(async (req, res) => {
  await supabaseAdmin
    .from('notifications')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  successResponse(res, null, 'Notification deleted');
}));

// GET/UPDATE PREFERENCES
router.get('/preferences', asyncHandler(async (req, res) => {
  let { data } = await supabaseAdmin
    .from('notification_preferences')
    .select('*')
    .eq('user_id', req.user.id)
    .single();

  if (!data) {
    const { data: created } = await supabaseAdmin
      .from('notification_preferences')
      .insert({ user_id: req.user.id })
      .select().single();
    data = created;
  }

  successResponse(res, data);
}));

router.put('/preferences', asyncHandler(async (req, res) => {
  const { order_updates, subscription_alerts, promotional, review_requests, channel } = req.body;

  const { data, error } = await supabaseAdmin
    .from('notification_preferences')
    .upsert({
      user_id: req.user.id, order_updates, subscription_alerts, promotional, review_requests, channel,
      updated_at: new Date().toISOString()
    })
    .select().single();

  if (error) throw new ApiError(500, 'Failed to update preferences');
  successResponse(res, data, 'Preferences updated');
}));

export default router;

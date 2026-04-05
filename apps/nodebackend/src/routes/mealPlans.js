import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, paginatedResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate, optionalAuth } from '../middleware/auth.js';

const router = express.Router();

// GET ALL MEAL PLANS
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, featured, dietary_type } = req.query;

  // First get meal plans
  let query = supabaseAdmin
    .from('meal_plans')
    .select('*, vendor:vendors(id, name, image, rating)', { count: 'exact' })
    .eq('is_active', true);

  if (featured === 'true') query = query.eq('is_featured', true);
  if (dietary_type) query = query.eq('dietary_type', dietary_type);

  const from = (page - 1) * limit;
  query = query.order('sort_order', { ascending: true }).range(from, from + limit - 1);

  const { data, error, count } = await query;
  if (error) throw new ApiError(500, 'Failed to fetch meal plans');

  // Fetch all available future menu dates (no limit)
  const today = new Date().toISOString().split('T')[0];
  
  const plansWithMenu = await Promise.all(
    data.map(async (plan) => {
      const { data: menuData } = await supabaseAdmin
        .from('meal_plan_menu_view')
        .select('*')
        .eq('meal_plan_id', plan.id)
        .gte('menu_date', today)
        .order('menu_date', { ascending: true });
      
      return {
        ...plan,
        day_menu: menuData || []
      };
    })
  );

  paginatedResponse(res, plansWithMenu, page, limit, count);
}));

// GET FEATURED
router.get('/featured', asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('meal_plans')
    .select('*, vendor:vendors(id, name, image)')
    .eq('is_active', true)
    .eq('is_featured', true)
    .order('sort_order', { ascending: true })
    .limit(6);

  if (error) throw new ApiError(500, 'Failed to fetch');
  successResponse(res, data);
}));

// GET BY ID
router.get('/:id', asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('meal_plans')
    .select('*, vendor:vendors(*)')
    .eq('id', req.params.id)
    .eq('is_active', true)
    .single();

  if (error || !data) throw new ApiError(404, 'Meal plan not found');
  
  // Fetch all available future menu dates
  const today = new Date().toISOString().split('T')[0];
  
  const { data: menuData } = await supabaseAdmin
    .from('meal_plan_menu_view')
    .select('*')
    .eq('meal_plan_id', req.params.id)
    .gte('menu_date', today)
    .order('menu_date', { ascending: true });
  
  successResponse(res, { ...data, day_menu: menuData || [] });
}));

// SUBSCRIBE
router.post('/:id/subscribe', authenticate, asyncHandler(async (req, res) => {
  const { chosen_meals, chosen_days, custom_times, duration, start_date, delivery_address } = req.body;

  const { data: mealPlan } = await supabaseAdmin
    .from('meal_plans').select('*').eq('id', req.params.id).single();

  if (!mealPlan) throw new ApiError(404, 'Meal plan not found');

  const durationDays = { 'Trial Week': 7, '1 Month': 30, '3 Months': 90 };
  const days = durationDays[duration] || 7;
  const deliveryDays = Math.floor(days * (chosen_days.length / 7));
  const totalAmount = mealPlan.price_per_day * deliveryDays;

  const endDate = new Date(start_date);
  endDate.setDate(endDate.getDate() + days);

  const { data: subscription, error } = await supabaseAdmin
    .from('meal_plan_subscriptions')
    .insert({
      user_id: req.user.id, meal_plan_id: req.params.id, chosen_meals, chosen_days,
      custom_times: custom_times || {}, duration, start_date,
      end_date: endDate.toISOString().split('T')[0], total_amount: totalAmount,
      delivery_address: JSON.stringify(delivery_address), status: 'active'
    })
    .select().single();

  if (error) throw new ApiError(500, 'Failed to create subscription');

  successResponse(res, { subscription, totalAmount, days, deliveryDays }, 'Subscribed', 201);
}));

// MY SUBSCRIPTIONS
router.get('/subscriptions/me', authenticate, asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('meal_plan_subscriptions')
    .select('*, meal_plan:meal_plans(id, title, thumbnail)')
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false });

  if (error) throw new ApiError(500, 'Failed to fetch');
  successResponse(res, data);
}));

// PAUSE/RESUME/CANCEL
router.post('/subscriptions/:id/pause', authenticate, asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('meal_plan_subscriptions')
    .update({ status: 'paused' }).eq('id', req.params.id).eq('user_id', req.user.id).select().single();
  if (error) throw new ApiError(400, 'Cannot pause');
  successResponse(res, data, 'Paused');
}));

router.post('/subscriptions/:id/resume', authenticate, asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('meal_plan_subscriptions')
    .update({ status: 'active' }).eq('id', req.params.id).eq('user_id', req.user.id).select().single();
  if (error) throw new ApiError(400, 'Cannot resume');
  successResponse(res, data, 'Resumed');
}));

router.post('/subscriptions/:id/cancel', authenticate, asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('meal_plan_subscriptions')
    .update({ status: 'cancelled' }).eq('id', req.params.id).eq('user_id', req.user.id).select().single();
  if (error) throw new ApiError(400, 'Cannot cancel');
  successResponse(res, data, 'Cancelled');
}));

export default router;

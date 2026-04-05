import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

// ============================================================================
// MEAL CALENDAR (Date assignments with 4 template slots)
// ============================================================================

// GET CALENDAR FOR MEAL PLAN
router.get('/:mealPlanId', asyncHandler(async (req, res) => {
  const { mealPlanId } = req.params;
  const { startDate, endDate, days = 7 } = req.query;

  const start = startDate || new Date().toISOString().split('T')[0];
  const end = endDate || new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

  const { data, error } = await supabaseAdmin
    .from('meal_plan_menu_view')
    .select('*')
    .eq('meal_plan_id', mealPlanId)
    .gte('menu_date', start)
    .lte('menu_date', end)
    .order('menu_date', { ascending: true });

  if (error) throw new ApiError(500, `Failed to fetch calendar: ${error.message}`);

  successResponse(res, data);
}));

// GET MENU FOR SPECIFIC DATE
router.get('/:mealPlanId/date/:date', asyncHandler(async (req, res) => {
  const { mealPlanId, date } = req.params;

  const { data, error } = await supabaseAdmin
    .from('meal_plan_menu_view')
    .select('*')
    .eq('meal_plan_id', mealPlanId)
    .eq('menu_date', date)
    .single();

  if (error || !data) throw new ApiError(404, 'No menu found for this date');

  successResponse(res, data);
}));

// ASSIGN TEMPLATE TO MEAL SLOT
router.post('/assign', authenticate, asyncHandler(async (req, res) => {
  const {
    meal_plan_id,
    template_code,
    meal_slot, // 'breakfast', 'lunch', 'dinner', 'snack'
    start_date,
    end_date,
    day_of_week // optional: 0-6 for specific days only
  } = req.body;

  if (!meal_plan_id || !template_code || !meal_slot || !start_date || !end_date) {
    throw new ApiError(400, 'Missing required fields');
  }

  if (!['breakfast', 'lunch', 'dinner', 'snack'].includes(meal_slot)) {
    throw new ApiError(400, 'Invalid meal_slot. Must be: breakfast, lunch, dinner, or snack');
  }

  // Call PostgreSQL function
  const { data, error } = await supabaseAdmin.rpc('assign_template_to_meal', {
    p_meal_plan_id: meal_plan_id,
    p_template_code: template_code,
    p_meal_slot: meal_slot,
    p_start_date: start_date,
    p_end_date: end_date,
    p_day_of_week: day_of_week || null
  });

  if (error) throw new ApiError(500, `Failed to assign template: ${error.message}`);

  successResponse(
    res,
    { rows_affected: data },
    `Assigned ${template_code} to ${meal_slot} for ${data} dates`
  );
}));

// UPDATE SPECIFIC DATE
router.put('/:mealPlanId/date/:date', authenticate, asyncHandler(async (req, res) => {
  const { mealPlanId, date } = req.params;
  const {
    breakfast_template_code,
    lunch_template_code,
    dinner_template_code,
    snack_template_code,
    is_available,
    notes
  } = req.body;

  // Get vendor_id from meal plan
  const { data: mealPlan } = await supabaseAdmin
    .from('meal_plans')
    .select('vendor_id')
    .eq('id', mealPlanId)
    .single();

  if (!mealPlan) throw new ApiError(404, 'Meal plan not found');

  // Build update object
  const updateData = {};
  
  if (breakfast_template_code !== undefined) {
    const { data: template } = await supabaseAdmin
      .from('meal_templates')
      .select('id')
      .eq('vendor_id', mealPlan.vendor_id)
      .eq('template_code', breakfast_template_code)
      .single();
    updateData.breakfast_template_id = template?.id || null;
    updateData.breakfast_template_code = breakfast_template_code;
  }

  if (lunch_template_code !== undefined) {
    const { data: template } = await supabaseAdmin
      .from('meal_templates')
      .select('id')
      .eq('vendor_id', mealPlan.vendor_id)
      .eq('template_code', lunch_template_code)
      .single();
    updateData.lunch_template_id = template?.id || null;
    updateData.lunch_template_code = lunch_template_code;
  }

  if (dinner_template_code !== undefined) {
    const { data: template } = await supabaseAdmin
      .from('meal_templates')
      .select('id')
      .eq('vendor_id', mealPlan.vendor_id)
      .eq('template_code', dinner_template_code)
      .single();
    updateData.dinner_template_id = template?.id || null;
    updateData.dinner_template_code = dinner_template_code;
  }

  if (snack_template_code !== undefined) {
    const { data: template } = await supabaseAdmin
      .from('meal_templates')
      .select('id')
      .eq('vendor_id', mealPlan.vendor_id)
      .eq('template_code', snack_template_code)
      .single();
    updateData.snack_template_id = template?.id || null;
    updateData.snack_template_code = snack_template_code;
  }

  if (is_available !== undefined) updateData.is_available = is_available;
  if (notes !== undefined) updateData.notes = notes;

  // Check if calendar entry exists, insert or update
  const { data: existing } = await supabaseAdmin
    .from('meal_plan_calendar')
    .select('id')
    .eq('meal_plan_id', mealPlanId)
    .eq('menu_date', date)
    .single();

  let result;
  if (existing) {
    const { data, error } = await supabaseAdmin
      .from('meal_plan_calendar')
      .update(updateData)
      .eq('id', existing.id)
      .select()
      .single();
    if (error) throw new ApiError(500, 'Failed to update calendar');
    result = data;
  } else {
    const { data, error } = await supabaseAdmin
      .from('meal_plan_calendar')
      .insert({
        meal_plan_id: mealPlanId,
        menu_date: date,
        ...updateData
      })
      .select()
      .single();
    if (error) throw new ApiError(500, 'Failed to create calendar entry');
    result = data;
  }

  successResponse(res, result, 'Calendar updated');
}));

// DELETE CALENDAR ENTRY (clear menu for date)
router.delete('/:mealPlanId/date/:date', authenticate, asyncHandler(async (req, res) => {
  const { mealPlanId, date } = req.params;

  const { error } = await supabaseAdmin
    .from('meal_plan_calendar')
    .delete()
    .eq('meal_plan_id', mealPlanId)
    .eq('menu_date', date);

  if (error) throw new ApiError(500, 'Failed to delete calendar entry');

  successResponse(res, null, 'Calendar entry deleted');
}));

// BULK CREATE/UPDATE CALENDAR ENTRIES
router.post('/bulk', authenticate, asyncHandler(async (req, res) => {
  const { entries } = req.body; // Array of calendar objects

  if (!Array.isArray(entries) || entries.length === 0) {
    throw new ApiError(400, 'entries array is required');
  }

  const { data, error } = await supabaseAdmin
    .from('meal_plan_calendar')
    .upsert(entries, { onConflict: 'meal_plan_id,menu_date' })
    .select();

  if (error) throw new ApiError(500, `Failed to bulk update: ${error.message}`);

  successResponse(res, data, `${data.length} calendar entries created/updated`);
}));

export default router;

import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

// ============================================================================
// MEAL TEMPLATES (Individual Food Items with GZ_X codes)
// ============================================================================

// GET ALL TEMPLATES FOR A VENDOR
router.get('/vendor/:vendorId', asyncHandler(async (req, res) => {
  const { vendorId } = req.params;
  const { meal_type, is_active = 'true' } = req.query;

  let query = supabaseAdmin
    .from('meal_templates')
    .select('*')
    .eq('vendor_id', vendorId);

  if (meal_type && meal_type !== 'any') {
    query = query.in('meal_type', [meal_type, 'any']);
  }
  
  if (is_active === 'true') {
    query = query.eq('is_active', true);
  }

  query = query.order('template_code', { ascending: true });

  const { data, error } = await query;
  if (error) throw new ApiError(500, 'Failed to fetch templates');

  successResponse(res, data);
}));

// GET TEMPLATE BY CODE
router.get('/vendor/:vendorId/code/:code', asyncHandler(async (req, res) => {
  const { vendorId, code } = req.params;

  const { data, error } = await supabaseAdmin
    .from('meal_templates')
    .select('*')
    .eq('vendor_id', vendorId)
    .eq('template_code', code)
    .single();

  if (error || !data) throw new ApiError(404, 'Template not found');
  successResponse(res, data);
}));

// CREATE NEW TEMPLATE (Auto-assigns GZ_X code)
router.post('/', authenticate, asyncHandler(async (req, res) => {
  const {
    vendor_id,
    item_name,
    item_description,
    image_url,
    product_id,
    calories,
    protein_grams,
    carbs_grams,
    fat_grams,
    meal_type = 'any'
  } = req.body;

  if (!vendor_id || !item_name) {
    throw new ApiError(400, 'vendor_id and item_name are required');
  }

  // Insert without template_code - trigger will auto-generate it
  const { data, error } = await supabaseAdmin
    .from('meal_templates')
    .insert({
      vendor_id,
      item_name,
      item_description,
      image_url,
      product_id,
      calories,
      protein_grams,
      carbs_grams,
      fat_grams,
      meal_type
    })
    .select()
    .single();

  if (error) throw new ApiError(500, `Failed to create template: ${error.message}`);

  successResponse(
    res,
    data,
    `Template created with code ${data.template_code}`,
    201
  );
}));

// UPDATE TEMPLATE
router.put('/:id', authenticate, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updateFields = req.body;

  // Don't allow updating template_code or vendor_id
  delete updateFields.template_code;
  delete updateFields.vendor_id;

  const { data, error } = await supabaseAdmin
    .from('meal_templates')
    .update(updateFields)
    .eq('id', id)
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to update template');
  if (!data) throw new ApiError(404, 'Template not found');

  successResponse(res, data, 'Template updated. All dates using this template will reflect changes.');
}));

// DELETE TEMPLATE (with usage check)
router.delete('/:id', authenticate, asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Check if template is in use
  const { data: usageCheck } = await supabaseAdmin.rpc('count', {
    table_name: 'meal_plan_calendar',
    conditions: {
      or: [
        { breakfast_template_id: id },
        { lunch_template_id: id },
        { dinner_template_id: id },
        { snack_template_id: id }
      ]
    }
  }).gte('menu_date', new Date().toISOString().split('T')[0]);

  if (usageCheck && usageCheck > 0) {
    throw new ApiError(
      400,
      `Cannot delete template. It's assigned to ${usageCheck} upcoming dates. Unassign it first.`
    );
  }

  const { error } = await supabaseAdmin
    .from('meal_templates')
    .delete()
    .eq('id', id);

  if (error) throw new ApiError(500, 'Failed to delete template');

  successResponse(res, null, 'Template deleted');
}));

// TOGGLE ACTIVE STATUS
router.patch('/:id/toggle-active', authenticate, asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: current } = await supabaseAdmin
    .from('meal_templates')
    .select('is_active')
    .eq('id', id)
    .single();

  if (!current) throw new ApiError(404, 'Template not found');

  const { data, error } = await supabaseAdmin
    .from('meal_templates')
    .update({ is_active: !current.is_active })
    .eq('id', id)
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to toggle status');

  successResponse(res, data, `Template ${data.is_active ? 'activated' : 'deactivated'}`);
}));

export default router;

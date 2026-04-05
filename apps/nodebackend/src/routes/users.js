import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';
import { validate, schemas } from '../middleware/validate.js';

const router = express.Router();

// All routes require authentication
router.use(authenticate);

// ============================================
// GET CURRENT USER PROFILE
// GET /api/users/me
// ============================================
router.get('/me', asyncHandler(async (req, res) => {
  const { data: user, error } = await supabaseAdmin
    .from('users')
    .select(`
      *,
      addresses:user_addresses(*)
    `)
    .eq('id', req.user.id)
    .single();

  if (error) throw new ApiError(500, 'Failed to fetch profile');

  successResponse(res, user);
}));

// ============================================
// UPDATE USER PROFILE
// PUT /api/users/me
// ============================================
router.put('/me', validate(schemas.updateUser), asyncHandler(async (req, res) => {
  const updates = req.body;

  const { data: user, error } = await supabaseAdmin
    .from('users')
    .update({
      ...updates,
      updated_at: new Date().toISOString()
    })
    .eq('id', req.user.id)
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to update profile');

  successResponse(res, user, 'Profile updated successfully');
}));

// ============================================
// GET USER ADDRESSES
// GET /api/users/addresses
// ============================================
router.get('/addresses', asyncHandler(async (req, res) => {
  const { data: addresses, error } = await supabaseAdmin
    .from('user_addresses')
    .select('*')
    .eq('user_id', req.user.id)
    .order('is_default', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) throw new ApiError(500, 'Failed to fetch addresses');

  successResponse(res, addresses);
}));

// ============================================
// ADD NEW ADDRESS
// POST /api/users/addresses
// ============================================
router.post('/addresses', validate(schemas.createAddress), asyncHandler(async (req, res) => {
  const addressData = req.body;

  // If this is default, unset other defaults
  if (addressData.is_default) {
    await supabaseAdmin
      .from('user_addresses')
      .update({ is_default: false })
      .eq('user_id', req.user.id);
  }

  // Check if this is first address (make it default)
  const { count } = await supabaseAdmin
    .from('user_addresses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', req.user.id);

  const { data: address, error } = await supabaseAdmin
    .from('user_addresses')
    .insert({
      user_id: req.user.id,
      ...addressData,
      type: addressData.label.toLowerCase(), // Map label (Home) to type (home)
      is_default: count === 0 ? true : addressData.is_default,
      full_address: addressData.full_address || 
        `${addressData.street}, ${addressData.area}, ${addressData.city} - ${addressData.zipcode}`
    })
    .select()
    .single();

  if (error) {
    console.error('Supabase Error (Create Address):', error);
    throw new ApiError(500, 'Failed to add address');
  }

  successResponse(res, address, 'Address added successfully', 201);
}));

// ============================================
// UPDATE ADDRESS
// PUT /api/users/addresses/:id
// ============================================
router.put('/addresses/:id', validate(schemas.createAddress), asyncHandler(async (req, res) => {
  const { id } = req.params;
  const addressData = req.body;

  // Verify ownership
  const { data: existing } = await supabaseAdmin
    .from('user_addresses')
    .select('id')
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (!existing) throw new ApiError(404, 'Address not found');

  // If setting as default, unset others
  if (addressData.is_default) {
    await supabaseAdmin
      .from('user_addresses')
      .update({ is_default: false })
      .eq('user_id', req.user.id)
      .neq('id', id);
  }

  const { data: address, error } = await supabaseAdmin
    .from('user_addresses')
    .update({
      ...addressData,
      type: addressData.label.toLowerCase(),
      full_address: addressData.full_address || 
        `${addressData.street}, ${addressData.area}, ${addressData.city} - ${addressData.zipcode}`,
      updated_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to update address');

  successResponse(res, address, 'Address updated successfully');
}));

// ============================================
// DELETE ADDRESS
// DELETE /api/users/addresses/:id
// ============================================
router.delete('/addresses/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Verify ownership
  const { data: existing } = await supabaseAdmin
    .from('user_addresses')
    .select('id, is_default')
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (!existing) throw new ApiError(404, 'Address not found');

  const { error } = await supabaseAdmin
    .from('user_addresses')
    .delete()
    .eq('id', id);

  if (error) throw new ApiError(500, 'Failed to delete address');

  // If deleted was default, set another as default
  if (existing.is_default) {
    const { data: nextAddress } = await supabaseAdmin
      .from('user_addresses')
      .select('id')
      .eq('user_id', req.user.id)
      .limit(1)
      .single();

    if (nextAddress) {
      await supabaseAdmin
        .from('user_addresses')
        .update({ is_default: true })
        .eq('id', nextAddress.id);
    }
  }

  successResponse(res, null, 'Address deleted successfully');
}));

// ============================================
// SET DEFAULT ADDRESS
// PATCH /api/users/addresses/:id/default
// ============================================
router.patch('/addresses/:id/default', asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Verify ownership
  const { data: existing } = await supabaseAdmin
    .from('user_addresses')
    .select('id')
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (!existing) throw new ApiError(404, 'Address not found');

  // Unset all defaults
  await supabaseAdmin
    .from('user_addresses')
    .update({ is_default: false })
    .eq('user_id', req.user.id);

  // Set this as default
  const { data: address, error } = await supabaseAdmin
    .from('user_addresses')
    .update({ is_default: true })
    .eq('id', id)
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to set default address');

  successResponse(res, address, 'Default address updated');
}));

// ============================================
// GET USER STATS
// GET /api/users/stats
// ============================================
router.get('/stats', asyncHandler(async (req, res) => {
  const { data: user } = await supabaseAdmin
    .from('users')
    .select('total_orders, total_spent, loyalty_points, membership_tier')
    .eq('id', req.user.id)
    .single();

  // Get active subscriptions count
  const { count: activeSubscriptions } = await supabaseAdmin
    .from('product_subscriptions')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', req.user.id)
    .eq('status', 'active');

  // Get pending orders count
  const { count: pendingOrders } = await supabaseAdmin
    .from('orders')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', req.user.id)
    .in('status', ['placed', 'confirmed', 'preparing', 'ready']);

  successResponse(res, {
    ...user,
    activeSubscriptions: activeSubscriptions || 0,
    pendingOrders: pendingOrders || 0
  });
}));

export default router;

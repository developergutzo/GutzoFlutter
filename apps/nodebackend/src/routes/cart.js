import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';
import { validate, schemas } from '../middleware/validate.js';

const router = express.Router();

// All cart routes require authentication
router.use(authenticate);

// ============================================
// GET CART
// GET /api/cart
// ============================================
router.get('/', asyncHandler(async (req, res) => {
  const { data: cartItems, error } = await supabaseAdmin
    .from('cart')
    .select(`
      *,
      product:products(*),
      vendor:vendors(id, name, image, minimum_order, delivery_fee, is_open)
    `)
    .eq('user_phone', req.user.phone)
    .order('created_at', { ascending: false });

  if (error) throw new ApiError(500, 'Failed to fetch cart');

  // Group by vendor
  const vendorGroups = {};
  let totalItems = 0;
  let totalAmount = 0;

  (cartItems || []).forEach(item => {
    const vendorId = item.vendor_id;
    if (!vendorGroups[vendorId]) {
      vendorGroups[vendorId] = {
        vendor: item.vendor,
        items: [],
        subtotal: 0
      };
    }

    const itemTotal = (item.product?.price || 0) * item.quantity;
    vendorGroups[vendorId].items.push({
      ...item,
      itemTotal
    });
    vendorGroups[vendorId].subtotal += itemTotal;
    totalItems += item.quantity;
    totalAmount += itemTotal;
  });

  successResponse(res, {
    items: cartItems || [],
    vendorGroups: Object.values(vendorGroups),
    summary: {
      totalItems,
      totalAmount,
      vendorCount: Object.keys(vendorGroups).length
    }
  });
}));

// ============================================
// SYNC CART (Bulk Replace)
// POST /api/cart/sync
// ============================================
router.post('/sync', asyncHandler(async (req, res) => {
  const { items } = req.body; // Expects { items: [...] }

  if (!Array.isArray(items)) {
    throw new ApiError(400, 'Items array is required');
  }

  // 1. Clear existing cart
  const { error: deleteError } = await supabaseAdmin
    .from('cart')
    .delete()
    .eq('user_phone', req.user.phone);

  if (deleteError) {
    throw new ApiError(500, 'Failed to clear cart for sync');
  }

  if (items.length === 0) {
    return successResponse(res, { items: [] }, 'Cart cleared');
  }

  // 2. Prepare new items
  // We need to fetch products to get vendor_id if not provided, but
  // usually the frontend sends vendor_id.
  // We'll rely on the input items having product_id, vendor_id, quantity.

  const formattedItems = items.map(item => ({
    user_phone: req.user.phone,
    product_id: item.productId || item.product_id,
    vendor_id: item.vendorId || item.vendor_id,
    quantity: item.quantity,
    variant_id: item.variantId || item.variant_id || null,
    addons: item.addons ? JSON.stringify(item.addons) : null,
    special_instructions: item.specialInstructions || item.special_instructions || null,
    metadata: item.metadata || null,
    created_at: new Date().toISOString()
  }));

  // 3. Bulk insert
  // 3. Bulk insert with fallback for bad data
  try {
    const { data: newItems, error: insertError } = await supabaseAdmin
      .from('cart')
      .insert(formattedItems)
      .select();

    if (insertError) throw insertError;

    successResponse(res, { items: newItems }, 'Cart synced successfully');
  } catch (batchError) {
    console.warn('⚠️ Batch insert failed, attempting serial insert to salvage valid items:', batchError.message);

    // Fallback: Insert valid items one by one
    const savedItems = [];
    for (const item of formattedItems) {
      try {
        const { data: savedItem, error: singleError } = await supabaseAdmin
          .from('cart')
          .insert(item)
          .select()
          .single();

        if (!singleError && savedItem) {
          savedItems.push(savedItem);
        }
      } catch (e) {
        console.warn(`Skipping invalid cart item during sync (Product: ${item.product_id}):`, e.message);
      }
    }

    if (savedItems.length === 0 && formattedItems.length > 0) {
      // If we couldn't save ANY items, throw the original error
      throw new ApiError(500, `Failed to sync cart: ${batchError.message}`);
    }

    // console.log(`✅ Recovered ${savedItems.length}/${formattedItems.length} items via serial insert`);
    successResponse(res, { items: savedItems }, 'Cart synced (some invalid items removed)');
  }
}));

// ============================================
// ADD TO CART
// POST /api/cart
// ============================================
router.post('/', validate(schemas.addToCart), asyncHandler(async (req, res) => {
  const { product_id, vendor_id, quantity, variant_id, addons, special_instructions, metadata } = req.body;

  // Verify product exists and is available
  const { data: product, error: productError } = await supabaseAdmin
    .from('products')
    .select('*, vendor:vendors(id, is_open, is_active)')
    .eq('id', product_id)
    .single();

  if (productError || !product) throw new ApiError(404, 'Product not found');
  if (!product.is_available) throw new ApiError(400, 'Product is not available');
  if (!product.vendor?.is_open) throw new ApiError(400, 'Vendor is currently closed');

  // Check if item already exists in cart
  const { data: existingItem } = await supabaseAdmin
    .from('cart')
    .select('*')
    .eq('user_phone', req.user.phone)
    .eq('product_id', product_id)
    .single();

  if (existingItem) {
    // Update quantity
    const newQuantity = existingItem.quantity + quantity;

    // Check max order quantity
    if (product.max_order_qty && newQuantity > product.max_order_qty) {
      throw new ApiError(400, `Maximum ${product.max_order_qty} items allowed`);
    }

    const { data: updated, error: updateError } = await supabaseAdmin
      .from('cart')
      .update({
        quantity: newQuantity,
        updated_at: new Date().toISOString()
      })
      .eq('id', existingItem.id)
      .select()
      .single();

    if (updateError) throw new ApiError(500, 'Failed to update cart');

    return successResponse(res, updated, 'Cart updated');
  }

  // Add new item
  const { data: cartItem, error: insertError } = await supabaseAdmin
    .from('cart')
    .insert({
      user_phone: req.user.phone,
      product_id,
      vendor_id,
      quantity,
      variant_id,
      addons: addons ? JSON.stringify(addons) : null,
      special_instructions,
      metadata: metadata || null
    })
    .select()
    .single();

  if (insertError) throw new ApiError(500, 'Failed to add to cart');

  successResponse(res, cartItem, 'Added to cart', 201);
}));

// ============================================
// UPDATE CART ITEM
// PUT /api/cart/:id
// ============================================
router.put('/:id', validate(schemas.updateCartItem), asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { quantity, addons, special_instructions, metadata } = req.body;

  // Verify ownership
  const { data: existingItem } = await supabaseAdmin
    .from('cart')
    .select('*, product:products(max_order_qty)')
    .eq('id', id)
    .eq('user_phone', req.user.phone)
    .single();

  if (!existingItem) throw new ApiError(404, 'Cart item not found');

  // Check max quantity
  if (existingItem.product?.max_order_qty && quantity > existingItem.product.max_order_qty) {
    throw new ApiError(400, `Maximum ${existingItem.product.max_order_qty} items allowed`);
  }

  // If quantity is 0, delete the item
  if (quantity === 0) {
    const { error: deleteError } = await supabaseAdmin
      .from('cart')
      .delete()
      .eq('id', id);

    if (deleteError) throw new ApiError(500, 'Failed to remove item');

    return successResponse(res, null, 'Item removed from cart');
  }

  const { data: updated, error: updateError } = await supabaseAdmin
    .from('cart')
    .update({
      quantity,
      addons: addons ? JSON.stringify(addons) : existingItem.addons,
      special_instructions: special_instructions ?? existingItem.special_instructions,
      metadata: metadata ?? existingItem.metadata,
      updated_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single();

  if (updateError) throw new ApiError(500, 'Failed to update cart');

  successResponse(res, updated, 'Cart updated');
}));

// ============================================
// REMOVE CART ITEM
// DELETE /api/cart/:id
// ============================================
router.delete('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Verify ownership
  const { data: existingItem } = await supabaseAdmin
    .from('cart')
    .select('id')
    .eq('id', id)
    .eq('user_phone', req.user.phone)
    .single();

  if (!existingItem) throw new ApiError(404, 'Cart item not found');

  const { error } = await supabaseAdmin
    .from('cart')
    .delete()
    .eq('id', id);

  if (error) throw new ApiError(500, 'Failed to remove item');

  successResponse(res, null, 'Item removed from cart');
}));

// ============================================
// CLEAR CART
// DELETE /api/cart
// ============================================
router.delete('/', asyncHandler(async (req, res) => {
  const { vendor_id } = req.query;

  let query = supabaseAdmin
    .from('cart')
    .delete()
    .eq('user_phone', req.user.phone);

  if (vendor_id) {
    query = query.eq('vendor_id', vendor_id);
  }

  const { error } = await query;

  if (error) throw new ApiError(500, 'Failed to clear cart');

  successResponse(res, null, vendor_id ? 'Vendor items removed' : 'Cart cleared');
}));

// ============================================
// GET CART COUNT
// GET /api/cart/count
// ============================================
router.get('/count', asyncHandler(async (req, res) => {
  const { data: items, error } = await supabaseAdmin
    .from('cart')
    .select('quantity')
    .eq('user_phone', req.user.phone);

  if (error) throw new ApiError(500, 'Failed to get cart count');

  const totalCount = (items || []).reduce((sum, item) => sum + item.quantity, 0);

  successResponse(res, { count: totalCount });
}));

// ============================================
// VALIDATE CART (Before checkout)
// POST /api/cart/validate
// ============================================
router.post('/validate', asyncHandler(async (req, res) => {
  const { data: cartItems, error } = await supabaseAdmin
    .from('cart')
    .select(`
      *,
      product:products(id, name, price, is_available, max_order_qty),
      vendor:vendors(id, name, is_open, is_active, minimum_order)
    `)
    .eq('user_phone', req.user.phone);

  if (error) throw new ApiError(500, 'Failed to validate cart');

  const issues = [];
  const validItems = [];

  for (const item of cartItems || []) {
    if (!item.product?.is_available) {
      issues.push({ item_id: item.id, issue: `${item.product?.name} is no longer available` });
      continue;
    }
    if (!item.vendor?.is_open) {
      issues.push({ item_id: item.id, issue: `${item.vendor?.name} is currently closed` });
      continue;
    }
    if (item.product?.max_order_qty && item.quantity > item.product.max_order_qty) {
      issues.push({ item_id: item.id, issue: `Maximum ${item.product.max_order_qty} ${item.product.name} allowed` });
      continue;
    }
    validItems.push(item);
  }

  // Check minimum order per vendor
  const vendorTotals = {};
  validItems.forEach(item => {
    if (!vendorTotals[item.vendor_id]) {
      vendorTotals[item.vendor_id] = { vendor: item.vendor, total: 0 };
    }
    vendorTotals[item.vendor_id].total += item.product.price * item.quantity;
  });

  Object.values(vendorTotals).forEach(({ vendor, total }) => {
    if (vendor.minimum_order && total < vendor.minimum_order) {
      issues.push({
        vendor_id: vendor.id,
        issue: `Minimum order ₹${vendor.minimum_order} required for ${vendor.name}. Current: ₹${total}`
      });
    }
  });

  successResponse(res, {
    isValid: issues.length === 0,
    issues,
    validItems
  });
}));

export default router;

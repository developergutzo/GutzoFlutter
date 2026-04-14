import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { sendVendorOTP } from '../utils/emailService.js';

const router = express.Router();

// ============================================
// VENDOR LOGIN
// POST /api/vendor-auth/login
// ============================================
// ============================================
// CHECK VENDOR STATUS
// POST /api/vendor-auth/check-status
// ============================================
router.post('/check-status', asyncHandler(async (req, res) => {
  const { phone } = req.body;
  if (!phone) throw new ApiError(400, 'Phone number is required');

  const cleanPhone = phone.trim();
  const searchPhones = [
    cleanPhone,
    cleanPhone.startsWith('+91') ? cleanPhone.slice(3) : `+91${cleanPhone}`,
    cleanPhone.startsWith('91') ? cleanPhone.slice(2) : `91${cleanPhone}`
  ];

  console.log('🔍 Auth: Checking status for phones:', searchPhones);

  // 1. Check vendors table - fetch full profile for Flutter synchronization
  const { data: vendors, error: vendorError } = await supabaseAdmin
    .from('vendors')
    .select('*')
    .in('phone', searchPhones)
    .limit(1);

  if (vendorError) {
     console.error('❌ Auth: Vendor query error:', vendorError);
  }

  if (vendors && vendors.length > 0) {
    const vendor = vendors[0];
    console.log('✅ Auth: Found vendor:', vendor.name, '(' + vendor.id + ')');
    return successResponse(res, { 
      status: 'vendor',
      vendor: vendor 
    });
  }

  // 2. Check vendor_leads table
  const { data: leads } = await supabaseAdmin
    .from('vendor_leads')
    .select('id, status, remarks')
    .in('phone', searchPhones)
    .limit(1);

  if (leads && leads.length > 0) {
    const lead = leads[0];
    console.log('ℹ️ Auth: Found lead with status:', lead.status);
    return successResponse(res, {
      status: 'lead',
      leadStatus: lead.status,
      leadRemarks: lead.remarks
    });
  }

  // 3. New user
  return successResponse(res, { status: 'new' });
}));

// ============================================
// VENDOR LOGIN
// POST /api/vendor-auth/login
// ============================================
router.post('/login', asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    throw new ApiError(400, 'Email and password are required');
  }

  // Check if vendor exists with this email
  const { data: vendor, error } = await supabaseAdmin
    .from('vendors')
    .select('*')
    .eq('email', email)
    .single();

  if (error || !vendor) {
    throw new ApiError(404, 'Vendor not found'); // Should catch this in check-status theoretically
  }

  if (!vendor.is_active) {
    throw new ApiError(403, 'Account is inactive. Contact Admin.');
  }

  // Verify password (simple exact match for now as stored in DB)
  if (vendor.password !== password) {
    throw new ApiError(401, 'Invalid password');
  }

  // Return success with vendor info
  delete vendor.password; // Don't send password back

  successResponse(res, { vendor }, 'Login successful');
}));

// ============================================
// UPDATE KITCHEN STATUS
// POST /api/vendor-auth/:id/status
// ============================================
router.post('/:id/status', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { isOpen } = req.body;

  const { data: vendor, error } = await supabaseAdmin
    .from('vendors')
    .update({ is_open: isOpen })
    .eq('id', id)
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to update status');

  successResponse(res, { vendor }, 'Status updated successfully');
}));

// ============================================
// GET VENDOR PRODUCTS (MENU)
// GET /api/vendor-auth/:id/products
// ============================================
router.get('/:id/products', asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Fetch products ordered by sort_order or created_at
  const { data: products, error } = await supabaseAdmin
    .from('products')
    .select('*')
    .eq('vendor_id', id)
    .order('sort_order', { ascending: true });

  if (error) throw new ApiError(500, 'Failed to fetch menu');

  successResponse(res, { products });
}));

// ============================================
// ADD PRODUCT
// POST /api/vendor-auth/:id/products
// ============================================
// ============================================
// ADD PRODUCT
// POST /api/vendor-auth/:id/products
// ============================================
router.post('/:id/products', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { name, description, price, image, image_url, category, is_veg, dietary_type, is_available, addon_ids, parent_product_ids, nutrition } = req.body;

  const { data: product, error } = await supabaseAdmin
    .from('products')
    .insert({
      id: req.body.id, // Use explicit ID if provided (for folder consistency)
      vendor_id: id,
      name,
      description,
      price,
      image_url: image_url || image,
      category,
      is_veg: is_veg ?? true,
      dietary_type: dietary_type || (is_veg === false ? 'non-veg' : 'veg'),
      is_available: is_available ?? true,
      nutritional_info: nutrition || null,
      rating: 0,
      sort_order: 999,
      addon_ids: addon_ids || []
    })
    .select()
    .single();

  if (error) {
    console.error('Create Product Info:', error);
    throw new ApiError(500, `Failed to create product: ${error.message}`);
  }

  // Handle Link as Addon (Parent Products)
  if (parent_product_ids && Array.isArray(parent_product_ids) && parent_product_ids.length > 0) {
    // Fetch current addons of these parents
    const { data: parents } = await supabaseAdmin
      .from('products')
      .select('id, addon_ids')
      .in('id', parent_product_ids);

    if (parents) {
      for (const parent of parents) {
        const currentAddons = parent.addon_ids || [];
        if (!currentAddons.includes(product.id)) {
          await supabaseAdmin
            .from('products')
            .update({ addon_ids: [...currentAddons, product.id] })
            .eq('id', parent.id);
        }
      }
    }
  }

  successResponse(res, { product }, 'Product added successfully');
}));

// ============================================
// UPDATE PRODUCT
// PUT /api/vendor-auth/:id/products/:productId
// ============================================
router.put('/:id/products/:productId', asyncHandler(async (req, res) => {
  const { productId } = req.params;
  const { addon_ids, parent_product_ids, ...updates } = req.body;

  // Prepare update payload
  const payload = { ...updates };
  if (addon_ids) payload.addon_ids = addon_ids;

  const { data: product, error } = await supabaseAdmin
    .from('products')
    .update(payload)
    .eq('id', productId)
    .select()
    .single();

  if (error) throw new ApiError(500, 'Failed to update product');

  // Handle Link as Addon (Parent Products)
  if (parent_product_ids && Array.isArray(parent_product_ids) && parent_product_ids.length > 0) {
    const { data: parents } = await supabaseAdmin
      .from('products')
      .select('id, addon_ids')
      .in('id', parent_product_ids);

    if (parents) {
      for (const parent of parents) {
        const currentAddons = parent.addon_ids || [];
        if (!currentAddons.includes(productId)) {
          await supabaseAdmin
            .from('products')
            .update({ addon_ids: [...currentAddons, productId] })
            .eq('id', parent.id);
        }
      }
    }
  }

  successResponse(res, { product }, 'Product updated successfully');
}));

// ============================================
// DELETE PRODUCT
// DELETE /api/vendor-auth/:id/products/:productId
// ============================================
router.delete('/:id/products/:productId', asyncHandler(async (req, res) => {
  const { productId } = req.params;

  const { error } = await supabaseAdmin
    .from('products')
    .delete()
    .eq('id', productId);

  if (error) throw new ApiError(500, 'Failed to delete product');

  successResponse(res, null, 'Product deleted successfully');
}));

// ============================================
// UPDATE VENDOR PROFILE
// PUT /api/vendor-auth/:id/profile
// ============================================
router.put('/:id/profile', asyncHandler(async (req, res) => {
  const { id } = req.params;

  // 1. Define allowed fields for profile update to prevent column mismatch errors
  const allowedFields = [
    'name', 'description', 'address', 'cuisine_type', 'phone', 'pincode',
    'company_type', 'owner_name', 'company_reg_no', 'owner_aadhar_no',
    'pan_card_no', 'fssai_license', 'gst_number', 'bank_account_no',
    'ifsc_code', 'bank_name', 'account_holder_name', 'image',
    'latitude', 'longitude'
  ];



  // 2. Filter the body
  const updates = {};
  allowedFields.forEach(field => {
    // Only include field if it's provided and not an empty string
    // This prevents violating check constraints on empty mandatory fields like company_type
    if (req.body[field] !== undefined && req.body[field] !== "") {
      updates[field] = req.body[field];
    }
  });


  console.log('📝 Profile Update: Applying updates for vendor:', id, Object.keys(updates));

  // 3. Update Supabase
  const { data: vendor, error } = await supabaseAdmin
    .from('vendors')
    .update(updates)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    console.error('❌ Profile Update Error:', error);
    throw new ApiError(500, `Failed to update profile: ${error.message}`);
  }

  successResponse(res, { vendor }, 'Profile updated successfully');
}));

// ============================================
// GET DASHBOARD STATS
// GET /api/vendor-auth/:id/dashboard-stats
// ============================================
router.get('/:id/dashboard-stats', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();

  // 1. Fetch Today's Orders & Revenue
  const { data: orders, error: ordersError } = await supabaseAdmin
    .from('orders')
    .select('total_amount, status')
    .eq('vendor_id', id)
    .gte('created_at', startOfDay);

  if (ordersError) throw new ApiError(500, 'Failed to fetch sales stats');

  const validOrders = orders?.filter(o => o.status !== 'cancelled' && o.status !== 'rejected') || [];
  const todayOrders = validOrders.length;
  const todayRevenue = validOrders.reduce((sum, o) => sum + (o.total_amount || 0), 0);

  // 2. Fetch Vendor Rating
  const { data: vendor } = await supabaseAdmin
    .from('vendors')
    .select('rating')
    .eq('id', id)
    .single();

  successResponse(res, {
    todayOrders,
    todayRevenue,
    rating: vendor?.rating || 4.8,
    views: Math.floor(Math.random() * 50) + 20 // Mock views for now
  });
}));


// ============================================
// FORGOT PASSWORD - REQUEST OTP
// POST /api/vendor-auth/forgot-password
// ============================================
router.post('/forgot-password', asyncHandler(async (req, res) => {
  const { email } = req.body;
  if (!email) throw new ApiError(400, 'Email is required');

  // Check if vendor exists
  const { data: vendor } = await supabaseAdmin
    .from('vendors')
    .select('id, email')
    .eq('email', email)
    .single();

  if (!vendor) throw new ApiError(404, 'No account found with this email');

  // Generate 6 digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

  // Store in DB (Update vendor record)
  const { error } = await supabaseAdmin
    .from('vendors')
    .update({ otp, otp_expires_at: expiresAt })
    .eq('email', email);

  if (error) throw new ApiError(500, 'Failed to generate OTP');

  // Send Email
  await sendVendorOTP(email, otp);

  successResponse(res, null, 'OTP sent to your email');
}));

// ============================================
// VERIFY OTP
// POST /api/vendor-auth/verify-otp
// ============================================
router.post('/verify-otp', asyncHandler(async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) throw new ApiError(400, 'Email and OTP required');

  const { data: vendor, error } = await supabaseAdmin
    .from('vendors')
    .select('id, otp, otp_expires_at')
    .eq('email', email)
    .single();

  if (error || !vendor) throw new ApiError(400, 'Invalid request');

  // Verify OTP and Expiry
  if (vendor.otp !== otp) throw new ApiError(400, 'Invalid OTP');
  if (new Date(vendor.otp_expires_at) < new Date()) throw new ApiError(400, 'OTP has expired');

  successResponse(res, { valid: true }, 'OTP Verified');
}));

// ============================================
// RESET PASSWORD
// POST /api/vendor-auth/reset-password
// ============================================
router.post('/reset-password', asyncHandler(async (req, res) => {
  const { email, otp, newPassword } = req.body;
  if (!email || !otp || !newPassword) throw new ApiError(400, 'All fields required');

  // Verify OTP again (double check)
  const { data: vendor } = await supabaseAdmin
    .from('vendors')
    .select('id, otp, otp_expires_at')
    .eq('email', email)
    .single();

  if (!vendor || vendor.otp !== otp || new Date(vendor.otp_expires_at) < new Date()) {
    throw new ApiError(400, 'Invalid or expired OTP');
  }

  // Update Password and Clear OTP
  const { error: updateError } = await supabaseAdmin
    .from('vendors')
    .update({
      password: newPassword,
      otp: null,
      otp_expires_at: null
    })
    .eq('email', email);

  if (updateError) throw new ApiError(500, 'Failed to reset password');

  successResponse(res, null, 'Password reset successful. Please login.');
}));

// ============================================
// GET VENDOR ORDERS
// GET /api/vendor-auth/:id/orders
// ============================================
router.get('/:id/orders', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { status, limit = 50 } = req.query;

  let query = supabaseAdmin
    .from('orders')
    .select(`
        *,
        items:order_items(*),
        delivery:deliveries(*)
      `)
    .eq('vendor_id', id)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (status) {
    // Support comma separated statuses e.g. "placed,confirmed,preparing"
    const statuses = status.split(',');
    query = query.in('status', statuses);
  }

  const { data: rawOrders, error } = await query;

  const fs = await import('fs');
  const path = await import('path');
  const logFile = path.resolve('shadowfax_debug.log');
  fs.appendFileSync(logFile, `\n📦 [Vendor Orders Debug] Fetching for Vendor: ${id}\nRaw Count: ${rawOrders?.length || 0}\nData: ${JSON.stringify(rawOrders?.map(o => ({ id: o.order_number, status: o.status, del: o.delivery?.[0]?.status })), null, 2)}\n`);

  if (error) {
    console.error('❌ Vendor Orders Error:', error);
    throw new ApiError(500, `Failed to fetch vendor orders: ${error.message}`);
  }

  console.log(`📦 [Vendor Orders Debug] Raw Orders (count: ${rawOrders.length}):`, JSON.stringify(rawOrders.map(o => ({ id: o.order_number, status: o.status, del: o.delivery?.[0]?.status })), null, 2));

  // FILTER: Only show orders that are either:
  // 1. Not Shadowfax orders (no delivery record)
  // 2. Shadowfax orders that have been ACCEPTED or further 
  // (Filter out those searching for rider: CREATED, searching_rider, pending)
  const orders = rawOrders.filter(order => {
    const delivery = Array.isArray(order.delivery) ? order.delivery[0] : order.delivery;
    const isSearching = delivery && ['CREATED', 'searching_rider', 'pending'].includes(delivery.status);
    // console.log(`🔍 [Filter Debug] Order ${order.order_number}: status=${order.status}, del=${delivery?.status}, isSearching=${isSearching}`);
    return !isSearching;
  });

  console.log(`📦 [Vendor Orders Debug] Screened Orders:`, orders.length);

  successResponse(res, { orders });
}));

// ============================================
// UPDATE VENDOR ORDER STATUS
// PATCH /api/vendor-auth/:id/orders/:orderId/status
// ============================================
router.patch('/:id/orders/:orderId/status', asyncHandler(async (req, res) => {
  const { id, orderId } = req.params;
  const { status } = req.body;

  if (!['preparing', 'ready', 'completed', 'rejected'].includes(status)) {
    throw new ApiError(400, 'Invalid status update');
  }

  // Verify order belongs to vendor
  const { data: order, error } = await supabaseAdmin
    .from('orders')
    .update({ status })
    .eq('id', orderId)
    .eq('vendor_id', id)
    .select()
    .single();

  if (error || !order) throw new ApiError(404, 'Order not found or update failed');

  // Send Notification to User if needed (e.g. "Your food is being prepared")
  if (status === 'preparing') {
    await supabaseAdmin.from('notifications').insert({
      user_id: order.user_id,
      type: 'order_update',
      title: 'Order Preparing 🍳',
      message: `The kitchen has started preparing your order #${order.order_number}`,
      data: { order_id: order.id }
    });



  } else if (status === 'ready') {
    await supabaseAdmin.from('notifications').insert({
      user_id: order.user_id,
      type: 'order_update',
      title: 'Order Ready! 🍽️',
      message: `Your order #${order.order_number} is ready for pickup/delivery`,
      data: { order_id: order.id }
    });
  } else if (status === 'rejected') {
    // 🚀 TRIGGER SHADOWFAX CANCELLATION
    // Use Client Order ID (order_number) as 'order_id' for cancellation
    try {
      const { cancelShadowfaxOrder } = await import('../utils/shadowfax.js');
      // send order_number e.g. "GZ2026..." which was sent as 'order_id' during creation
      const cancelResp = await cancelShadowfaxOrder(order.order_number, "Rejected by Vendor");
      if (cancelResp.success) {
        console.log("✅ Shadowfax Order Cancelled due to Vendor Rejection");
        // Update local delivery status to cancelled so UI updates
        await supabaseAdmin
          .from('deliveries')
          .update({ status: 'cancelled' })
          .eq('order_id', orderId);
        // ALSO update the orders table to keep data in sync
        await supabaseAdmin
          .from('orders')
          .update({ status: 'cancelled' })
          .eq('id', orderId);
      }
    } catch (err) {
      console.error("❌ Failed to cancel Shadowfax order:", err);
    }

    // 💰 REFUND LOGIC (Placeholder)
    // Currently, refunds are handled MANUALLY via the Paytm Dashboard.
    // Future: specific logic to auto-call Paytm Refund API can be added here.
    if (order.payment_status === 'paid') {
      console.log(`ℹ️ Order ${order.order_number} Rejected. Please refund manually on Paytm Dashboard.`);
    }

    await supabaseAdmin.from('notifications').insert({
      user_id: order.user_id,
      type: 'refund_initiated',
      title: 'Order Rejected & Refund Initiated',
      message: `We're sorry, but vendor rejected your order #${order.order_number}. A refund has been initiated to your source payment method.`,
      data: { order_id: order.id }
    });
  }

  successResponse(res, { order });
}));

// ============================================
// DISPATCH HABIT ORDER (DAILY RITUAL)
// POST /api/vendor-auth/:id/orders/:orderId/dispatch-habit
// ============================================
router.post('/:id/orders/:orderId/dispatch-habit', asyncHandler(async (req, res) => {
  const { id, orderId } = req.params;

  // 1. Fetch Order and Verify Mission Status
  const { data: order, error: orderError } = await supabaseAdmin
    .from('orders')
    .select('*, items:order_items(*), vendor:vendors(*)')
    .eq('id', orderId)
    .eq('vendor_id', id)
    .single();

  if (orderError || !order) throw new ApiError(404, 'Order not found');
  if (!order.is_habit_pack) throw new ApiError(400, 'Only habit packs can be dispatched iteratively.');

  // Check progress (defaulting if columns don't exist yet, but logic relies on them)
  const currentDay = order.current_fulfillment_day || 0;
  const totalDays = order.total_fulfillment_days || 5;

  if (currentDay >= totalDays) {
    throw new ApiError(400, `This mission is already $100% complete (${currentDay}/${totalDays})`);
  }

  const nextDay = currentDay + 1;
  console.log(`🚀 [Dispatch Habit] Triggering Day ${nextDay}/${totalDays} for Order ${order.order_number}`);

  // 2. Trigger Programmatic On-Demand Delivery (Shadowfax)
  let sfResponse = null;
  const { createShadowfaxOrder } = await import('../utils/shadowfax.js');

  // Generate Unique Day Segment ID (e.g. GZ...-D1)
  const segmentOrder = {
    ...order,
    order_number: `${order.order_number}-D${nextDay}`
  };

  // Generate Fresh OTPs for today's pickup
  const pickupOtp = Math.floor(1000 + Math.random() * 9000).toString();
  const deliveryOtp = Math.floor(1000 + Math.random() * 9000).toString();

  sfResponse = await createShadowfaxOrder(segmentOrder, order.vendor, { pickup_otp: pickupOtp, delivery_otp: deliveryOtp });

  if (!sfResponse || !sfResponse.success) {
    console.error(`❌ [Shadowfax Error] Failed to trigger iterative dispatch: ${sfResponse?.error}`);
    throw new ApiError(500, `Shadowfax rejection: ${sfResponse?.error || 'Unknown'}`);
  }

  const shadowfaxId = sfResponse.data.sfx_order_id || sfResponse.data.id;

  // 3. Update Fulfillment State and Create Delivery Record
  // Increment progress
  await supabaseAdmin
    .from('orders')
    .update({ 
      current_fulfillment_day: nextDay,
      status: nextDay === totalDays ? 'completed' : 'preparing' // Status management for multi-day
    })
    .eq('id', orderId);

  // Store new delivery segment
  await supabaseAdmin.from('deliveries').insert({
    order_id: order.id,
    partner_id: 'shadowfax',
    external_order_id: shadowfaxId,
    status: 'searching_rider',
    pickup_otp: pickupOtp,
    delivery_otp: deliveryOtp,
    history: [{
      status: 'searching_rider',
      timestamp: new Date().toISOString(),
      note: `Iterative Dispatch Triggered: Day ${nextDay}/${totalDays}`
    }]
  });

  // 4. Notify User of Mission Progress
  await supabaseAdmin.from('notifications').insert({
    user_id: order.user_id,
    type: 'order_update',
    title: `Day ${nextDay} In-Flight! 🛵`,
    message: `Your Day ${nextDay} health ritual is out for delivery (#${order.order_number}).`,
    data: { order_id: order.id, day: nextDay }
  });

  successResponse(res, { 
    success: true, 
    current_day: nextDay,
    total_days: totalDays,
    message: `Day ${nextDay} mission successfully dispatched via Shadowfax!` 
  });
}));

// ============================================
// GET VENDOR GST REPORT
// GET /api/vendor-auth/:vendorId/gst-report
// ============================================
router.get('/:vendorId/gst-report', asyncHandler(async (req, res) => {
  const { vendorId } = req.params;
  const { from, to, format = 'json' } = req.query;

  // Default date range: current month
  const today = new Date();
  const defaultFrom = from || new Date(today.getFullYear(), today.getMonth(), 1).toISOString();
  const defaultTo = to || new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59).toISOString();

  // Fetch vendor details
  const { data: vendor, error: vendorError } = await supabaseAdmin
    .from('vendors')
    .select('id, name, address')
    .eq('id', vendorId)
    .single();

  console.log('GST Report - Vendor ID:', vendorId);
  console.log('GST Report - Vendor lookup result:', { vendor, vendorError });

  if (vendorError || !vendor) {
    throw new ApiError(404, `Vendor not found: ${vendorId}, Error: ${vendorError?.message || 'No error message'}`);
  }

  // Add placeholder GSTIN (vendors table doesn't have this field)
  vendor.gstin = 'N/A';

  // Fetch orders for the period
  const { data: orders, error: ordersError } = await supabaseAdmin
    .from('orders')
    .select(`
      id,
      order_number,
      created_at,
      subtotal,
      gst_items,
      packaging_fee,
      delivery_fee,
      platform_fee,
      gst_fees,
      delivery_address,
      status
    `)
    .eq('vendor_id', vendorId)
    .gte('created_at', defaultFrom)
    .lte('created_at', defaultTo)
    .in('status', ['delivered', 'completed'])
    .order('created_at', { ascending: false });

  console.log('Fetching orders for vendor:', vendorId, 'from', defaultFrom, 'to', defaultTo);

  if (ordersError) {
    console.error('Orders Error:', ordersError);
    throw new ApiError(500, `Failed to fetch orders: ${ordersError.message || 'Unknown error'}`);
  }

  console.log('Found orders:', orders?.length || 0);

  // Process orders and calculate GST
  const processedOrders = [];
  const stateWiseBreakup = {};
  let totalSalesValue = 0;
  let totalGST5Percent = 0;
  let totalPlatformFees = 0;
  let totalGST18Percent = 0;
  let totalGross = 0;
  let totalCommission = 0;
  let totalTDSTCS = 0;
  let totalNetSettlement = 0;

  try {
    orders.forEach(order => {
      const itemTotal = Number(order.subtotal || 0) + Number(order.packaging_fee || 0);
      const gstOnItems = Number(order.gst_items || 0) || (itemTotal * 5 / 105);
      const platformFee = Number(order.platform_fee || 0);
      const gstOnFees = Number(order.gst_fees || 0) || (platformFee * 18 / 118);
      const deliveryFee = Number(order.delivery_fee || 0);

      // Calculate total since it's not in the database
      const grossAmount = itemTotal + gstOnItems + platformFee + gstOnFees + deliveryFee;

      // Calculate commission (example: 15% of item total)
      const commission = itemTotal * 0.15;

      // Calculate TDS/TCS (example: 0.3% of gross)
      const tdsTcs = grossAmount * 0.003;

      // Net settlement
      const netSettlement = grossAmount - commission - tdsTcs;

      // Extract customer state from delivery address
      let customerState = 'Unknown';
      if (order.delivery_address) {
        try {
          const address = typeof order.delivery_address === 'string'
            ? JSON.parse(order.delivery_address)
            : order.delivery_address;
          customerState = address.state || address.city || 'Unknown';
        } catch (e) {
          customerState = 'Unknown';
        }
      }

      // Add to state-wise breakup
      if (!stateWiseBreakup[customerState]) {
        stateWiseBreakup[customerState] = { orders: 0, value: 0, gst: 0 };
      }
      stateWiseBreakup[customerState].orders += 1;
      stateWiseBreakup[customerState].value += itemTotal;
      stateWiseBreakup[customerState].gst += gstOnItems;

      // Add to totals
      totalSalesValue += itemTotal;
      totalGST5Percent += gstOnItems;
      totalPlatformFees += platformFee;
      totalGST18Percent += gstOnFees;
      totalGross += grossAmount;
      totalCommission += commission;
      totalTDSTCS += tdsTcs;
      totalNetSettlement += netSettlement;

      processedOrders.push({
        order_number: order.order_number,
        date: order.created_at,
        customer_state: customerState,
        item_total: itemTotal,
        gst_on_items: gstOnItems,
        delivery_charges: Number(order.delivery_fee || 0),
        platform_fee: platformFee,
        gst_on_fees: gstOnFees,
        gross_amount: grossAmount,
        commission,
        tds_tcs: tdsTcs,
        net_settlement: netSettlement
      });
    });
  } catch (error) {
    console.error('Error processing orders:', error);
    throw new ApiError(500, `Error processing orders: ${error.message}`);
  }

  // Prepare report data
  const reportData = {
    vendor: {
      id: vendor.id,
      name: vendor.name,
      gstin: vendor.gstin,
      address: vendor.address
    },
    period: {
      from: defaultFrom,
      to: defaultTo,
      month: new Date(defaultFrom).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
    },
    orders: processedOrders,
    summary: {
      total_orders: orders.length,
      total_sales_value: totalSalesValue,
      total_gst_collected_5_percent: totalGST5Percent,
      total_platform_fees: totalPlatformFees,
      total_gst_on_fees_18_percent: totalGST18Percent,
      gross_revenue: totalGross,
      total_commission: totalCommission,
      total_tds_tcs: totalTDSTCS,
      net_settlement_amount: totalNetSettlement,
      state_wise_breakup: stateWiseBreakup
    },
    gst_filing_summary: {
      table_8_gstr1: {
        description: 'Supplies through ECO (Gutzo)',
        taxable_value: totalSalesValue,
        tax_paid_by_eco: totalGST5Percent
      },
      table_3_1_1_ii_gstr3b: {
        description: 'Supplies through ECO',
        taxable_value: totalSalesValue,
        note: 'No tax liability - GST paid by ECO'
      }
    }
  };

  // Handle different formats
  if (format === 'pdf') {
    console.log('Generating PDF report...');
    const { generateGSTReportPDF } = await import('../utils/gstReportGenerator.js');
    const pdfBuffer = await generateGSTReportPDF(reportData);

    console.log('PDF generated, buffer size:', pdfBuffer.length);

    const filename = `GST_Report_${vendor.name.replace(/[^a-zA-Z0-9]/g, '_')}_${new Date().toISOString().split('T')[0]}.pdf`;

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Length', pdfBuffer.length);
    res.setHeader('Cache-Control', 'no-cache');

    return res.end(Buffer.from(pdfBuffer));
  }

  if (format === 'excel') {
    const { generateGSTReportExcel } = await import('../utils/gstReportGenerator.js');
    const excelBuffer = await generateGSTReportExcel(reportData);

    const filename = `GST_Report_${vendor.name.replace(/[^a-zA-Z0-9]/g, '_')}_${new Date().toISOString().split('T')[0]}.xlsx`;

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.send(excelBuffer);
  }

  if (format === 'html') {
    const { generateGSTReportHTML } = await import('../utils/gstReportGenerator.js');
    const htmlContent = generateGSTReportHTML(reportData);

    res.setHeader('Content-Type', 'text/html');
    return res.send(htmlContent);
  }

  // Return JSON by default
  successResponse(res, reportData);
}));


export default router;

import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, paginatedResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';
import { validate, schemas } from '../middleware/validate.js';
import { v4 as uuidv4 } from 'uuid';
import { generateCustomerInvoiceHtml, generateVendorKOTHtml, generateInvoicePDF } from '../utils/invoiceGenerator.js';

const router = express.Router();

// ============================================
// HELPER: Generate Order Number
// ============================================
const generateOrderNumber = () => {
  const date = new Date();
  const prefix = 'GZ';
  const dateStr = `${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}${String(date.getDate()).padStart(2, '0')}`;
  const timeStr = `${String(date.getHours()).padStart(2, '0')}${String(date.getMinutes()).padStart(2, '0')}`;
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `${prefix}${dateStr}${timeStr}${random}`;
};

// ============================================
// HELPER: Calculate Order Total
// ============================================
const calculateOrderTotal = async (items, vendorId, couponCode = null, feeOverrides = {}) => {
  let subtotal = 0;
  const itemDetails = [];

  for (const item of items) {
    const { data: product } = await supabaseAdmin
      .from('products')
      .select('id, name, price, discount_price')
      .eq('id', item.product_id)
      .single();

    if (!product) continue;

    const price = product.discount_price || product.price;
    const itemTotal = price * item.quantity;
    subtotal += itemTotal;

    itemDetails.push({
      product_id: item.product_id,
      product_name: product.name,
      quantity: item.quantity,
      unit_price: price,
      total_price: itemTotal,
      variant_id: item.variant_id,
      addons: item.addons,
      special_instructions: item.special_instructions
    });
  }

  // Get vendor details for defaults
  const { data: vendor } = await supabaseAdmin
    .from('vendors')
    .select('delivery_fee, minimum_order')
    .eq('id', vendorId)
    .single();

  // Use overrides if provided, otherwise defaults
  // Note: feeOverrides might contain explicit 0, so check !== undefined
  const deliveryFee = feeOverrides.delivery_fee !== undefined
    ? Number(feeOverrides.delivery_fee)
    : (vendor?.delivery_fee || 1);

  const packagingFee = feeOverrides.packaging_fee !== undefined
    ? Number(feeOverrides.packaging_fee)
    : 0;

  const platformFee = feeOverrides.platform_fee !== undefined
    ? Number(feeOverrides.platform_fee)
    : 1;

  let discount = feeOverrides.discount_amount !== undefined
    ? Number(feeOverrides.discount_amount)
    : 0;

  // Apply coupon only if discount override NOT provided (or if we want to re-validate)
  // For safety, if frontend provides discount, we use it, but ideal validaton should check coupon validity again.
  // For now, if couponCode is active and NO override, calculate it.
  if (couponCode && feeOverrides.discount_amount === undefined) {
    const { data: coupon } = await supabaseAdmin
      .from('coupons')
      .select('*')
      .eq('code', couponCode.toUpperCase())
      .eq('is_active', true)
      .single();

    if (coupon) {
      if (subtotal >= coupon.minimum_order) {
        if (coupon.discount_type === 'percentage') {
          discount = (subtotal * coupon.discount_value) / 100;
          if (coupon.maximum_discount) {
            discount = Math.min(discount, coupon.maximum_discount);
          }
        } else {
          discount = coupon.discount_value;
        }
      }
    }
  }

  // Calculate taxes
  // If override provided, use it. Otherwise calculate default logic.
  let totalTax;
  let gstItems = 0;
  let gstFees = 0;

  if (feeOverrides.taxes !== undefined) {
    totalTax = Number(feeOverrides.taxes);
    // Rough estimation for back-filling if needed, or leave 0
    gstItems = totalTax * 0.7; // Approx
    gstFees = totalTax * 0.3;
  } else {
    // Restaurant Level GST (5%) on Subtotal + Packaging
    const restaurantBill = subtotal + packagingFee;
    gstItems = restaurantBill - (restaurantBill / 1.05);

    // Platform Level GST (18%) on Delivery + Platform Fee
    const platformBill = deliveryFee + platformFee;
    gstFees = platformBill - (platformBill / 1.18);

    totalTax = Math.round(gstItems + gstFees);
  }

  // Total
  const total = subtotal + deliveryFee + packagingFee + platformFee - discount;

  return {
    subtotal,
    deliveryFee,
    packagingFee,
    platformFee,
    taxes: totalTax, // Use calculated or overridden tax
    discount,
    total,
    itemDetails,
    gstDetails: {
      itemTax: Number(gstItems.toFixed(2)),
      feeTax: Number(gstFees.toFixed(2))
    }
  };
};

// All order routes require authentication
router.use(authenticate);

// ============================================
// CREATE ORDER
// POST /api/orders
// ============================================
router.post('/', validate(schemas.createOrder), asyncHandler(async (req, res) => {
  try {
    const {
      vendor_id,
      items,
      delivery_address,
      delivery_phone,
      coupon_code,
      tip_amount = 0,
      special_instructions,
      payment_method,
      order_source = 'app',
      // Destructure overrides
      delivery_fee,
      platform_fee,
      packaging_fee,
      taxes,
      discount_amount,
      mock_shadowfax // New field
    } = req.body;

    // console.log('📦 Creating Order:', { vendor_id, itemCount: items.length });

    // Verify vendor is open
    const { data: vendor, error: vendorError } = await supabaseAdmin
      .from('vendors')
      .select('*')
      .eq('id', vendor_id)
      .eq('is_active', true)
      .single();

    if (vendorError) {
      console.error('❌ Vendor Error:', vendorError);
      throw new ApiError(404, 'Vendor not found');
    }
    if (!vendor) {
      console.error('❌ Vendor not found');
      throw new ApiError(404, 'Vendor not found');
    }
    if (!vendor.is_open) throw new ApiError(400, 'Vendor is currently closed');

    // Calculate totals
    // console.log('🧮 Calculating totals...');
    const feeOverrides = { delivery_fee, platform_fee, packaging_fee, taxes, discount_amount };
    const calculation = await calculateOrderTotal(items, vendor_id, coupon_code, feeOverrides);

    // Check minimum order
    // Check minimum order
    /* Disabled as per user request
    if (vendor.minimum_order && calculation.subtotal < vendor.minimum_order) {
      throw new ApiError(400, `Minimum order amount is ₹${vendor.minimum_order}`);
    }
    */

    const orderNumber = generateOrderNumber();
    const deliveryOtp = Math.floor(1000 + Math.random() * 9000).toString();

    // console.log('📝 Inserting Order:', orderNumber);

    // Create order
    const { data: order, error: orderError } = await supabaseAdmin
      .from('orders')
      .insert({
        order_number: orderNumber,
        user_id: req.user.id,
        // user_phone removed as it is not in schema
        vendor_id,
        // vendor_name removed as it is not in schema
        delivery_address: JSON.stringify(delivery_address),
        delivery_phone,
        subtotal: calculation.subtotal,
        delivery_fee: calculation.deliveryFee,
        packaging_fee: calculation.packagingFee,
        platform_fee: calculation.platformFee,
        taxes: calculation.taxes,
        discount_amount: calculation.discount,
        tip_amount,
        total_amount: calculation.total + tip_amount,
        status: 'created', // Changed from 'placed' to distinguish initial state
        payment_method,
        gst_items: calculation.gstDetails.itemTax,
        gst_fees: calculation.gstDetails.feeTax,
        payment_status: payment_method === 'cod' ? 'pending' : 'pending',
        special_instructions,
        order_source,
        coupon_code,
        mock_shadowfax // Added for Dev/Mock handling
      })
      .select()
      .single();

    if (orderError) {
      console.error('❌ DB Error inserting order:', orderError);
      throw new ApiError(500, `Failed to create order: ${orderError.message}`);
    }

    // Create initial delivery record (moved from orders table)
    const { error: deliveryError } = await supabaseAdmin
      .from('deliveries')
      .insert({
        order_id: order.id,
        delivery_otp: deliveryOtp,
        partner_id: 'shadowfax', // Default partner
        status: 'pending' // Initial status
      });

    if (deliveryError) {
      console.error('❌ DB Error inserting initial delivery:', deliveryError);
      // Optional: Should we rollback? For now, logging error.
    }

    // Create order items
    const orderItems = calculation.itemDetails.map(item => ({
      order_id: order.id,
      product_id: item.product_id,
      vendor_id: vendor_id, // Added matching schema
      product_name: item.product_name,
      quantity: item.quantity,
      unit_price: item.unit_price,
      total_price: item.total_price,
      // variant_id removed
      customizations: item.addons ? JSON.stringify(item.addons) : null, // Mapped addons to customizations
      special_instructions: item.special_instructions
    }));

    const { error: itemsError } = await supabaseAdmin
      .from('order_items')
      .insert(orderItems);

    if (itemsError) {
      console.error('❌ DB Error inserting order items:', itemsError);
      // Rollback order
      await supabaseAdmin.from('orders').delete().eq('id', order.id);
      throw new ApiError(500, `Failed to create order items: ${itemsError.message}`);
    }

    // Update coupon usage if used
    if (coupon_code && calculation.discount > 0) {
      const { data: coupon } = await supabaseAdmin
        .from('coupons')
        .select('id, used_count')
        .eq('code', coupon_code.toUpperCase())
        .single();

      if (coupon) {
        await supabaseAdmin
          .from('coupon_usage')
          .insert({
            coupon_id: coupon.id,
            user_id: req.user.id,
            order_id: order.id,
            discount_applied: calculation.discount
          });

        await supabaseAdmin
          .from('coupons')
          .update({ used_count: coupon.used_count + 1 })
          .eq('id', coupon.id);
      }
    }

    // Clear cart for this vendor
    await supabaseAdmin
      .from('cart')
      .delete()
      .eq('user_phone', req.user.phone)
      .eq('vendor_id', vendor_id);

    // Update user stats
    await supabaseAdmin
      .from('users')
      .update({
        total_orders: req.user.total_orders + 1,
        total_spent: (req.user.total_spent || 0) + calculation.total + tip_amount,
        last_order_at: new Date().toISOString()
      })
      .eq('id', req.user.id);

    // Create notification
    await supabaseAdmin
      .from('notifications')
      .insert({
        user_id: req.user.id,
        type: 'order_placed',
        title: 'Order Placed!',
        message: `Your order #${orderNumber} has been placed successfully.`,
        data: { order_id: order.id, order_number: orderNumber }
      });

    successResponse(res, {
      order,
      items: calculation.itemDetails,
      calculation: {
        subtotal: calculation.subtotal,
        deliveryFee: calculation.deliveryFee,
        discount: calculation.discount,
        tip: tip_amount,
        total: calculation.total + tip_amount
      }
    }, 'Order placed successfully', 201);
  } catch (error) {
    console.error('❌ Create Order Unhandled Error:', error);
    throw error; // Re-throw to be caught by asyncHandler
  }
}));

// ============================================
// GET USER ORDERS
// GET /api/orders
// ============================================
router.get('/', asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, status } = req.query;

  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let query = supabaseAdmin
    .from('orders')
    .select(`
      *,
      items:order_items(*),
      vendor:vendors(id, name, image)
    `, { count: 'exact' })
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false })
    .range(from, to);

  if (status) query = query.eq('status', status);

  const { data: orders, error, count } = await query;

  // console.log(`[DEBUG] GET /orders for User ${req.user.id} (${req.user.phone}) - Found: ${count}`);
  if (orders && orders.length > 0) {
    // console.log(`[DEBUG] First order ID: ${orders[0].id} Status: ${orders[0].status}`);
  } else {
    // console.log(`[DEBUG] No orders found for query details.`);
  }

  if (error) throw new ApiError(500, 'Failed to fetch orders');

  paginatedResponse(res, orders, page, limit, count);
}));

// ============================================
// GET ORDER BY ID
// GET /api/orders/:id
// ============================================
// ============================================
// GET ORDER BY ID (OR ORDER NUMBER)
// GET /api/orders/:id
// ============================================
router.get('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;
  console.log(`[DEBUG] GET Order: ${id} | User: ${req.user?.id} | Phone: ${req.user?.phone}`);

  let query = supabaseAdmin
    .from('orders')
    .select(`
      *,
      items:order_items(*),
      vendor:vendors(id, name, image, phone, whatsapp_number, address, latitude, longitude),
      delivery:deliveries(*)
    `);

  // Check if ID is likely a UUID (basic regex or length check)
  // UUID is 36 chars. Order Number (GZ...) is usually different.
  const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

  if (isUUID) {
    query = query.eq('id', id);
  } else {
    query = query.eq('order_number', id);
  }

  const { data: order, error } = await query.eq('user_id', req.user.id).single();

  if (error || !order) throw new ApiError(404, 'Order not found');

  // Verify delivery attachment and Normalize (Supabase 1:1 returns Object, Frontend expects Array)
  if (order.delivery) {
    if (!Array.isArray(order.delivery)) {
      order.delivery = [order.delivery];
    }
    // Logs removed to reduce noise per user request
  }

  successResponse(res, order);
}));

// ============================================
// GET ORDER BY ORDER NUMBER
// GET /api/orders/number/:orderNumber
// ============================================
router.get('/number/:orderNumber', asyncHandler(async (req, res) => {
  const { orderNumber } = req.params;

  const { data: order, error } = await supabaseAdmin
    .from('orders')
    .select(`
      *,
      items:order_items(*),
      delivery:deliveries(*)
    `)
    .eq('order_number', orderNumber)
    .eq('user_id', req.user.id)
    .single();

  if (error || !order) throw new ApiError(404, 'Order not found');

  successResponse(res, order);
}));

// ============================================
// CANCEL ORDER
// POST /api/orders/:id/cancel
// ============================================
router.post('/:id/cancel', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  const { data: order, error } = await supabaseAdmin
    .from('orders')
    .select('*')
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !order) throw new ApiError(404, 'Order not found');

  // Can only cancel if order is in initial stages
  const cancelableStatuses = ['created', 'placed', 'confirmed'];
  if (!cancelableStatuses.includes(order.status)) {
    throw new ApiError(400, `Cannot cancel order in '${order.status}' status`);
  }

  const { data: updated, error: updateError } = await supabaseAdmin
    .from('orders')
    .update({
      status: 'cancelled',
      cancelled_by: 'user',
      cancellation_reason: reason,
      cancelled_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single();

  if (updateError) throw new ApiError(500, 'Failed to cancel order');

  // Create notification
  await supabaseAdmin
    .from('notifications')
    .insert({
      user_id: req.user.id,
      type: 'order_cancelled',
      title: 'Order Cancelled',
      message: `Your order #${order.order_number} has been cancelled.`,
      data: { order_id: id, order_number: order.order_number }
    });

  successResponse(res, updated, 'Order cancelled successfully');
}));

// ============================================
// REORDER (Create order from previous order)
// POST /api/orders/:id/reorder
// ============================================
router.post('/:id/reorder', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: previousOrder, error } = await supabaseAdmin
    .from('orders')
    .select(`
      *,
      items:order_items(*),
      delivery:deliveries(*)
    `)
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !previousOrder) throw new ApiError(404, 'Order not found');

  // Convert order items to cart format
  const items = previousOrder.items.map(item => ({
    product_id: item.product_id,
    quantity: item.quantity,
    variant_id: item.variant_id,
    addons: item.addons ? JSON.parse(item.addons) : null,
    special_instructions: item.special_instructions
  }));

  successResponse(res, {
    vendor_id: previousOrder.vendor_id,
    items,
    delivery_address: previousOrder.delivery_address,
    message: 'Items ready for checkout. Complete the order by calling POST /orders'
  });
}));

// ============================================
// RATE ORDER
// POST /api/orders/:id/rate
// ============================================
router.post('/:id/rate', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { rating, feedback } = req.body;

  if (!rating || rating < 1 || rating > 5) {
    throw new ApiError(400, 'Rating must be between 1 and 5');
  }

  const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

  let query = supabaseAdmin
    .from('orders')
    .select('*, items:order_items(id, product_id, vendor_id)');

  if (isUUID) {
    query = query.eq('id', id);
  } else {
    query = query.eq('order_number', id);
  }

  const { data: order, error } = await query
    .eq('user_id', req.user.id)
    .single();

  if (error || !order) throw new ApiError(404, 'Order not found');

  if (order.status !== 'delivered' && order.status !== 'completed' && order.status !== 'DELIVERED') {
    throw new ApiError(400, 'Can only rate delivered orders');
  }

  // 1. Update order rating
  const { data: updated, error: updateError } = await supabaseAdmin
    .from('orders')
    .update({
      rating,
      feedback,
      feedback_at: new Date().toISOString()
    })
    .eq('id', order.id)
    .select()
    .single();

  if (updateError) throw new ApiError(500, 'Failed to submit rating');

  // 2. Propagate rating to individual order items
  await supabaseAdmin
    .from('order_items')
    .update({ rating })
    .eq('order_id', order.id);

  // 3. Update Product Ratings
  const productIds = [...new Set(order.items?.map(item => item.product_id) || [])];
  
  for (const productId of productIds) {
    // Calculate new average for this product
    const { data: itemRatings } = await supabaseAdmin
      .from('order_items')
      .select('rating')
      .eq('product_id', productId)
      .not('rating', 'is', null);

    if (itemRatings && itemRatings.length > 0) {
      const avg = itemRatings.reduce((sum, r) => sum + r.rating, 0) / itemRatings.length;
      await supabaseAdmin
        .from('products')
        .update({ 
          rating: Number(avg.toFixed(1)),
          review_count: itemRatings.length 
        })
        .eq('id', productId);
    }
  }

  // 4. Update Vendor Rating (Average of its products that have real ratings)
  const vendorId = order.vendor_id;
  const { data: productRatings } = await supabaseAdmin
    .from('products')
    .select('rating')
    .eq('vendor_id', vendorId)
    .gt('rating', 0);

  if (productRatings && productRatings.length > 0) {
    const avg = productRatings.reduce((sum, p) => sum + p.rating, 0) / productRatings.length;
    await supabaseAdmin
      .from('vendors')
      .update({ 
        rating: Number(avg.toFixed(1))
      })
      .eq('id', vendorId);
  }

  successResponse(res, updated, 'Thank you for your feedback!');
}));

// ============================================
// TRACK ORDER (Get live status)
// GET /api/orders/:id/track
// ============================================
router.get('/:id/track', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: order, error } = await supabaseAdmin
    .from('orders')
    .select(`
      id, order_number, status, 
      estimated_delivery_time, actual_delivery_time,
      rider_id, 
      vendor:vendors(id, name, latitude, longitude),
      delivery:deliveries(*)
    `)
    .eq('id', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !order) throw new ApiError(404, 'Order not found');

  /* 
     Update Status Flow based on Vendor/Delivery Status 
  */
  const statusFlow = [
    { status: 'searching_rider', label: 'Finding Delivery Partner', icon: '🛵' },
    { status: 'placed', label: 'Waiting for Confirmation', icon: '📝' },
    { status: 'confirmed', label: 'Confirmed', icon: '✅' },
    { status: 'preparing', label: 'Preparing', icon: '👨‍🍳' },
    { status: 'ready', label: 'Ready for Pickup', icon: '📦' },
    { status: 'out_for_delivery', label: 'Out for Delivery', icon: '🚴' },
    { status: 'delivered', label: 'Delivered', icon: '✨' }
  ];

  const currentIndex = statusFlow.findIndex(s => s.status === order.status);

  // 🚚 Fetch 3rd Party Tracking if available
  // Refactored to check 'deliveries' table first
  let deliveryTracking = null;

  // order.delivery is an array, take the latest one (assuming sorting or trigger handles order)
  // Ideally sort by created_at desc in query but Supabase select needs explicit ordering or we sort here
  const activeDelivery = order.delivery && order.delivery.length > 0
    ? order.delivery.sort((a, b) => new Date(b.created_at) - new Date(a.created_at))[0]
    : null;

  if (activeDelivery) {
    deliveryTracking = {
      provider: activeDelivery.partner_id || 'shadowfax',
      rider_name: activeDelivery.rider_name,
      rider_phone: activeDelivery.rider_phone,
      rider_location: activeDelivery.rider_coordinates,
      tracking_url: activeDelivery.tracking_url,
      pickup_otp: activeDelivery.pickup_otp,
      delivery_otp: activeDelivery.delivery_otp,
      status: activeDelivery.status
    };
    // Shadowfax On-Demand Check (if we still need to hit their API live)
    // Only if status is incomplete and we don't trust our DB? 
    // For now, rely on Webhook updates stored in DB.
  }

  successResponse(res, {
    order_number: order.order_number,
    current_status: order.status,
    status_flow: statusFlow.map((s, i) => ({
      ...s,
      completed: i <= currentIndex,
      current: i === currentIndex
    })),
    estimated_delivery: order.estimated_delivery_time,
    rider: deliveryTracking ? {
      name: deliveryTracking.rider_name,
      phone: deliveryTracking.rider_phone,
      location: deliveryTracking.rider_location
    } : null,
    delivery_tracking: deliveryTracking,
    vendor_location: order.vendor ? {
      lat: order.vendor.latitude,
      lng: order.vendor.longitude
    } : null
  });
}));

// ============================================
// GET INVOICE (HTML or PDF)
// GET /api/orders/:id/invoice
// ============================================
router.get('/:id/invoice', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { format } = req.query;

  const { data: order, error } = await supabaseAdmin
    .from('orders')
    .select('*, items:order_items(*), vendor:vendors(*)')
    .eq('id', id)
    .single();

  if (error || !order) throw new ApiError(404, 'Order not found');

  // Fetch user separately to avoid missing foreign key relation errors
  const { data: user } = await supabaseAdmin
    .from('users')
    .select('name, phone')
    .eq('id', order.user_id)
    .single();

  if (user) {
    order.user = user;
  }

  // Generate HTML or PDF
  if (format === 'pdf') {
    const pdfBuffer = await generateInvoicePDF(order);
    const filename = `Invoice_${order.order_number}.pdf`;

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Length', pdfBuffer.length);
    res.setHeader('Cache-Control', 'no-cache');

    return res.end(Buffer.from(pdfBuffer));
  } else {
    const html = generateCustomerInvoiceHtml(order);
    res.set('Content-Type', 'text/html');
    res.send(html);
  }
}));

// ============================================
// GET KITCHEN TICKET (KOT) (HTML)
// GET /api/orders/:id/kot
// ============================================
router.get('/:id/kot', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: order, error } = await supabaseAdmin
    .from('orders')
    .select('*, items:order_items(*), vendor:vendors(*)')
    .eq('id', id)
    .single();

  if (error || !order) throw new ApiError(404, 'Order not found');

  // Fetch user separately to avoid missing foreign key relation errors
  const { data: user } = await supabaseAdmin
    .from('users')
    .select('name, phone')
    .eq('id', order.user_id)
    .single();

  if (user) {
    order.user = user;
  }

  const html = generateVendorKOTHtml(order);

  res.set('Content-Type', 'text/html');
  res.send(html);
}));


// ============================================
// REPRICE ORDER (for payment retry with fresh prices)
// PATCH /api/orders/:id/reprice
// ============================================
router.patch('/:id/reprice', asyncHandler(async (req, res) => {
  const { id } = req.params;

  // 1. Fetch the existing failed order (must be 'created' = unpaid)
  const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
  const { data: order, error } = await supabaseAdmin
    .from('orders')
    .select('*, items:order_items(*)')
    .eq(isUUID ? 'id' : 'order_number', id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !order) throw new ApiError(404, 'Order not found');

  // Only allow reprice on unpaid orders
  if (order.status !== 'created') {
    throw new ApiError(400, `Cannot reprice an order with status '${order.status}'. Only unpaid orders can be repriced.`);
  }

  // 2. Rebuild items array for the calculator (use stored quantities, fresh prices)
  const items = (order.items || []).map(item => ({
    product_id: item.product_id,
    quantity: item.quantity,
    variant_id: item.variant_id,
    addons: item.customizations ? JSON.parse(item.customizations) : null,
    special_instructions: item.special_instructions,
  }));

  // 3. Recalculate with CURRENT product prices AND current fees
  //    delivery_fee and platform_fee are intentionally NOT overridden
  //    so calculateOrderTotal fetches the vendor's current delivery_fee
  //    and uses the default platform_fee — reflecting today's rates.
  const feeOverrides = {
    packaging_fee: order.packaging_fee,     // Keep packaging as-is
    taxes: undefined,                        // Recalculate taxes from scratch
    discount_amount: order.discount_amount, // Keep any coupon discount
  };

  const calculation = await calculateOrderTotal(items, order.vendor_id, order.coupon_code, feeOverrides);
  const newTotal = calculation.total + (order.tip_amount || 0);

  // 4. Update order with fresh prices
  const { data: updated, error: updateError } = await supabaseAdmin
    .from('orders')
    .update({
      subtotal: calculation.subtotal,
      taxes: calculation.taxes,
      total_amount: newTotal,
      gst_items: calculation.gstDetails.itemTax,
      gst_fees: calculation.gstDetails.feeTax,
      updated_at: new Date().toISOString(),
    })
    .eq('id', order.id)
    .select()
    .single();

  if (updateError) throw new ApiError(500, `Failed to reprice order: ${updateError.message}`);

  // 5. Also update individual order_items with new unit prices
  for (const item of calculation.itemDetails) {
    await supabaseAdmin
      .from('order_items')
      .update({
        unit_price: item.unit_price,
        total_price: item.total_price,
      })
      .eq('order_id', order.id)
      .eq('product_id', item.product_id);
  }

  successResponse(res, {
    order_number: updated.order_number,
    new_total: newTotal,
    breakdown: {
      subtotal: calculation.subtotal,
      delivery_fee: calculation.deliveryFee,
      platform_fee: calculation.platformFee,
      taxes: calculation.taxes,
      discount: calculation.discount,
      tip: order.tip_amount || 0,
      total: newTotal,
    }
  }, 'Order repriced with current prices');
}));

export default router;


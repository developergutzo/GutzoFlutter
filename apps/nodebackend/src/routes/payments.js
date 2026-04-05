import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';
import PaytmChecksum from '../utils/paytmChecksum.js';

const router = express.Router();

// Paytm Environment variables
const PAYTM_MID = process.env.PAYTM_MID;
const PAYTM_MERCHANT_KEY = process.env.PAYTM_MERCHANT_KEY;
const PAYTM_WEBSITE_NAME = process.env.PAYTM_WEBSITE_NAME;
const PAYTM_CALLBACK_URL = process.env.PAYTM_CALLBACK_URL;
const PAYTM_ENV = process.env.PAYTM_ENV;

// Paytm URLs based on environment
const PAYTM_BASE_URL = PAYTM_ENV === 'production'
  ? 'https://secure.paytmpayments.com'
  : 'https://securestage.paytmpayments.com';

const PAYTM_STATUS_QUERY_URL = PAYTM_ENV === 'production'
  ? 'https://secure.paytmpayments.com/v3/order/status'
  : 'https://securestage.paytmpayments.com/v3/order/status';

/**
 * Helper to verify payment status directly with Paytm API (Secure Fallback)
 * Used when webhook checksum is missing or untrusted.
 */
async function verifyPaytmStatus(orderId) {
  const paytmParams = {
    mid: PAYTM_MID,
    orderId: orderId,
  };

  try {
    const checksum = await PaytmChecksum.generateSignature(JSON.stringify(paytmParams), PAYTM_MERCHANT_KEY);

    const payload = {
      head: { signature: checksum },
      body: paytmParams
    };

    const response = await fetch(PAYTM_STATUS_QUERY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const data = await response.json();
    console.log(`[Paytm Status Query] Response for ${orderId}:`, JSON.stringify(data));

    return {
      success: data?.body?.resultInfo?.resultStatus === 'TXN_SUCCESS',
      status: data?.body?.resultInfo?.resultStatus,
      raw: data
    };
  } catch (error) {
    console.error(`[Paytm Status Query] Error for ${orderId}:`, error.message);
    return { success: false, error: error.message };
  }
}


// ============================================
// PAYTM PAYMENT ENDPOINTS
// ============================================

// GENERATE PAYTM CHECKSUM
router.post('/generate-checksum', asyncHandler(async (req, res) => {
  const { merchantKey, ...params } = req.body;

  const key = merchantKey || PAYTM_MERCHANT_KEY;
  if (!key || Object.keys(params).length === 0) {
    throw new ApiError(400, 'merchantKey and params are required');
  }

  const checksum = await PaytmChecksum.generateSignature(params, key);

  successResponse(res, { checksum }, 'Checksum generated successfully');
}));

// VERIFY PAYTM CHECKSUM
router.post('/verify-checksum', asyncHandler(async (req, res) => {
  const { body, merchantKey, checksum } = req.body;

  const key = merchantKey || PAYTM_MERCHANT_KEY;
  if (!body || !key || !checksum) {
    throw new ApiError(400, 'body, merchantKey, and checksum are required');
  }

  const isValid = PaytmChecksum.verifySignature(body, key, checksum);

  successResponse(res, {
    valid: isValid,
    message: isValid ? 'Checksum is valid' : 'Checksum is invalid'
  });
}));

// INITIATE PAYTM TRANSACTION (For web form-based flow)
router.post('/initiate', authenticate, asyncHandler(async (req, res) => {
  const { order_id, amount } = req.body;

  if (!order_id || !amount) {
    throw new ApiError(400, 'Order ID and amount are required');
  }

  // Verify order exists
  const { data: order } = await supabaseAdmin
    .from('orders')
    .select('*')
    .eq('id', order_id)
    .eq('user_id', req.user.id)
    .single();

  if (!order) throw new ApiError(404, 'Order not found');
  if (order.payment_status === 'paid') throw new ApiError(400, 'Order already paid');

  /* Refactored to use Paytm initiateTransaction API for JS Checkout */
  const paytmParams = {
    mid: PAYTM_MID,
    orderId: order.order_number, // User friendly order number
    requestType: 'Payment',
    txnAmount: {
      value: String(amount),
      currency: 'INR'
    },
    userInfo: {
      custId: req.user.id
    },
    callbackUrl: PAYTM_CALLBACK_URL,
    industryType: 'Retail',
    channelId: 'WEB',
    websiteName: PAYTM_WEBSITE_NAME,
  };

  try {
    // const checksum = await PaytmChecksum.generateSignature(JSON.stringify(paytmParams), PAYTM_MERCHANT_KEY);
    // console.log('Generated Paytm Checksum:', checksum);

    console.log('[Paytm Initiate] Params:', JSON.stringify(paytmParams, null, 2));

    const checksum = await PaytmChecksum.generateSignature(JSON.stringify(paytmParams), PAYTM_MERCHANT_KEY);

    const payload = {
      body: paytmParams,
      head: { signature: checksum }
    };

    console.log('[Paytm Initiate] Payload:', JSON.stringify(payload, null, 2));

    const response = await fetch(
      `${PAYTM_BASE_URL}/theia/api/v1/initiateTransaction?mid=${PAYTM_MID}&orderId=${order.order_number}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      }
    );

    const data = await response.json();
    console.log('[Paytm Initiate] Response:', JSON.stringify(data, null, 2));

    // Create payment record
    await supabaseAdmin.from('payments').insert({
      order_id: order_id, // keep UUID link
      merchant_order_id: order.order_number, // Use order number for matching
      amount,
      status: 'initiated',
      gateway: 'paytm',
      mode: 'web'
    });

    successResponse(res, {
      checksum,
      mid: PAYTM_MID,
      paytmResponse: data,
      message: 'Paytm payment initiated'
    });
  } catch (err) {
    console.error('Paytm API error:', err);
    throw new ApiError(500, 'Failed to initiate Paytm transaction');
  }
}));



// PAYTM CALLBACK/WEBHOOK (REDIRECT FLOW)
router.post('/callback', asyncHandler(async (req, res) => {
  const paytmParams = req.body;
  console.log('[Paytm Callback] Received:', paytmParams);
  console.log('[Paytm Callback] Debug Env:', {
    FRONTEND_URL: process.env.FRONTEND_URL,
    CALLBACK_URL: process.env.PAYTM_CALLBACK_URL
  });

  const receivedChecksum = paytmParams.CHECKSUMHASH;
  // delete paytmParams.CHECKSUMHASH; // Do not delete if verifySignature needs it in specific way, usually it handles it. 
  // But PaytmChecksum usually expects params WITHOUT checksumHash for generation, but verifySignature(params, key, checksum). 
  // Let's stick to standard practice: Cloning.

  const paramsForVerify = { ...paytmParams };
  delete paramsForVerify.CHECKSUMHASH;

  const isValid = PaytmChecksum.verifySignature(paramsForVerify, PAYTM_MERCHANT_KEY, receivedChecksum);

  if (!isValid) {
    console.error('[Paytm Callback] Invalid checksum');
    // Still redirect but maybe with error? Or just block? 
    // Usually bad to show success if fake.
    return res.status(400).send('Invalid checksum');
  }

  const orderId = paytmParams.ORDERID;
  const txnStatus = paytmParams.STATUS;
  const txnId = paytmParams.TXNID;
  const bankTxnId = paytmParams.BANKTXNID;
  const txnAmount = paytmParams.TXNAMOUNT;

  console.log('[Paytm Callback] Order ID:', orderId);
  console.log('[Paytm Callback] Transaction Status:', txnStatus);
  console.log('[Paytm Callback] Transaction ID:', txnId);
  console.log('[Paytm Callback] Bank Transaction ID:', bankTxnId);
  console.log('[Paytm Callback] Transaction Amount:', txnAmount);

  // Fetch existing order to check idempotency
  const { data: existingOrder, error: orderError } = await supabaseAdmin
    .from('orders')
    .select('id, user_id, payment_status, total_amount')
    .eq('order_number', orderId)
    .single();

  if (orderError) {
    console.error(`[Paytm Callback] Supabase error for ${orderId}:`, orderError);
  }

  if (!existingOrder) {
    console.error(`[Paytm Callback] Order ${orderId} not found. Error:`, orderError);
    return res.status(404).send('Order not found');
  }

  // Idempotency: If already marked as paid (likely by webhook), just redirect to success
  if (existingOrder.payment_status === 'paid' && txnStatus === 'TXN_SUCCESS') {
    console.log(`[Paytm Callback] Order ${orderId} already processed (idempotent). Redirecting...`);
    return res.redirect(`${process.env.FRONTEND_URL}/payment-status?orderId=${orderId}`);
  }

  let paymentStatus = 'failed';
  let orderStatus = 'payment_failed';

  if (txnStatus === 'TXN_SUCCESS') {
    paymentStatus = 'paid';
    orderStatus = 'searching_rider'; // INTERIM STATUS: Hide from Vendor until rider allotted
  } else if (txnStatus === 'PENDING') {
    paymentStatus = 'pending';
    orderStatus = 'pending';
  }

  // Update order
  const { data: updatedOrder } = await supabaseAdmin
    .from('orders')
    .update({
      payment_status: paymentStatus,
      payment_method: 'paytm',
      payment_id: txnId,
      status: orderStatus,
      updated_at: new Date().toISOString(),
    })
    .eq('order_number', orderId)
    .select('*, vendor:vendors(*)')
    .single();

  // Update payment record
  await supabaseAdmin
    .from('payments')
    .update({
      transaction_id: txnId,
      status: paymentStatus === 'paid' ? 'success' : paymentStatus,
      gateway_response: { ...paytmParams, payment_source: 'callback' },
      updated_at: new Date().toISOString(),
    })
    .eq('merchant_order_id', orderId);

  // LOGIC: Shadowfax Request before Vendor Notification
  if (updatedOrder && paymentStatus === 'paid') {
    try {
      // CHECK SUBSCRIPTION
      if (updatedOrder.order_source === 'subscription') {
        console.log(`[Subscription] Order ${orderId} is a subscription. Skipping Shadowfax.`);

        // Notify User (Success)
        await supabaseAdmin.from('notifications').insert({
          user_id: updatedOrder.user_id,
          type: 'payment_success',
          title: 'Subscription Activated!',
          message: `Your meal plan subscription is now active.`,
          data: { order_id: orderId, txn_id: txnId, is_subscription: true }
        });

        // Update status to 'paid' (already done) or specific subscription status if needed
      } else {

        // STANDARD ORDER - SHADOWFAX LOGIC
        let deliverySuccess = false;
        let sfResponse = null;

        // MOCK SHADOWFAX CHECK (Real Payment, Mock Delivery)
        // Relies solely on the checkbox sent from the frontend (mock_shadowfax field or [MOCK_SFX] tag)
        const isInternalMock = updatedOrder.mock_shadowfax || (updatedOrder.special_instructions && updatedOrder.special_instructions.includes('[MOCK_SFX]'));

        if (isInternalMock) {
          console.log(`🛠️ [Mock Shadowfax] Triggering INTERNAL Mock Delivery (DB Only) for Order ${orderId}`);
          const mockSfId = `SFX_MOCK_PAY_${Date.now()}`;
          const pickupOtp = "1234";
          const deliveryOtp = "5678";

          const insertPayload = {
            order_id: updatedOrder.id,
            partner_id: 'shadowfax',
            external_order_id: mockSfId,
            status: 'searching_rider',
            pickup_otp: pickupOtp,
            delivery_otp: deliveryOtp,
            history: [{
              status: 'searching_rider',
              timestamp: new Date().toISOString(),
              note: 'Mock Order Created (Real Payment - Internal)'
            }],
            courier_request_payload: { mock: true, source: 'real-payment-internal' }
          };

          await supabaseAdmin.from('deliveries').upsert(insertPayload, { onConflict: 'order_id' });

          await supabaseAdmin.from('orders').update({
            shadowfax_order_id: mockSfId
          }).eq('id', updatedOrder.id);

          console.log("✅ Internal Mock Delivery Created.");
          deliverySuccess = true;
 
          // Sync with local Shadowfax Mock Dashboard for visibility
          try {
            console.log(`📡 [Mock Shadowfax Callback] Syncing with local Dashboard...`);
            const { createShadowfaxOrder } = await import('../utils/shadowfax.js');
            const vendor = updatedOrder.vendor;
            if (vendor) {
              if (updatedOrder.delivery_address && typeof updatedOrder.delivery_address === 'string') {
                try { updatedOrder.delivery_address = JSON.parse(updatedOrder.delivery_address); } catch (e) { }
              }
              await createShadowfaxOrder(updatedOrder, vendor, { pickup_otp: pickupOtp, delivery_otp: deliveryOtp });
            }
          } catch (syncErr) {
            console.error("❌ [Mock Shadowfax Callback] Sync Error:", syncErr.message);
          }

        } else {
          // REAL SHADOWFAX
          const { createShadowfaxOrder } = await import('../utils/shadowfax.js');

          // Ensure delivery_address is an object
          if (updatedOrder.delivery_address && typeof updatedOrder.delivery_address === 'string') {
            try {
              updatedOrder.delivery_address = JSON.parse(updatedOrder.delivery_address);
            } catch (e) {
              console.error("Failed to parse delivery_address JSON:", e);
            }
          }

          // Generate OTPs
          const pickupOtp = Math.floor(1000 + Math.random() * 9000).toString();
          const deliveryOtp = Math.floor(1000 + Math.random() * 9000).toString();

          // Call Shadowfax
          sfResponse = await createShadowfaxOrder(updatedOrder, updatedOrder.vendor, { pickup_otp: pickupOtp, delivery_otp: deliveryOtp });

          if (sfResponse && sfResponse.success) {
            const shadowfaxId = sfResponse.data.sfx_order_id || sfResponse.data.flash_order_id || sfResponse.data.client_order_id || sfResponse.data.id;

            console.log(`[Shadowfax] Order ${orderId} accepted. ID: ${shadowfaxId}. OTPs: ${pickupOtp}/${deliveryOtp}`);

            const insertPayload = {
              order_id: updatedOrder.id,
              partner_id: 'shadowfax',
              external_order_id: shadowfaxId,
              status: 'searching_rider',
              pickup_otp: pickupOtp,
              delivery_otp: deliveryOtp
            };

            await supabaseAdmin.from('deliveries').upsert(insertPayload, { onConflict: 'order_id' });

            // Force Update OTPs
            await supabaseAdmin.from('deliveries').update({ pickup_otp: pickupOtp, delivery_otp: deliveryOtp }).eq('order_id', updatedOrder.id);

            // Update Order
            await supabaseAdmin.from('orders').update({ shadowfax_order_id: shadowfaxId }).eq('id', updatedOrder.id);

            deliverySuccess = true;
          }
        }

        if (deliverySuccess) {
          // Notify User (Success)
          await supabaseAdmin.from('notifications').insert({
            user_id: updatedOrder.user_id,
            type: 'payment_success',
            title: 'Payment Successful!',
            message: `Payment received. Searching for delivery partner...`,
            data: { order_id: orderId, txn_id: txnId }
          });

          console.log(`[Shadowfax] Order ${orderId} accepted. Notification delayed until rider allocation.`);

        } else {
          // Failure Block
          console.error(`[Shadowfax] Order ${orderId} rejected/failed. Reason: ${sfResponse?.error}`);

          // 1. Mark Order as Cancelled / Refund Initiated
          await supabaseAdmin.from('orders').update({
            status: 'cancelled',
            cancellation_reason: 'Delivery partner unavailable',
            cancelled_by: 'system',
            cancelled_at: new Date().toISOString()
          }).eq('id', updatedOrder.id);

          // 2. Initiate Auto-Refund
          console.log(`[Auto-Refund] Initiating refund for ${orderId}`);

          // Notify User (Failure)
          await supabaseAdmin.from('notifications').insert({
            user_id: updatedOrder.user_id,
            type: 'order_cancelled',
            title: 'Order Cancelled',
            message: `Payment successful but no delivery partner available. Refund initiated.`,
            data: { order_id: orderId }
          });
        }
      }
    } catch (err) {
      console.error('[Shadowfax] Flow Error:', err);
    }
  } else if (updatedOrder && paymentStatus !== 'paid') {
    // Payment Failed Logic
    await supabaseAdmin.from('notifications').insert({
      user_id: updatedOrder.user_id,
      type: 'payment_failed',
      title: 'Payment Failed',
      message: `Payment failed for order #${orderId}. Please try again.`,
      data: { order_id: orderId, txn_id: txnId }
    });
  }

  console.log(`[Paytm Callback] Order ${orderId} processed.`);

  // Redirect based on status (modified to show correct state)
  // If we auto-cancelled, we might want to redirect to a "refunded" or "cancelled" page if possible, 
  // currently just redirecting to status page.
  if (txnStatus === 'TXN_SUCCESS') {
    res.redirect(`${process.env.FRONTEND_URL}/payment-status?orderId=${orderId}`);
  } else {
    res.redirect(`${process.env.FRONTEND_URL}/payment-status?orderId=${orderId}&status=failed&reason=${txnStatus}`);
  }
}));

// PAYTM S2S WEBHOOK (BACKGROUND NOTIFICATION)
router.post('/webhook', asyncHandler(async (req, res) => {

  const paytmParams = req.body;
  console.log('[Paytm Webhook] Received:', JSON.stringify(paytmParams));

  // const testPhone = '+919944751745';
  // const apiUrl = `http://localhost:${process.env.PORT || 5000}/api/auth/send-otp`;

  // try {
  //   const response = await fetch(apiUrl, {
  //     method: "POST",
  //     headers: { "Content-Type": "application/json" },
  //     body: JSON.stringify({ phone: testPhone })
  //   });

  //   const status = response.status;
  //   const body = await response.json();

  //   console.log(`[Webhook Debug OTP] Success: ${status}`, body);
  //   //return res.status(200).send(`DEBUG_FETCH_SUCCESS: ${status} ${JSON.stringify(body)}`);
  // } catch (error) {
  //   console.error('[Webhook Debug OTP] Error:', error.message);
  //   //return res.status(200).send(`DEBUG_FETCH_ERROR: ${error.message}`);
  // }

  // 1. Capture payload and signature
  //const paytmParams = req.body;
  const receivedChecksum =
    paytmParams.CHECKSUMHASH ||
    req.headers['x-paytm-signature'] ||
    req.headers['signature'] ||
    req.headers['x-paytm-checksum'];

  console.log('[Paytm Webhook] Webhook ID:', paytmParams.ORDERID);
  console.log('[Paytm Webhook] Checksum:', receivedChecksum ? 'PRESENT' : 'MISSING');

  // 2. Verification Logic
  let isValid = false;
  if (receivedChecksum) {
    const paramsForVerify = { ...paytmParams };
    delete paramsForVerify.CHECKSUMHASH;
    isValid = PaytmChecksum.verifySignature(paramsForVerify, PAYTM_MERCHANT_KEY, receivedChecksum);
  }

  // 3. Secure Fallback if not valid/present
  if (!isValid) {
    console.log(`[Paytm Webhook] Verification ${receivedChecksum ? 'failed' : 'missing'}. Calling Status API as fallback...`);
    const statusCheck = await verifyPaytmStatus(paytmParams.ORDERID);

    if (statusCheck.success) {
      console.log(`[Paytm Webhook] ✅ Securely Verified via Paytm Status API: SUCCESS`);
      isValid = true;
    } else {
      console.error(`[Paytm Webhook] ❌ Secure API verification failed: ${statusCheck.status || 'unknown'}`);
      if (!receivedChecksum) {
        console.log('[Paytm Webhook] DEBUG HEADERS:', JSON.stringify(req.headers));
      }
      return res.status(200).send('VERIFICATION_FAILED');
    }
  }

  // 3. Process Status
  const orderId = paytmParams.ORDERID;
  const txnStatus = paytmParams.STATUS;
  const txnId = paytmParams.TXNID;
  const txnAmount = paytmParams.TXNAMOUNT;

  // console.log(`[Paytm Webhook] Processing Order: ${orderId}, Status: ${txnStatus}`);

  // Fetch existing order to check idempotency and validate amount
  const { data: existingOrder } = await supabaseAdmin
    .from('orders')
    .select('id, user_id, payment_status, total_amount')
    .eq('order_number', orderId)
    .single();

  if (!existingOrder) {
    console.error(`[Paytm Webhook] Order ${orderId} not found`);
    return res.status(200).send('ORDER_NOT_FOUND');
  }

  // Validate Amount
  if (txnAmount) {
    const orderAmount = parseFloat(existingOrder.total_amount);
    const paidAmount = parseFloat(txnAmount);
    // Allow for very small floating point diff (e.g. 0.01)
    if (Math.abs(orderAmount - paidAmount) > 0.05) {
      console.error(`[Paytm Webhook] Amount mismatch for ${orderId}. Expected ${orderAmount}, got ${paidAmount}`);
      // Log this suspicious activity but do NOT mark as paid
      return res.status(200).send('AMOUNT_MISMATCH');
    }
  }

  // Idempotency: If already paid, do nothing
  if (existingOrder.payment_status === 'paid' && txnStatus === 'TXN_SUCCESS') {
    // console.log(`[Paytm Webhook] Order ${orderId} already paid. Skipping update.`);
    return res.status(200).send('OK');
  }

  let paymentStatus = 'failed';
  let orderStatus = 'payment_failed';

  if (txnStatus === 'TXN_SUCCESS') {
    paymentStatus = 'paid';
    orderStatus = 'searching_rider'; // INTERIM STATUS: Hide from Vendor until rider allotted
  } else if (txnStatus === 'PENDING') {
    paymentStatus = 'pending';
    orderStatus = 'pending';
  }

  // Update Order
  const { data: updatedOrder } = await supabaseAdmin
    .from('orders')
    .update({
      payment_status: paymentStatus,
      payment_method: 'paytm',
      payment_id: txnId,
      status: orderStatus,
      updated_at: new Date().toISOString(),
    })
    .eq('order_number', orderId)
    .select('*, vendor:vendors(*)')
    .single();

  // Update Payment Record
  await supabaseAdmin
    .from('payments')
    .update({
      transaction_id: txnId,
      status: paymentStatus === 'paid' ? 'success' : paymentStatus,
      gateway_response: { ...paytmParams, payment_source: 'webhook' },
      updated_at: new Date().toISOString(),
    })
    .eq('merchant_order_id', orderId);

  // LOGIC: Shadowfax Request before Vendor Notification (Synced with Callback)
  if (paymentStatus === 'paid' && existingOrder.payment_status !== 'paid' && updatedOrder) {
    try {
      // CHECK SUBSCRIPTION
      if (updatedOrder.order_source === 'subscription') {
        console.log(`[Subscription Webhook] Order ${orderId} is a subscription. Skipping Shadowfax.`);

        // Notify User (Success)
        await supabaseAdmin.from('notifications').insert({
          user_id: existingOrder.user_id,
          type: 'payment_success',
          title: 'Subscription Activated!',
          message: `Your meal plan subscription is now active.`,
          data: { order_id: orderId, txn_id: txnId, is_subscription: true }
        });

      } else {
        // STANDARD ORDER - SHADOWFAX LOGIC
        let deliverySuccess = false;
        let sfResponse = null;

        // MOCK SHADOWFAX CHECK
        // Relies solely on the checkbox sent from the frontend (mock_shadowfax field or [MOCK_SFX] tag)
        const isInternalMock = updatedOrder.mock_shadowfax || (updatedOrder.special_instructions && updatedOrder.special_instructions.includes('[MOCK_SFX]'));

        if (isInternalMock) {
          console.log(`🛠️ [Mock Shadowfax Webhook] Triggering INTERNAL Mock Delivery (DB Only) for Order ${orderId}`);
          const mockSfId = `SFX_MOCK_PAY_WH_${Date.now()}`;
          const pickupOtp = "1234";
          const deliveryOtp = "5678";

          const insertPayload = {
            order_id: updatedOrder.id,
            partner_id: 'shadowfax',
            external_order_id: mockSfId,
            status: 'searching_rider',
            pickup_otp: pickupOtp,
            delivery_otp: deliveryOtp,
            history: [{
              status: 'searching_rider',
              timestamp: new Date().toISOString(),
              note: 'Mock Order Created (Webhook - Internal)'
            }],
            courier_request_payload: { mock: true, source: 'real-payment-webhook-internal' }
          };

          await supabaseAdmin.from('deliveries').upsert(insertPayload, { onConflict: 'order_id' });

          await supabaseAdmin.from('orders').update({
            shadowfax_order_id: mockSfId
          }).eq('id', updatedOrder.id);

          console.log("✅ Internal Mock Delivery Created via Webhook.");
          deliverySuccess = true;
 
          // Sync with local Shadowfax Mock Dashboard for visibility
          try {
            console.log(`📡 [Mock Shadowfax Webhook] Syncing with local Dashboard...`);
            const { createShadowfaxOrder } = await import('../utils/shadowfax.js');
            const vendor = updatedOrder.vendor;
            if (vendor) {
              if (updatedOrder.delivery_address && typeof updatedOrder.delivery_address === 'string') {
                try { updatedOrder.delivery_address = JSON.parse(updatedOrder.delivery_address); } catch (e) { }
              }
              await createShadowfaxOrder(updatedOrder, vendor, { pickup_otp: pickupOtp, delivery_otp: deliveryOtp });
            }
          } catch (syncErr) {
            console.error("❌ [Mock Shadowfax Webhook] Sync Error:", syncErr.message);
          }

        } else {
          // REAL SHADOWFAX
          const { createShadowfaxOrder } = await import('../utils/shadowfax.js');

          // Ensure delivery_address is an object
          if (updatedOrder.delivery_address && typeof updatedOrder.delivery_address === 'string') {
            try {
              updatedOrder.delivery_address = JSON.parse(updatedOrder.delivery_address);
            } catch (e) {
              console.error("Failed to parse delivery_address JSON in webhook:", e);
            }
          }

          // Generate OTPs
          const pickupOtp = Math.floor(1000 + Math.random() * 9000).toString();
          const deliveryOtp = Math.floor(1000 + Math.random() * 9000).toString();

          // Call Shadowfax
          sfResponse = await createShadowfaxOrder(updatedOrder, updatedOrder.vendor, { pickup_otp: pickupOtp, delivery_otp: deliveryOtp });

          if (sfResponse && sfResponse.success) {
            const shadowfaxId = sfResponse.data.sfx_order_id || sfResponse.data.flash_order_id || sfResponse.data.client_order_id || sfResponse.data.id;

            console.log(`[Shadowfax Webhook] Order ${orderId} accepted. ID: ${shadowfaxId}. OTPs: ${pickupOtp}/${deliveryOtp}`);

            const insertPayload = {
              order_id: updatedOrder.id,
              partner_id: 'shadowfax',
              external_order_id: shadowfaxId,
              status: 'searching_rider',
              pickup_otp: pickupOtp,
              delivery_otp: deliveryOtp
            };

            await supabaseAdmin.from('deliveries').upsert(insertPayload, { onConflict: 'order_id' });

            // Force Update OTPs
            await supabaseAdmin.from('deliveries').update({ pickup_otp: pickupOtp, delivery_otp: deliveryOtp }).eq('order_id', updatedOrder.id);

            // Update Order
            await supabaseAdmin.from('orders').update({ shadowfax_order_id: shadowfaxId }).eq('id', updatedOrder.id);

            deliverySuccess = true;
          }
        }

        if (deliverySuccess) {
          // Notify User (Success)
          await supabaseAdmin.from('notifications').insert({
            user_id: existingOrder.user_id,
            type: 'payment_success',
            title: 'Payment Successful!',
            message: `Payment of ₹${txnAmount} received. Searching for delivery partner...`,
            data: { order_id: orderId, txn_id: txnId }
          });

          console.log(`[Shadowfax Webhook] Order ${orderId} accepted. Notification sent.`);

        } else {
          // Failure Block
          console.error(`[Shadowfax Webhook] Order ${orderId} rejected/failed. Reason: ${sfResponse?.error}`);

          // 1. Mark Order as Cancelled / Refund Initiated
          await supabaseAdmin.from('orders').update({
            status: 'cancelled',
            cancellation_reason: 'Delivery partner unavailable (Auto)',
            cancelled_by: 'system',
            cancelled_at: new Date().toISOString()
          }).eq('id', updatedOrder.id);

          // 2. Notify User (Failure)
          await supabaseAdmin.from('notifications').insert({
            user_id: existingOrder.user_id,
            type: 'order_cancelled',
            title: 'Order Cancelled',
            message: `Payment successful but no delivery partner available. Refund initiated.`,
            data: { order_id: orderId }
          });
        }
      }
    } catch (err) {
      console.error('[Shadowfax Webhook] Flow Error:', err);
    }
  } else if (updatedOrder && paymentStatus !== 'paid' && existingOrder.payment_status !== 'paid') {
    // Payment Failed Logic
    await supabaseAdmin.from('notifications').insert({
      user_id: existingOrder.user_id,
      type: 'payment_failed',
      title: 'Payment Failed',
      message: `Payment failed for order #${orderId}. Please try again.`,
      data: { order_id: orderId, txn_id: txnId }
    });
  }

  // console.log(`[Paytm Webhook] Successfully processed ${orderId}`);
  return res.status(200).send('OK');
}));


// PAYTM REFUND WEBHOOK
router.post('/webhook/refund', asyncHandler(async (req, res) => {
  const paytmParams = req.body;
  // console.log('[Paytm Refund Webhook] Received:', JSON.stringify(paytmParams));

  const receivedChecksum = paytmParams.CHECKSUMHASH;
  if (!receivedChecksum) return res.status(200).send('CHECKSUM_MISSING');

  const paramsForVerify = { ...paytmParams };
  delete paramsForVerify.CHECKSUMHASH;

  const isValid = PaytmChecksum.verifySignature(paramsForVerify, PAYTM_MERCHANT_KEY, receivedChecksum);
  if (!isValid) return res.status(200).send('CHECKSUM_INVALID');

  // Parse fields
  const orderId = paytmParams.ORDERID;
  const refundId = paytmParams.REFID; // Our internal refund ID
  const refundAmount = paytmParams.REFUNDAMOUNT;
  // Use STATUS or refund status field depending on exact payload. 
  // Common Paytm refund webhooks often use 'STATUS' just like payment.
  // But sometimes it might be 'RESULT' or similar. We will assume standard structure.

  // NOTE: If this is 'Success Refund' webhook, status is usually 'TXN_SUCCESS' or 'SUCCESS'
  // If 'Accept Refund', it might be 'PENDING'

  // Update Payment/Order status
  // We'll update the 'payments' table to reflect refund. 
  // Ideally we should have a 'refunds' table, but for now we might update 'payments' or just log.

  // Since we don't have a refunds table explicitly shown in previous code, 
  // we will update the payment status to 'refunded' if it's a full refund.

  const { data: payment } = await supabaseAdmin
    .from('payments')
    .select('*, order:orders(id, total_amount)')
    .eq('merchant_order_id', orderId)
    .single();

  if (!payment) return res.status(200).send('ORDER_NOT_FOUND');

  if (paytmParams.STATUS === 'TXN_SUCCESS' || paytmParams.STATUS === 'SUCCESS') {
    // Mark as refunded
    await supabaseAdmin
      .from('payments')
      .update({
        status: 'refunded', // Simple state update
        gateway_response: { ...payment.gateway_response, refund_webhook: paytmParams },
        updated_at: new Date().toISOString()
      })
      .eq('id', payment.id);

    // Also update order status if needed
    // await supabaseAdmin.from('orders').update({ payment_status: 'refunded' }).eq('order_number', orderId);
  }

  return res.status(200).send('OK');
}));

// CHECK PAYMENT STATUS
router.get('/:id/status', asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Check if id is UUID
  const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

  let query = supabaseAdmin
    .from('orders')
    .select('payment_status, id, order_number');

  if (isUUID) {
    query = query.eq('id', id);
  } else {
    query = query.eq('order_number', id);
  }

  const { data: order, error } = await query.single();

  if (error || !order) {
    // Try checking payments table directly if order not found
    // Payments table uses merchant_order_id (usually GZ)
    const { data: payment } = await supabaseAdmin
      .from('payments')
      .select('status, merchant_order_id')
      .eq('merchant_order_id', id)
      .maybeSingle();

    if (payment) {
      let code = 'PENDING';
      let state = 'PENDING';

      if (payment.status === 'success' || payment.status === 'paid') {
        code = 'SUCCESS';
        state = 'COMPLETED';
      } else if (payment.status === 'failed' || payment.status === 'cancelled') {
        code = 'FAILED';
        state = 'FAILED';
      }

      return successResponse(res, {
        code,
        state,
        transactionId: payment.merchant_order_id // Return the GZ ID
      });
    }
    return res.status(404).json({ success: false, message: 'Order not found' });
  }

  // Map internal status to generic status expected by frontend
  let code = 'PENDING';
  let state = 'PENDING';

  if (order.payment_status === 'paid') {
    code = 'SUCCESS';
    state = 'COMPLETED';
  } else if (order.payment_status === 'failed' || order.payment_status === 'cancelled') {
    code = 'FAILED';
    state = 'FAILED';
  }

  successResponse(res, {
    code,
    state,
    transactionId: order.order_number // ALWAYS return the GZ ID
  });
}));

// PAYTM REFUND
router.post('/refund', authenticate, asyncHandler(async (req, res) => {
  const { order_id, refund_amount, reason } = req.body;

  if (!order_id || !refund_amount) {
    throw new ApiError(400, 'Order ID and refund amount are required');
  }

  const { data: order } = await supabaseAdmin
    .from('orders')
    .select('*')
    .eq('id', order_id)
    .eq('user_id', req.user.id)
    .single();

  if (!order) throw new ApiError(404, 'Order not found');
  if (order.payment_status !== 'paid') throw new ApiError(400, 'Can only refund paid orders');

  const refundId = `REFUND_${Date.now()}`;

  const paytmParams = {
    MID: PAYTM_MID,
    TXNID: order.payment_id,
    ORDERID: order.order_number,
    REFUNDAMOUNT: String(refund_amount),
    REFID: refundId,
  };

  try {
    const checksum = await PaytmChecksum.generateSignature(paytmParams, PAYTM_MERCHANT_KEY);

    const payload = {
      body: paytmParams,
      head: { signature: checksum }
    };

    const response = await fetch(
      `${PAYTM_BASE_URL}/refund/apply`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      }
    );

    const data = await response.json();
    // console.log('Paytm refund response:', data);

    // Create support ticket for tracking
    await supabaseAdmin
      .from('support_tickets')
      .insert({
        user_id: req.user.id,
        order_id,
        subject: `Refund Request - Order #${order.order_number}`,
        description: reason || 'Refund requested',
        category: 'refund',
        priority: 'high'
      });

    successResponse(res, {
      refund_id: refundId,
      status: data?.body?.resultInfo?.resultStatus || 'PENDING',
      message: 'Refund initiated'
    });
  } catch (err) {
    console.error('Paytm refund error:', err);
    throw new ApiError(500, 'Error processing refund');
  }
}));

// ============================================
// GENERIC PAYMENT ENDPOINTS
// ============================================

// GET PAYMENT STATUS
router.get('/status/:paymentId', authenticate, asyncHandler(async (req, res) => {
  const { data: payment, error } = await supabaseAdmin
    .from('payments')
    .select('*')
    .eq('id', req.params.paymentId)
    .single();

  if (error || !payment) throw new ApiError(404, 'Payment not found');

  successResponse(res, {
    payment_id: payment.id,
    status: payment.status,
    amount: payment.amount,
    gateway: payment.gateway,
    transaction_id: payment.transaction_id
  });
}));

// GET USER PAYMENT HISTORY
router.get('/history', authenticate, asyncHandler(async (req, res) => {
  const { page = 1, limit = 20 } = req.query;

  const { data: payments, error, count } = await supabaseAdmin
    .from('payments')
    .select('*, order:orders(order_number, vendor_name, total_amount)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((page - 1) * limit, page * limit - 1);

  if (error) throw new ApiError(500, 'Failed to fetch payments');

  successResponse(res, { payments, page, limit, total: count });
}));

// ============================================
// MOCK PAYMENT (FOR DEV TEST ONLY)
// POST /api/payments/mock-success
// ============================================
if (process.env.NODE_ENV === 'development') {
  router.post('/mock-success', asyncHandler(async (req, res) => {
    const { orderId, mockShadowfax } = req.body;

    // Mark order as paid
    const { data: order } = await supabaseAdmin.from('orders').update({
      payment_status: 'paid',
      status: 'searching_rider', // INTERIM STATUS
      payment_method: 'mock',
      payment_id: 'MOCK_' + Date.now()
    }).eq('order_number', orderId).select().single();
    
    if (!order) {
      console.error(`❌ [Mock Payment] Order not found: ${orderId}`);
      throw new ApiError(404, `Order ${orderId} not found`);
    }
 
    // Notify
    await supabaseAdmin.from('notifications').insert({
      user_id: order.user_id,
      type: 'payment_success',
      title: 'Mock Payment Successful',
      message: `Mock payment for order #${orderId}`,
      data: { order_id: orderId }
    });

    // Shadowfax logic — behaviour depends on the mock checkbox
    if (order) {
      if (mockShadowfax) {
        // INTERNAL MOCK: No real Shadowfax API call at all — DB only
        console.log(`🛠️ [Mock Payment] Creating INTERNAL Mock Delivery (DB Only) for ${orderId}`);
        try {
          const mockSfId = `SFX_MOCK_${Date.now()}`;
          const pickupOtp = '1234';
          const deliveryOtp = '5678';

          await supabaseAdmin.from('deliveries').upsert({
            order_id: order.id,
            partner_id: 'shadowfax',
            external_order_id: mockSfId,
            status: 'searching_rider',
            pickup_otp: pickupOtp,
            delivery_otp: deliveryOtp,
            history: [{
              status: 'searching_rider',
              timestamp: new Date().toISOString(),
              note: 'Mock Delivery Created (No Real Shadowfax API Call)'
            }],
            courier_request_payload: { mock: true, source: 'mock-payment-internal' }
          }, { onConflict: 'order_id' });

          await supabaseAdmin.from('orders').update({
            shadowfax_order_id: mockSfId,
            status: 'searching_rider'
          }).eq('id', order.id);

          console.log(`✅ [Mock Payment] Internal Mock Delivery Created: ${mockSfId}`);
 
          // Sync with local Shadowfax Mock Dashboard for visibility
          console.log(`📡 [Mock Payment] Syncing with local Shadowfax Mock Dashboard...`);
          const { createShadowfaxOrder } = await import('../utils/shadowfax.js');
          const { data: vendor } = await supabaseAdmin.from('vendors').select('*').eq('id', order.vendor_id).single();
          if (vendor) {
            if (order.delivery_address && typeof order.delivery_address === 'string') {
                try { order.delivery_address = JSON.parse(order.delivery_address); } catch (e) { }
            }
            await createShadowfaxOrder(order, vendor, { pickup_otp: pickupOtp, delivery_otp: deliveryOtp });
          }
        } catch (err) {
          console.error('❌ [Mock Payment] Error creating mock delivery:', err);
        }

      } else {
        // REAL SHADOWFAX: Only when mock checkbox is unchecked
        console.log(`🚀 [Mock Payment] Triggering REAL Shadowfax for ${orderId}`);
        try {
          const { createShadowfaxOrder } = await import('../utils/shadowfax.js');

          const { data: vendor } = await supabaseAdmin
            .from('vendors')
            .select('*')
            .eq('id', order.vendor_id)
            .single();

          if (vendor) {
            if (order.delivery_address && typeof order.delivery_address === 'string') {
              try { order.delivery_address = JSON.parse(order.delivery_address); } catch (e) { }
            }

            const pickupOtp = Math.floor(1000 + Math.random() * 9000).toString();
            const deliveryOtp = Math.floor(1000 + Math.random() * 9000).toString();

            const sfResponse = await createShadowfaxOrder(order, vendor, { pickup_otp: pickupOtp, delivery_otp: deliveryOtp });

            if (sfResponse && sfResponse.success) {
              const shadowfaxId = sfResponse.data.sfx_order_id || sfResponse.data.flash_order_id || sfResponse.data.client_order_id || sfResponse.data.id;
              console.log(`✅ [Mock Payment] Real Shadowfax Order Created: ${shadowfaxId}`);

              await supabaseAdmin.from('deliveries').upsert({
                order_id: order.id,
                external_order_id: shadowfaxId,
                partner_id: 'shadowfax',
                status: 'searching_rider',
                pickup_otp: pickupOtp,
                delivery_otp: deliveryOtp,
                history: [{ status: 'searching_rider', timestamp: new Date().toISOString(), note: 'Order Created (Real Shadowfax API)' }],
                courier_request_payload: sfResponse.data
              }, { onConflict: 'order_id' });

              await supabaseAdmin.from('orders').update({
                shadowfax_order_id: shadowfaxId,
                status: 'searching_rider'
              }).eq('id', order.id);
            } else {
              console.error('❌ [Mock Payment] Real Shadowfax failed:', sfResponse);
            }
          } else {
            console.error('❌ [Mock Payment] Vendor not found');
          }
        } catch (err) {
          console.error('❌ [Mock Payment] Error triggering real Shadowfax:', err);
        }
      }
    }

    // Notify Vendor logic... (simplified here)

    successResponse(res, { order, mockTriggered: !!mockShadowfax }, "Order marked as paid (Mock)");
  }));
}

export default router;

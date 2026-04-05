import express from 'express';
import { createClient } from '@supabase/supabase-js';

const router = express.Router();

// Shadowfax API Config
const SHADOWFAX_API_URL = process.env.SHADOWFAX_API_URL;
const SHADOWFAX_API_TOKEN = process.env.SHADOWFAX_API_TOKEN;

router.post('/serviceability', async (req, res) => {
  try {
    const { pickup_details, drop_details } = req.body;

    if (!pickup_details || !drop_details) {
      return res.status(400).json({ success: false, message: 'Pickup and Drop details are required' });
    }

    if (!SHADOWFAX_API_TOKEN) {
      console.warn('SHADOWFAX_API_TOKEN is not set');
      // Return a mock response or error in dev if token missing
      // For now, fail gracefully
      return res.status(503).json({ success: false, message: 'Delivery service configuration missing' });
    }


    const formattedPayload = {
      pickup_details: {
        building_name: pickup_details.building_name,
        latitude: parseFloat(pickup_details.latitude) || 0,
        longitude: parseFloat(pickup_details.longitude) || 0,
        address: pickup_details.address
      },
      drop_details: {
        building_name: drop_details.building_name,
        latitude: parseFloat(drop_details.latitude) || 0,
        longitude: parseFloat(drop_details.longitude) || 0,
        address: drop_details.address
      }
    };

    // console.log('Sending Serviceability Request:', JSON.stringify(formattedPayload, null, 2));

    const response = await fetch(`${SHADOWFAX_API_URL}/order/serviceability/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': SHADOWFAX_API_TOKEN
      },
      body: JSON.stringify(formattedPayload)
    });

    const data = await response.json();

    if (response.ok) {
        // Shadowfax success response
        // data structure: { value: { is_serviceable: true, pickup_eta: "10 Mins", ... } } 
        // Note: The docs say structure varies by example, but standard success is usually inside 'value' or direct keys 
        // depending on if it's Swagger example or real response.
        // Real response usually flat properties or inside a wrapper.
        // Let's pass the whole data back for frontend to parse, or parse here.
        // Docs example: "value": { "is_serviceable": true, "pickup_eta": "10 Mins", ... }
        // Wait, the docs showed "examples" key. The actual response likely just has the fields directly or data wrapper.
        // Let's assume standard response matches the schema: ServiceabilityRequest -> ServiceabilityResponse (implied).
        // I will return the full data.
        res.json({ success: true, data: data });
    } else {
        console.error('Shadowfax Error:', data);
        res.status(response.status).json({ success: false, message: data.message || 'Shadowfax Provider Error', details: data });
    }

  } catch (error) {
    console.error('Delivery Serviceability Route Error:', error);
    res.status(500).json({ success: false, message: 'Internal Server Error' });
  }
});

// Live Tracking Route
router.get('/track/:orderId', async (req, res) => {
    try {
        const { orderId } = req.params;

        // 1. Get deliveries record
        // OrderId could be UUID or 'GZ...' (order_number)
        // Let's assume orderId param is EITHER. We need to find the delivery record.
        // First find order UUID if it's a number
        let orderUUID = orderId;
        let ord = null;
        
        // Quick check if orderId is likely a UUID
        const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(orderId);

        if (!isUUID) {
             // It's already the order number (GZ...)
             const response = await createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY)
                .from('orders').select('id, order_number, mock_shadowfax').eq('order_number', orderId).single();
             ord = response.data;
             if (ord) {
                 orderUUID = ord.id;
             }
             else return res.status(404).json({ success: false, message: 'Order not found' });
        } else {
             // It is a UUID, fetch the order_number
             const response = await createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY)
                .from('orders').select('id, order_number, mock_shadowfax').eq('id', orderId).single();
             ord = response.data;
             if (!ord) return res.status(404).json({ success: false, message: 'Order UUID not found' });
             // Update orderId param to be the number for tracking
             orderId = ord.order_number; 
        }

        // 2. Call Shadowfax Tracking
        const { trackShadowfaxOrder } = await import('../utils/shadowfax.js');
        
        const trackingId = orderId;
        
        const trackingInfo = await trackShadowfaxOrder(trackingId, ord?.mock_shadowfax);

        if (!trackingInfo) {
            return res.status(500).json({ success: false, message: 'Failed to fetch tracking info' });
        }

        // --- UNIVERSAL SYNC LOGIC (Fallbacks for Failed Webhooks) ---
        
        // A. Fetch Local Delivery Status First
        const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);
        const { data: delivery } = await supabase
            .from('deliveries')
            .select('*')
            .eq('order_id', orderUUID)
            .single();

        if (delivery) {
             const sfStatus = trackingInfo.status ? trackingInfo.status.toUpperCase() : ''; // Normalize
             let internalStatus = sfStatus.toLowerCase(); // Default

             // MAPPING LOGIC (Must match shadowfax.js webhook logic)
             if (sfStatus === 'ARRIVED') internalStatus = 'reached_location';
             else if (sfStatus === 'COLLECTED') internalStatus = 'picked_up';
             else if (sfStatus === 'CUSTOMER_DOOR_STEP') internalStatus = 'arrived_at_drop';
             else if (sfStatus === 'DELIVERED') internalStatus = 'delivered';

             // Check for Drift (Database Status vs Real API Status)
             // We only update if the status is DIFFERENT and meaningful
             // (Simple check: if internalStatus !== delivery.status)
             // Note: internalStatus is the fresh truth.

             if (internalStatus !== delivery.status && internalStatus !== 'unknown') {
                 console.log(`[Sync] 🔄 Resolving Status Drift for ${trackingId}: DB=${delivery.status} -> API=${internalStatus}`);

                 // 1. Prepare Delivery Update
                 const newHistoryItem = {
                    status: internalStatus,
                    timestamp: new Date().toISOString(),
                    note: `Auto-Sync: API Polling detected ${sfStatus}`
                 };
                 
                 const updatedHistory = delivery.history ? [...delivery.history, newHistoryItem] : [newHistoryItem];

                 const deliveryUpdatePayload = {
                     status: internalStatus,
                     rider_name: trackingInfo.rider_details?.name,
                     rider_phone: trackingInfo.rider_details?.contact_number,
                     rider_coordinates: trackingInfo.rider_details?.current_location,
                     rider_id: trackingInfo.rider_details?.id ? String(trackingInfo.rider_details.id) : null,
                     history: updatedHistory,
                     updated_at: new Date().toISOString()
                 };

                 await supabase
                     .from('deliveries')
                     .update(deliveryUpdatePayload)
                     .eq('id', delivery.id);

                 // 2. Prepare Order Update (For critical status changes)
                 const orderPayload = {};
                 if (sfStatus === 'DELIVERED') {
                     orderPayload.status = 'completed'; 
                 } else if (sfStatus === 'COLLECTED') {
                     orderPayload.status = 'on_way'; 
                 } else if (sfStatus === 'CANCELLED') {
                     orderPayload.status = 'cancelled';
                 } else if (sfStatus === 'ACCEPTED' && (delivery.status === 'searching_rider' || delivery.status === 'created')) {
                     // Special Case: Vendor needs to know driver is assigned
                     orderPayload.status = 'confirmed'; 
                     
                     // Trigger Vendor Notification (Re-using existing logic)
                     const { data: fullOrder } = await supabase
                         .from('orders')
                         .select('*, vendor:vendors(*)')
                         .eq('id', orderUUID) 
                         .single();

                     if (fullOrder && fullOrder.vendor) {
                          // Send Email
                          import('../utils/emailService.js').then(({ sendVendorOrderNotification }) => {
                              sendVendorOrderNotification(fullOrder.vendor.email, fullOrder);
                          });
                          // Send Push
                          import('../utils/pushService.js').then(({ sendVendorPush }) => {
                              const msg = `Rider Assigned! ${trackingInfo.rider_details?.name || 'Partner'} is on the way.`;
                              sendVendorPush(fullOrder.vendor.id, 'Order Update 🔔', msg);
                          });
                          console.log(`[Sync] ✅ Vendor Notified of Rider Assignment.`);
                     }
                 }

                 if (Object.keys(orderPayload).length > 0) {
                     await supabase
                        .from('orders')
                        .update({
                            ...orderPayload,
                            updated_at: new Date().toISOString()
                        })
                        .eq('id', orderUUID);
                     console.log(`[Sync] ✅ Orders table updated to ${orderPayload.status}`);
                 }

                 console.log(`[Sync] ✅ Delivery state synchronized.`);
             }
        }
        // ---------------------------------------------------

        if (delivery) {
             // INJECT INTERNAL OTPs into the response
             trackingInfo.delivery_otp = delivery.delivery_otp;
             trackingInfo.pickup_otp = delivery.pickup_otp; // Included for Vendor/Debug visibility
        }

        res.json({ success: true, data: trackingInfo });

    } catch (e) {
        console.error("Tracking Route Error:", e);
        res.status(500).json({ success: false, message: 'Internal Error' });
    }
});

export default router;

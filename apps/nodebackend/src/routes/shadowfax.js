import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import axios from 'axios';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const router = express.Router();

// Shadowfax Config
const SHADOWFAX_BASE_URL = process.env.SHADOWFAX_API_URL;
const SHADOWFAX_TOKEN = process.env.SHADOWFAX_API_TOKEN;

/**
 * POST /api/shadowfax/create-order
 * Triggered by Vendor when they accept/start preparing an order.
 */
router.post('/create-order', async (req, res) => {
    try {
        const { orderId } = req.body;
        if (!orderId) return res.status(400).json({ error: 'Order ID is required' });

        // 1. Fetch Order Details
        const { data: order, error } = await supabaseAdmin
            .from('orders')
            .select('*, vendor:vendors(*)')
            .eq('id', orderId)
            .single();

        if (error || !order) return res.status(404).json({ error: 'Order not found' });

        // 1.5 Fetch Delivery Details for OTPs
        const { data: delivery } = await supabaseAdmin
            .from('deliveries')
            .select('*')
            .eq('order_id', orderId)
            .single();

        if (delivery?.external_order_id) {
            return res.json({
                success: true,
                shadowfax_order_id: delivery.external_order_id,
                message: 'Delivery partner already assigned'
            });
        }

        let deliveryOtp = delivery?.delivery_otp || Math.floor(1000 + Math.random() * 9000).toString();
        let pickupOtp = delivery?.pickup_otp || Math.floor(1000 + Math.random() * 9000).toString();

        // 2. Construct Shadowfax Payload
        const pickupLat = Number(order.vendor?.latitude);
        const pickupLng = Number(order.vendor?.longitude);
        const dropLat = order.delivery_address?.latitude;
        const dropLng = order.delivery_address?.longitude;

        const payload = {
            "pickup_details": {
                "name": order.vendor?.name,
                "contact_number": order.vendor?.phone,
                "address": order.vendor?.address || order.vendor?.location,
                "latitude": pickupLat,
                "longitude": pickupLng
            },
            "drop_details": {
                "name": order.delivery_address?.name,
                "contact_number": order.delivery_phone,
                "address": order.delivery_address?.address,
                "latitude": dropLat,
                "longitude": dropLng
            },
            "order_details": {
                "order_id": order.order_number,
                "is_prepaid": true,
                "cash_to_be_collected": 0,
                "rts_required": true
            },
            "validations": {
                "pickup": { "is_otp_required": true, "otp": pickupOtp },
                "drop": { "is_otp_required": true, "otp": deliveryOtp }
            }
        };

        const sfResponse = await axios.post(`${SHADOWFAX_BASE_URL}/order/create/`, payload, {
            headers: { 'Authorization': SHADOWFAX_TOKEN, 'Content-Type': 'application/json' }
        });

        if (sfResponse.data.order_id) {
            const initialHistory = [{
                status: 'searching_rider',
                timestamp: new Date().toISOString(),
                note: 'Order Created via API'
            }];

            await supabaseAdmin.from('deliveries').update({
                external_order_id: sfResponse.data.order_id,
                status: 'searching_rider',
                pickup_otp: pickupOtp,
                delivery_otp: deliveryOtp,
                history: initialHistory,
                updated_at: new Date().toISOString()
            }).eq('order_id', orderId);

            return res.json({ success: true, shadowfax_order_id: sfResponse.data.order_id });
        }
        res.status(400).json({ error: 'Failed' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});


/**
 * POST /api/shadowfax/webhook
 */
/*
router.post('/webhook', async (req, res) => {
    try {
        const data = req.body;
        const clientOrderId = data.coid;
        const sfOrderId = data.sfx_order_id;
        const status = data.status;

        const logFile = path.resolve('shadowfax_debug.log');
        fs.appendFileSync(logFile, `\n📥 [Webhook Debug] ${status} for ${clientOrderId || sfOrderId}\n`);

        if (!clientOrderId && !sfOrderId) return res.status(200).send('OK');

        // 1. Fetch Order
        let query = supabaseAdmin.from('orders');
        if (clientOrderId) query = query.select('*, vendor:vendors(*)').eq('order_number', clientOrderId);
        else query = query.select('*, vendor:vendors(*)').eq('shadowfax_id', sfOrderId);

        const { data: existingOrder } = await query.single();
        if (!existingOrder) return res.status(200).send('OK (Not found)');

        // 2. Map Status
        const orderPayload = {};
        let internalStatus = status.toLowerCase();

        if (status === 'ARRIVED') internalStatus = 'reached_location';
        else if (status === 'COLLECTED') internalStatus = 'picked_up';
        else if (status === 'CUSTOMER_DOOR_STEP') internalStatus = 'arrived_at_drop';
        else if (status === 'ACCEPTED') {
            internalStatus = 'accepted';
            orderPayload.status = 'confirmed';
        } else if (status === 'DELIVERED') {
            internalStatus = 'delivered';
            orderPayload.status = 'completed';
        } else if (status === 'CANCELLED') {
            internalStatus = 'cancelled';
            orderPayload.status = 'cancelled';
        }

        if (status === 'COLLECTED') {
            orderPayload.status = 'on_way';
        }

        // 3. Update Order
        let updatedOrder = existingOrder;
        if (Object.keys(orderPayload).length > 0) {
            const { data: up } = await supabaseAdmin.from('orders').update(orderPayload).eq('id', existingOrder.id).select('*, vendor:vendors(*)').single();
            if (up) updatedOrder = up;
        }

        // 4. Update Delivery
        const deliveryPayload = {
            status: internalStatus,
            rider_name: data.rider_name || null,
            rider_phone: data.rider_contact_number || null,
            rider_latitude: data.rider_latitude ? parseFloat(data.rider_latitude) : null,
            rider_longitude: data.rider_longitude ? parseFloat(data.rider_longitude) : null,
            updated_at: new Date().toISOString()
        };

        if (status === 'ACCEPTED' && data.rider_name) {
            deliveryPayload.rider_details = {
                rider_name: data.rider_name,
                rider_phone: data.rider_contact_number,
                assigned_at: new Date().toISOString()
            };
        }

        const { data: currDel } = await supabaseAdmin.from('deliveries').select('history, pickup_otp, delivery_otp').eq('order_id', updatedOrder.id).single();
        const history = [...(currDel?.history || []), { status: internalStatus, timestamp: new Date().toISOString(), note: `Update: ${status}` }];
        deliveryPayload.history = history;

        await supabaseAdmin.from('deliveries').update(deliveryPayload).eq('order_id', updatedOrder.id);

        // 5. Broadcast
        const channel = supabaseAdmin.channel('delivery-updates');
        channel.subscribe((subStatus) => {
            if (subStatus === 'SUBSCRIBED') {
                channel.send({
                    type: 'broadcast',
                    event: 'status-update',
                    payload: {
                        order_id: updatedOrder.id,
                        order_number: updatedOrder.order_number,
                        status: status,
                        internal_status: internalStatus,
                        rider_details: deliveryPayload.rider_details || null,
                        pickup_otp: currDel?.pickup_otp,
                        delivery_otp: currDel?.delivery_otp
                    }
                });
            }
        });

        // 6. Notifications
        if (status === 'ACCEPTED') {
            import('../utils/pushService.js').then(({ sendVendorPush }) => {
                sendVendorPush(updatedOrder.vendor_id, 'New Order!', `Rider assigned for #${updatedOrder.order_number}`);
            });
        }

        res.json({ received: true });
    } catch (err) {
        console.error('Webhook Error:', err);
        res.status(500).send('Error');
    }
});
*/

router.post('/mock-create-order', async (req, res) => {
    try {
        const { orderId } = req.body;
        const { data: order } = await supabaseAdmin.from('orders').select('*').eq('id', orderId).single();
        const mockSfId = `SFX_MOCK_${Date.now()}`;
        await supabaseAdmin.from('deliveries').upsert({
            order_id: orderId,
            external_order_id: mockSfId,
            status: 'searching_rider',
            pickup_otp: '1234',
            delivery_otp: '5678',
            history: [{ status: 'searching_rider', timestamp: new Date().toISOString() }],
            updated_at: new Date().toISOString()
        }, { onConflict: 'order_id' });
        await supabaseAdmin.from('orders').update({ status: 'searching_rider' }).eq('id', orderId);
        res.json({ success: true, sf_id: mockSfId });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

export default router;

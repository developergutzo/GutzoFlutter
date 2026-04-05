import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3002;
const DATA_FILE = path.join(__dirname, 'orders.json');

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// In-Memory Storage (Synced with File)
let orders = new Map();

// Helper: Load Data
const loadData = () => {
    try {
        if (fs.existsSync(DATA_FILE)) {
            const data = fs.readFileSync(DATA_FILE, 'utf8');
            const json = JSON.parse(data);
            orders = new Map(json);
            console.log(`📂 [Mock Shadowfax] Loaded ${orders.size} orders from disk.`);
        }
    } catch (e) {
        console.error('❌ [Mock Shadowfax] Failed to load data:', e);
    }
};

// Helper: Save Data
const saveData = () => {
    try {
        const json = JSON.stringify(Array.from(orders.entries()), null, 2);
        fs.writeFileSync(DATA_FILE, json);
        // console.log('DISK_SAVE_SUCCESS');
    } catch (e) {
        console.error('❌ [Mock Shadowfax] Failed to save data:', e);
    }
};

// Helper: Send Webhook
const sendWebhook = async (order) => {
    const WEBHOOK_URL = 'http://localhost:5000/api/shadowfax/webhook';
    try {
        const payload = {
            coid: order.client_order_id,
            sfx_order_id: order.shadowfax_id,
            status: order.status,
            action_time: new Date().toISOString(),
            rider_id: 101,
            rider_name: order.rider_details?.name || 'Mock Rider',
            rider_contact_number: order.rider_details?.contact_number || '9999999999',
            rider_latitude: order.rider_details?.latitude,
            rider_longitude: order.rider_details?.longitude,
            cancel_reason: order.cancellation_reason,
            cancelled_by: order.cancelled_by || 'sfx'
        };

        console.log(`📡 [Mock Shadowfax] Sending Webhook: ${order.status} -> ${WEBHOOK_URL}`);

        fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        }).catch(err => console.error("Webhook Fetch Error:", err.message));

    } catch (e) {
        console.error('❌ [Mock Shadowfax] Webhook Setup Failed:', e);
    }
};

// Load on start
loadData();

// Helper: Generate Mock Shadowfax ID
const generateShadowfaxId = () => `SFX_MOCK_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

// Helper: Get current timestamp
const timestamp = () => new Date().toISOString();

// ============================================
// MOCK SHADOWFAX API ENDPOINTS
// ============================================

/**
 * POST /order/create/
 * Mimics Shadowfax order creation
 */
app.post('/order/create/', (req, res) => {
    try {
        const payload = req.body;
        const orderId = payload.order_details?.order_id;

        if (!orderId) {
            return res.status(400).json({
                status: 'FAILED',
                message: 'order_id is required'
            });
        }

        const shadowfaxId = generateShadowfaxId();

        // Store order in memory
        const order = {
            shadowfax_id: shadowfaxId,
            client_order_id: orderId,
            status: 'CREATED',
            awb_number: shadowfaxId,
            created_at: timestamp(),
            updated_at: timestamp(),
            pickup_details: payload.pickup_details,
            drop_details: payload.drop_details,
            order_details: payload.order_details,
            validations: payload.validations,
            rider_details: null,
            history: [{
                status: 'CREATED',
                timestamp: timestamp(),
                note: 'Order created via Mock API'
            }]
        };

        orders.set(shadowfaxId, order);
        saveData();

        console.log(`✅ [Mock Shadowfax] Order Created: ${shadowfaxId} (Client: ${orderId})`);

        res.json({
            is_order_created: true,
            message: 'Order created successfully',
            flash_order_id: shadowfaxId,
            pickup_otp: payload.validations?.pickup?.otp || '1234',
            drop_otp: payload.validations?.drop?.otp || '5678',
            total_amount: 50,
            rain_rider_incentive: 0,
            high_demand_surge: 0
        });

    } catch (error) {
        console.error('❌ [Mock Shadowfax] Create Error:', error);
        res.status(500).json({
            status: 'FAILED',
            message: error.message
        });
    }
});

/**
 * GET /order/track/:orderId/
 * Mimics Shadowfax order tracking
 */
app.get('/order/track/:orderId/', (req, res) => {
    try {
        const { orderId } = req.params;
        let order = orders.get(orderId);

        // If not found by ID, try finding by client_order_id
        if (!order) {
            for (const o of orders.values()) {
                if (o.client_order_id === orderId) {
                    order = o;
                    break;
                }
            }
        }

        if (!order) {
            return res.status(404).json({
                status: 'FAILED',
                message: 'Order not found'
            });
        }

        console.log(`📍 [Mock Shadowfax] Tracking: ${orderId} - Status: ${order.status}`);

        res.json({
            status: order.status,
            awb_number: order.awb_number,
            rider_name: order.rider_details?.name || null,
            rider_contact_number: order.rider_details?.contact_number || null,
            rider_latitude: order.rider_details?.latitude || null,
            rider_longitude: order.rider_details?.longitude || null,
            tracking_url: `http://localhost:${PORT}/?order=${orderId}`
        });

    } catch (error) {
        console.error('❌ [Mock Shadowfax] Track Error:', error);
        res.status(500).json({
            status: 'FAILED',
            message: error.message
        });
    }
});

/**
 * POST /order/serviceability/
 * Check rider availability and delivery charges
 */
app.post('/order/serviceability/', (req, res) => {
    try {
        const { pickup_details, drop_details } = req.body;

        if (!pickup_details?.address || !drop_details?.address) {
            return res.status(400).json({
                message: 'pickup_details.address and drop_details.address are required',
                is_serviceable: false
            });
        }

        // Mock: Always serviceable with random delivery charge
        const baseCharge = 30 + Math.floor(Math.random() * 20);
        const rainIncentive = 0;
        const surge = 0;

        console.log(`📍 [Mock Shadowfax] Serviceability Check: ${pickup_details.address} → ${drop_details.address}`);

        res.json({
            is_serviceable: true,
            total_amount: baseCharge + rainIncentive + surge,
            rain_rider_incentive: rainIncentive,
            high_demand_surge: surge,
            total_distance: 2.5,
            message: 'We are serviceable',
            pickup_eta: '10 Mins'
        });

    } catch (error) {
        console.error('❌ [Mock Shadowfax] Serviceability Error:', error);
        res.status(500).json({
            is_serviceable: false,
            message: error.message
        });
    }
});

/**
 * POST /order/cancel/
 * Mimics Shadowfax order cancellation
 */
app.post('/order/cancel/', (req, res) => {
    try {
        const { order_id, cancellation_reason, cancelled_by } = req.body;
        const order = orders.get(order_id);

        if (!order) {
            return res.status(404).json({
                is_cancelled: false,
                message: 'Order not found'
            });
        }

        if (order.status === 'DELIVERED') {
            return res.status(400).json({
                is_cancelled: false,
                message: 'Cannot cancel delivered order'
            });
        }

        order.status = 'CANCELLED';
        order.updated_at = timestamp();
        order.cancelled_by = cancelled_by || 'sfx'; // Default to sfx if not provided
        order.cancellation_reason = cancellation_reason;

        order.history.push({
            status: 'CANCELLED',
            timestamp: timestamp(),
            note: cancellation_reason || 'Order cancelled',
            meta: { cancelled_by }
        });
        saveData();
        sendWebhook(order);

        console.log(`🚫 [Mock Shadowfax] Order Cancelled: ${order_id}`);

        res.json({
            is_cancelled: true,
            order_id: order_id,
            message: 'Order cancelled successfully'
        });

    } catch (error) {
        console.error('❌ [Mock Shadowfax] Cancel Error:', error);
        res.status(500).json({
            is_cancelled: false,
            message: error.message
        });
    }
});

// ============================================
// UI DASHBOARD API ENDPOINTS
// ============================================

/**
 * GET /api/orders
 * Get all orders for UI dashboard
 */
app.get('/api/orders', (req, res) => {
    const orderList = Array.from(orders.values()).sort((a, b) =>
        new Date(b.created_at) - new Date(a.created_at)
    );
    res.json({ orders: orderList });
});

/**
 * POST /api/orders/:orderId/update-status
 * Update order status from UI
 */
app.post('/api/orders/:orderId/update-status', (req, res) => {
    try {
        const { orderId } = req.params;
        const { status, rider_details } = req.body;

        const order = orders.get(orderId);

        if (!order) {
            return res.status(404).json({ error: 'Order not found' });
        }

        // Update status
        order.status = status;
        order.updated_at = timestamp();

        // Update rider details if provided (from request body)
        if (rider_details) {
            order.rider_details = {
                ...order.rider_details,
                ...rider_details
            };
        }

        // Simulate Rider Movement (Mock Logic)
        if (order.rider_details && order.pickup_details?.latitude && order.drop_details?.latitude) {
            const pLat = Number(order.pickup_details.latitude);
            const pLng = Number(order.pickup_details.longitude);
            const dLat = Number(order.drop_details.latitude);
            const dLng = Number(order.drop_details.longitude);

            if (['CUSTOMER_DOOR_STEP', 'DELIVERED'].includes(status)) {
                // Teleport to drop
                order.rider_details.latitude = dLat;
                order.rider_details.longitude = dLng;
            } else if (['ARRIVED'].includes(status)) {
                // Reset to pickup (Rider has arrived at store)
                order.rider_details.latitude = pLat;
                order.rider_details.longitude = pLng;
            }
        }

        // Add to history
        order.history.push({
            status: status,
            timestamp: timestamp(),
            note: `Status updated via UI to ${status}`
        });
        saveData();
        sendWebhook(order);

        console.log(`🔄 [Mock Shadowfax] Status Updated: ${orderId} → ${status}`);

        res.json({
            success: true,
            order: order
        });

    } catch (error) {
        console.error('❌ [Mock Shadowfax] Update Error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/orders/:orderId/assign-rider
 * Assign rider to order (ALLOTTED status)
 */
app.post('/api/orders/:orderId/assign-rider', (req, res) => {
    try {
        const { orderId } = req.params;
        const order = orders.get(orderId);

        if (!order) {
            return res.status(404).json({ error: 'Order not found' });
        }

        // Generate mock rider details
        const riderNames = ['Rajesh Kumar', 'Amit Singh', 'Priya Sharma', 'Vikram Patel'];
        const randomName = riderNames[Math.floor(Math.random() * riderNames.length)];

        order.status = 'ACCEPTED';
        order.updated_at = timestamp();
        order.rider_details = {
            name: randomName,
            contact_number: `+91${Math.floor(7000000000 + Math.random() * 3000000000)}`,
            latitude: order.rider_details?.latitude || order.pickup_details?.latitude || 12.9716,
            longitude: order.rider_details?.longitude || order.pickup_details?.longitude || 77.5946
        };

        order.history.push({
            status: 'ACCEPTED',
            timestamp: timestamp(),
            note: `Order accepted by rider ${randomName}`
        });
        saveData();
        sendWebhook(order);

        console.log(`👤 [Mock Shadowfax] Order Accepted: ${orderId} by ${randomName}`);

        res.json({
            success: true,
            order: order
        });

    } catch (error) {
        console.error('❌ [Mock Shadowfax] Assign Rider Error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/orders/:orderId/update-location
 * Manually update rider coordinates
 */
app.post('/api/orders/:orderId/update-location', (req, res) => {
    const { orderId } = req.params;
    const { latitude, longitude } = req.body;

    console.log(`📍 Request Update Location: ${orderId} -> ${latitude}, ${longitude}`);

    const order = orders.get(orderId);

    if (!order) {
        console.error(`❌ Order not found: ${orderId}`);
        return res.status(404).json({ success: false, message: 'Order not found' });
    }

    if (!order.rider_details) order.rider_details = {};

    // Update coordinates
    order.rider_details.latitude = parseFloat(latitude);
    order.rider_details.longitude = parseFloat(longitude);

    // Also update common nested structure if present
    order.rider_details.current_location = {
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude)
    };

    saveData();
    res.json({ success: true, message: 'Location updated' });
    console.log(`📍 [Mock Shadowfax] Location Updated: ${orderId} -> ${latitude}, ${longitude}`);
});

// ============================================
/*
// AUTOMATIC RIDER MOVEMENT LOOP
// ============================================

// Move riders every 3 seconds
setInterval(() => {
    let updatedCount = 0;

    orders.forEach((order) => {
        // Only move if status is COLLECTED (Picked Up)
        if (order.status !== 'COLLECTED') return;

        // Ensure we have valid coordinates
        if (!order.rider_details?.latitude || !order.drop_details?.latitude) return;

        const currentLat = Number(order.rider_details.latitude);
        const currentLng = Number(order.rider_details.longitude);
        const targetLat = Number(order.drop_details.latitude);
        const targetLng = Number(order.drop_details.longitude);

        // Calculate distance to target (roughly)
        const diffLat = targetLat - currentLat;
        const diffLng = targetLng - currentLng;
        const distanceSq = diffLat * diffLat + diffLng * diffLng;

        // If very close (threshold approx 10 meters in degrees), stop or snap
        if (distanceSq < 0.0000001) {
            return;
        }

        // Move 10% of the remaining distance per tick (Eases out as it gets closer)
        // Minimum step size to ensure arrival
        const easeFactor = 0.1;

        const newLat = currentLat + (diffLat * easeFactor);
        const newLng = currentLng + (diffLng * easeFactor);

        // Update Order
        order.rider_details.latitude = newLat;
        order.rider_details.longitude = newLng;

        // Also update nested current_location if exists (some schemas use it)
        if (order.rider_details.current_location) {
            order.rider_details.current_location = {
                latitude: newLat,
                longitude: newLng
            };
        }

        order.updated_at = timestamp();
        updatedCount++;

        // Send Webhook Update
        sendWebhook(order);
    });

    if (updatedCount > 0) {
        saveData(); // Persist changes
        console.log(`🚚 [AutoMove] Moved ${updatedCount} riders towards destination.`);
    }

}, 3000);
*/

// ============================================
// SERVER START
// ============================================

app.listen(PORT, () => {
    console.log(`
╔═══════════════════════════════════════════════╗
║   🚚  MOCK SHADOWFAX API & DASHBOARD  🚚      ║
╠═══════════════════════════════════════════════╣
║  Port:        ${PORT}                              ║
║  Dashboard:   http://localhost:${PORT}/           ║
║  API:         http://localhost:${PORT}/order/...  ║
╚═══════════════════════════════════════════════╝
    `);
});

export default app;

import fetch from 'node-fetch';

const SHADOWFAX_REAL_URL = process.env.SHADOWFAX_API_URL;

const SHADOWFAX_API_TOKEN = process.env.SHADOWFAX_API_TOKEN || "mock_token";

export const createShadowfaxOrder = async (order, vendor, otps = {}) => {
    // Determine API URL based on order's mock flag (from CheckoutPage's devEnvironment)
    const isMock = order.mock_shadowfax || (order.special_instructions && order.special_instructions.includes('[MOCK_SFX]'));
    const SHADOWFAX_API_URL = isMock ? "http://localhost:3002" : SHADOWFAX_REAL_URL;
 
    if (!SHADOWFAX_API_TOKEN && !isMock) {
        console.warn("⚠️ SHADOWFAX_API_TOKEN missing. Skipping delivery creation.");
        return { success: false, error: "SHADOWFAX_TOKEN_MISSING" };
    }

    // Map Order to Shadowfax Payload
    const isPrepaid = order.payment_status === 'paid' || order.payment_status === 'success';

    // Ensure Lat/Long are valid (not 0)
    const pickupLat = Number(vendor.latitude);
    const pickupLng = Number(vendor.longitude);
    const dropLat = Number(order.delivery_address.latitude);
    const dropLng = Number(order.delivery_address.longitude);

    // Debug Address Data
    console.log("📦 Delivery Address Data:", JSON.stringify(order.delivery_address, null, 2));

    const buildAddressString = (addr, lat, lng) => {
        // 1. Try pre-formatted full address
        if (addr.full_address && addr.full_address.trim()) return addr.full_address;
        if (addr.address && addr.address.trim()) return addr.address;

        // 2. Try to construct from components
        const parts = [
            addr.house_no || addr.house_number || addr.flat,
            addr.street || addr.road,
            addr.landmark,
            addr.area || addr.locality,
            addr.city,
            addr.state,
            addr.pincode || addr.zipcode
        ].filter(p => p && String(p).trim());

        if (parts.length > 0) return parts.join(", ");

        // 3. If ABSOLUTELY no text but we have coordinates, use them as the "address"
        // This is actual data, not a fake fallback like "Bengaluru"
        if (lat && lng) return `Location: ${lat}, ${lng}`;

        return ""; // Will fail validation if empty, which is correct
    };

    const dropAddress = buildAddressString(order.delivery_address, dropLat, dropLng);

    // Use passed OTPs or Generate 4-digit OTPs
    const pickupOtp = otps.pickup_otp || Math.floor(1000 + Math.random() * 9000).toString();
    const deliveryOtp = otps.delivery_otp || Math.floor(1000 + Math.random() * 9000).toString();

    const payload = {
        order_details: {
            order_id: order.order_number,
            actual_order_value: Number(order.total_amount),
            paid: isPrepaid,
            is_prepaid: isPrepaid,
            cash_to_be_collected: isPrepaid ? 0 : Number(order.total_amount),
            payment_mode: isPrepaid ? 'prepaid' : 'cod',
            delivery_charge_to_be_collected_from_customer: 0
        },
        pickup_details: {
            name: vendor.name,
            contact_number: vendor.phone,
            address: buildAddressString(vendor, pickupLat, pickupLng),
            city: vendor.city,
            state: vendor.state,
            ...(pickupLat && pickupLng ? { latitude: pickupLat, longitude: pickupLng } : {})
        },
        drop_details: {
            name: order.delivery_address.name,
            contact_number: order.delivery_phone,
            address: dropAddress,
            city: order.delivery_address.city,
            state: order.delivery_address.state,
            ...(dropLat && dropLng ? { latitude: dropLat, longitude: dropLng } : {})
        },
        user_details: {
            name: "Gutzo",
            contact_number: process.env.SHADOWFAX_CONTACT_NUMBER, // Use env or throw if missing
            credits_key: process.env.SHADOWFAX_CREDITS_KEY
        },
        communications: {
            send_sms_to_pickup_person: true,
            send_sms_to_drop_person: true,
            send_rts_sms_to_pickup_person: true
        },
        validations: {
            pickup: {
                is_otp_required: true,
                otp: pickupOtp
            },
            drop: {
                is_otp_required: true,
                otp: deliveryOtp
            }
        }
    };

    //console.log("🚚 Sending Shadowfax Payload:", JSON.stringify(payload, null, 2));


    try {
        // LOGGING TO FILE FOR DEBUGGING
        const fs = await import('fs');
        const path = await import('path');
        const logFile = path.resolve('shadowfax_debug.log');
        const logMsg = `\n[${new Date().toISOString()}] Creating Order: ${order.order_number}\nPayload: ${JSON.stringify(payload)}\n`;
        fs.appendFileSync(logFile, logMsg);

        const response = await fetch(`${SHADOWFAX_API_URL}/order/create/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': SHADOWFAX_API_TOKEN
            },
            body: JSON.stringify(payload)
        });

        const data = await response.json();

        // LOG RESPONSE
        fs.appendFileSync(logFile, `Response Status: ${response.status}\nResponse Data: ${JSON.stringify(data)}\n`);

        if (!response.ok) {
            console.error("Shadowfax Order Failed:", data);
            return { success: false, error: data.message || "Failed to create delivery order", details: data };
        }

        // Return Shadowfax ID + Generated OTPs
        return {
            success: true,
            data: {
                ...data,
                generated_pickup_otp: pickupOtp,
                generated_delivery_otp: deliveryOtp
            }
        };
    } catch (e) {
        // LOG ERROR
        const fs = await import('fs');
        const path = await import('path');
        const logFile = path.resolve('shadowfax_debug.log');
        fs.appendFileSync(logFile, `ERROR: ${e.message}\n${e.stack}\n`);

        console.error("Shadowfax Integration Error:", e);
        return { success: false, error: e.message };
    }
};

export const trackShadowfaxOrder = async (flashOrderId, isMock = false) => {
    const SHADOWFAX_API_URL = isMock ? "http://localhost:3002" : SHADOWFAX_REAL_URL;
    if (!SHADOWFAX_API_TOKEN || !flashOrderId) return null;

    try {
        const response = await fetch(`${SHADOWFAX_API_URL}/order/track/${flashOrderId}/`, {
            method: 'GET',
            headers: {
                'Authorization': SHADOWFAX_API_TOKEN
            }
        });

        const data = await response.json();

        if (!response.ok) {
            console.error(`❌ Tracking Failed [${response.status}]:`, JSON.stringify(data));
            return null;
        }

        const trackingData = {
            status: data.status,
            awb_number: data.awb_number || flashOrderId,
            rider_details: {
                name: data.rider_name,
                contact_number: data.rider_contact_number,
                current_location: {
                    lat: data.rider_latitude,
                    lng: data.rider_longitude
                }
            },
            tracking_url: data.tracking_url
        };

        // Conditional Logging per user request
        const activeStatuses = ['ACCEPTED', 'ALLOTTED', 'PICKED_UP', 'DELIVERED', 'REACHED_LOCATION', 'ARRIVED_AT_DROP'];
        if (data.status && activeStatuses.includes(data.status.toUpperCase())) {
            console.log(`🚴 Shadowfax Live Tracking for ${flashOrderId} [${data.status}]:`, JSON.stringify(data, null, 2));
            console.log(`📍 Rider Location: lat=${data.rider_latitude}, lng=${data.rider_longitude}`);
        }

        return trackingData;
    } catch (e) {
        console.error("Shadowfax Tracking Error:", e);
        return null;
    }
};

export const cancelShadowfaxOrder = async (flashOrderId, reason = "Vendor Rejected", isMock = false) => {
    const SHADOWFAX_API_URL = isMock ? "http://localhost:3002" : SHADOWFAX_REAL_URL;
    if (!SHADOWFAX_API_TOKEN || !flashOrderId) return null;

    const payload = {
        order_id: flashOrderId,
        cancellation_reason: reason
    };

    console.log("🚚 Cancelling Shadowfax Order:", JSON.stringify(payload, null, 2));

    try {
        // Try standard cancel endpoint
        const response = await fetch(`${SHADOWFAX_API_URL}/order/cancel/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': SHADOWFAX_API_TOKEN
            },
            body: JSON.stringify(payload)
        });

        const data = await response.json();

        if (!response.ok || !data.is_cancelled) {
            console.error(`❌ Shadowfax Cancel Failed [${response.status}]:`, JSON.stringify(data));
            return { success: false, error: data.message || "Cancellation failed" };
        }

        console.log("✅ Shadowfax Cancel Success:", data);
        return { success: true, data };

    } catch (e) {
        console.error("Shadowfax Cancellation Error:", e);
        return { success: false, error: e.message };
    }
};

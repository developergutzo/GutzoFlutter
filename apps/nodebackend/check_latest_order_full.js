
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function checkLatestOrder() {
    console.log("🔍 Checking Latest Order for Shadowfax Readiness...\n");

    // 1. Get Latest Order
    const { data: order, error: orderError } = await supabase
        .from('orders')
        .select('*, vendor:vendors(*)')
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

    if (orderError) {
        console.error("❌ Failed to fetch order:", orderError.message);
        return;
    }

    console.log(`📦 LATEST ORDER: ${order.order_number} (ID: ${order.id})`);
    console.log(`   Status: ${order.status}`);
    console.log(`   Payment: ${order.payment_status} (${order.payment_method})`);
    console.log(`   Created At: ${new Date(order.created_at).toLocaleString()}`);

    // 2. Validate Drop Details
    let dropAddress = order.delivery_address;
    if (typeof dropAddress === 'string') {
        try { dropAddress = JSON.parse(dropAddress); } catch (e) { }
    }

    console.log("\n📍 DROP DETAILS (Customer):");
    if (!dropAddress) {
        console.error("   ❌ MISSING: delivery_address is null!");
    } else {
        console.log(`   Name: ${dropAddress.name || 'N/A'}`);
        console.log(`   Address: ${dropAddress.address || dropAddress.full_address || 'N/A'}`);
        console.log(`   Coordinates: ${dropAddress.latitude}, ${dropAddress.longitude}`);
        if (!dropAddress.latitude || !dropAddress.longitude) console.warn("   ⚠️ WARNING: Drop coordinates missing/invalid!");
    }
    console.log(`   Phone: ${order.delivery_phone || 'N/A'}`);

    // 3. Validate Pickup Details (Vendor)
    console.log("\n🏪 PICKUP DETAILS (Vendor):");
    const vendor = order.vendor;
    if (!vendor) {
        console.error("   ❌ MISSING: Vendor record not linked!");
    } else {
        console.log(`   Name: ${vendor.name}`);
        console.log(`   Address: ${vendor.address}`);
        console.log(`   Phone: ${vendor.phone}`);
        console.log(`   Coordinates: ${vendor.latitude}, ${vendor.longitude}`);
        if (!vendor.latitude || !vendor.longitude) console.error("   ❌ CRITICAL: Vendor coordinates missing! Shadowfax cannot pick up.");
    }

    // 4. Check Delivery Record
    console.log("\n🚚 DELIVERY RECORD (Internal):");
    const { data: delivery, error: delError } = await supabase
        .from('deliveries')
        .select('*')
        .eq('order_id', order.id)
        .single();

    if (delError || !delivery) {
        console.error("   ❌ MISSING: No entry in 'deliveries' table!");
        console.log("      (This means the backend delivery creation logic failed)");
    } else {
        console.log(`   Status: ${delivery.status}`);
        console.log(`   Partner: ${delivery.partner_id}`);
        console.log(`   External ID (Shadowfax): ${delivery.external_order_id || 'PENDING'}`);
        console.log(`   OTPs: Pickup=${delivery.pickup_otp || 'MISSING'}, Drop=${delivery.delivery_otp || 'MISSING'}`);

        if (delivery.status === 'searching_rider' && !delivery.external_order_id) {
            console.warn("   ⚠️ PENDING: Order is searching but has no External ID yet.");
        }
    }

    console.log("\n✅ DIAGNOSIS COMPLETE");
}

checkLatestOrder();

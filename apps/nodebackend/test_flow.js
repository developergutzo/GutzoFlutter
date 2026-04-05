
import { supabaseAdmin } from './src/config/supabase.js';
import { createShadowfaxOrder } from './src/utils/shadowfax.js';
import fetch from 'node-fetch';
import PaytmChecksum from './src/utils/paytmChecksum.js';
import dotenv from 'dotenv';
dotenv.config();

const BASE_URL = 'http://localhost:5000/api/payments';
const PAYTM_MERCHANT_KEY = process.env.PAYTM_MERCHANT_KEY;
const PAYTM_MID = process.env.PAYTM_MID;

async function simulateWebhook(orderId, amount) {
    console.log(`\n📡 Sending Webhook for ${orderId}...`);
    const payload = {
        MID: PAYTM_MID,
        ORDERID: orderId,
        TXNAMOUNT: amount,
        CURRENCY: 'INR',
        TXNID: 'TXN_' + Date.now(),
        BANKTXNID: 'BANK_' + Date.now(),
        STATUS: 'TXN_SUCCESS',
        RESPCODE: '01',
        RESPMSG: 'Txn Success',
        TXNDATE: new Date().toISOString(),
        GATEWAYNAME: 'WALLET',
        BANKNAME: 'WALLET',
        PAYMENTMODE: 'PPI'
    };

    const checksum = await PaytmChecksum.generateSignature(payload, PAYTM_MERCHANT_KEY);
    payload.CHECKSUMHASH = checksum;

    const params = new URLSearchParams(payload);
    try {
        const response = await fetch(`${BASE_URL}/webhook`, {
            method: 'POST',
            body: params
        });
        console.log(`   Response: ${response.status} ${await response.text()}`);
    } catch (e) {
        console.error("   Webhook Failed:", e.message);
    }
}

async function runTest() {
    console.log("🛠️  Starting Order Flow Test...");

    // 1. Get Pre-requisites
    const { data: user } = await supabaseAdmin.from('users').select('id').limit(1).single();
    const { data: vendor } = await supabaseAdmin.from('vendors').select('*').limit(1).single();

    if (!user || !vendor) {
        console.error("❌ Need at least one user and vendor in DB.");
        process.exit(1);
    }

    // ============================================
    // TEST CASE 1: Shadowfax Accepts
    // ============================================
    const orderIdSuccess = 'TEST_SUCCESS_' + Date.now();
    console.log(`\n🧪 TEST CASE 1: Expect Shadowfax Success (${orderIdSuccess})`);
    
    // Create Order
    const { data: order1, error: err1 } = await supabaseAdmin.from('orders').insert({
        order_number: orderIdSuccess,
        user_id: user.id,
        vendor_id: vendor.id,
        total_amount: 100,
        subtotal: 90,
        payment_status: 'pending',
        status: 'pending',
        delivery_address: JSON.stringify({ address: "Test St", city: "Coimbatore" })
    }).select().single();

    if (err1) { console.error("   ❌ Order Creation Failed:", err1); return; }

    // Create Payment Record (Required for Webhook logic sometimes, but our code checks Order mostly, but updates Payment)
    await supabaseAdmin.from('payments').insert({
        merchant_order_id: orderIdSuccess,
        amount: 100,
        status: 'pending', 
        user_id: user.id
    });

    // Simulate Payment Success
    await simulateWebhook(orderIdSuccess, '100.00');

    // Verify
    await new Promise(r => setTimeout(r, 2000)); // Wait for async async handling
    const { data: delivery1 } = await supabaseAdmin.from('deliveries').select('*').eq('order_id', order1.id).single();
    const { data: updatedOrder1 } = await supabaseAdmin.from('orders').select('*').eq('id', order1.id).single();

    if (delivery1 && delivery1.partner_id === 'shadowfax' && delivery1.status === 'searching_rider') {
        console.log("   ✅ SUCCESS: Delivery record created.");
    } else {
        console.error("   ❌ FAILURE: Delivery record missing or incorrect.", delivery1);
    }

    if (updatedOrder1.status === 'paid' || updatedOrder1.status === 'confirmed') {
         // My code sets logic: if payment success -> orderStatus = 'paid'. 
         // Then if accepted -> it stays 'paid' or specific status? 
         // My code: status: orderStatus (which is 'paid').
         console.log("   ✅ SUCCESS: Order status is 'paid'.");
    } else {
         console.log(`   ⚠️  Order status is '${updatedOrder1.status}' (Expected 'paid')`);
    }


    // ============================================
    // TEST CASE 2: Shadowfax Rejects
    // ============================================
    const orderIdFail = 'TEST_FAIL_' + Date.now();
    console.log(`\n🧪 TEST CASE 2: Expect Shadowfax Failure (${orderIdFail})`);

    const { data: order2 } = await supabaseAdmin.from('orders').insert({
        order_number: orderIdFail,
        user_id: user.id,
        vendor_id: vendor.id,
        total_amount: 100,
        subtotal: 90,
        payment_status: 'pending',
        status: 'pending',
        delivery_address: JSON.stringify({ address: "Test St", city: "Coimbatore" })
    }).select().single();

    await supabaseAdmin.from('payments').insert({
        merchant_order_id: orderIdFail,
        amount: 100,
        status: 'pending',
        user_id: user.id
    });

    await simulateWebhook(orderIdFail, '100.00');

    await new Promise(r => setTimeout(r, 2000));
    const { data: updatedOrder2 } = await supabaseAdmin.from('orders').select('*').eq('id', order2.id).single();

    if (updatedOrder2.status === 'cancelled') {
        console.log("   ✅ SUCCESS: Order was auto-cancelled.");
    } else {
        console.error(`   ❌ FAILURE: Order status is '${updatedOrder2.status}' (Expected 'cancelled')`);
    }
    
    console.log("\nDone.");
    process.exit(0);
}

runTest();

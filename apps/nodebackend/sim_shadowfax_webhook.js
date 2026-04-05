import fetch from 'node-fetch';

const WEBHOOK_URL = 'http://localhost:3000/api/shadowfax/webhook';

// Usage: node sim_shadowfax_webhook.js <SHADOWFAX_ORDER_ID> [STATUS]
// Example: node sim_shadowfax_webhook.js 21027232 ALLOTTED

const sfOrderId = process.argv[2];
const status = process.argv[3] || 'ALLOTTED';

if (!sfOrderId) {
    console.error("Usage: node sim_shadowfax_webhook.js <ORDER_ID_OR_COID> [STATUS]");
    process.exit(1);
}

// Detect if it's a Client Order ID (starts with GZ)
const isClientID = sfOrderId.startsWith('GZ');

const payload = {
    // If GZ ID, send as 'coid'. If numeric, send as 'order_id'
    ...(isClientID ? { coid: sfOrderId } : { order_id: sfOrderId }),
    status: status,
    // Rider Details (Flat fields as per user schema)
    rider_name: "Simulated Rider (COID Test)",
    rider_contact_number: "9876543210", 
    rider_latitude: 12.9716,
    rider_longitude: 77.5946,
    pickup_otp: "1234",
    delivery_otp: "5678",
    // Timestamps
    timestamp: new Date().toISOString()
};

console.log(`🚀 Simulating Shadowfax Webhook: ${status} for ID: ${sfOrderId}`);
console.log(`URL: ${WEBHOOK_URL}`);
console.log(`Payload:`, JSON.stringify(payload, null, 2));

fetch(WEBHOOK_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
})
.then(async res => {
    const txt = await res.text();
    console.log(`\n✅ Response [${res.status}]:`, txt);
})
.catch(err => {
    console.error("\n❌ Error:", err.message);
});

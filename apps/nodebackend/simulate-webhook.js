import PaytmChecksum from './src/utils/paytmChecksum.js';
import dotenv from 'dotenv';
import fetch from 'node-fetch'; // Ensure node-fetch is available (or use global fetch in Node 18+)

dotenv.config();

const PAYTM_MERCHANT_KEY = process.env.PAYTM_MERCHANT_KEY;
const PAYTM_MID = process.env.PAYTM_MID;
const BASE_URL = 'http://localhost:5000/api/payments';

async function simulateWebhook(type = 'payment', status = 'TXN_SUCCESS', amount = '100.00', customOrderId = null) {
  console.log(`\n🚀 Simulating ${type.toUpperCase()} Webhook with status: ${status}...`);

  const orderId = customOrderId || 'TEST_ORDER_' + Date.now();
  
  let payload = {
    MID: PAYTM_MID,
    ORDERID: orderId,
    TXNAMOUNT: amount,
    CURRENCY: 'INR',
    TXNID: 'TXN_' + Date.now(),
    BANKTXNID: 'BANK_' + Date.now(),
    STATUS: status,
    RESPCODE: status === 'TXN_SUCCESS' ? '01' : '227',
    RESPMSG: status === 'TXN_SUCCESS' ? 'Txn Success' : 'Txn Failed',
    TXNDATE: new Date().toISOString(),
    GATEWAYNAME: 'WALLET',
    BANKNAME: 'WALLET',
    PAYMENTMODE: 'PPI'
  };

  if (type === 'refund') {
    payload = {
      ...payload,
      REFID: 'REF_' + Date.now(),
      REFUNDAMOUNT: amount,
      TOTALREFUNDAMT: amount
      // Paytm refund webhooks structure varies but typically includes these
    };
  }

  try {
    // Generate Checksum
    const checksum = await PaytmChecksum.generateSignature(payload, PAYTM_MERCHANT_KEY);
    payload.CHECKSUMHASH = checksum;

    // Send Request
    const endpoint = type === 'refund' ? '/webhook/refund' : '/webhook';
    console.log(`POSTing to ${BASE_URL}${endpoint}`);
    
    // Simulate urlencoded form data as Paytm sends
    const params = new URLSearchParams(payload);

    const response = await fetch(`${BASE_URL}${endpoint}`, {
      method: 'POST',
      body: params
    });

    const text = await response.text();
    console.log(`Example Payload:`, payload);
    console.log(`Response: [${response.status}] ${text}`);

  } catch (error) {
    console.error('Error simulating webhook:', error);
  }
}

// Run scenarios
async function runTests() {
  // 1. Payment Success (Random Order - will likely return ORDER_NOT_FOUND if not in DB)
  await simulateWebhook('payment', 'TXN_SUCCESS', '100.00');

  // 2. Refund Success
  await simulateWebhook('refund', 'TXN_SUCCESS', '50.00');
}

// Check for arguments to run specific tests or all
// Usage: node simulate-webhook.js [orderId]
const args = process.argv.slice(2);
if (args.length > 0) {
    // If order ID provided, try to confirm that specific order
    simulateWebhook('payment', 'TXN_SUCCESS', '100.00', args[0]);
} else {
    runTests();
}

import PaytmChecksum from './src/utils/paytmChecksum.js';
// import fetch from 'node-fetch'; // Native fetch used in Node 18+
import dotenv from 'dotenv';

dotenv.config();

const PAYTM_MERCHANT_KEY = process.env.PAYTM_MERCHANT_KEY;

async function testCallback() {
  console.log('🧪 Starting Local Callback Test...');

  // 1. Mock Data (Simulating a successful payment)
  // NOTE: You must have an order with this ID in your DB or the update will technically "fail" to find records, 
  // but the route logic (checksum & redirect) will still run.
  // Ideally, create a dummy order first if you want full DB verification.
  const mockParams = {
    MID: process.env.PAYTM_MID,
    ORDERID: 'TEST_ORDER_' + Date.now(),
    TXNAMOUNT: '1.00',
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

  try {
    // 2. Generate Valid Checksum locally
    const checksum = await PaytmChecksum.generateSignature(mockParams, PAYTM_MERCHANT_KEY);
    mockParams.CHECKSUMHASH = checksum;
    delete mockParams.checksumhash; // specific key cleanup if needed

    console.log('🔑 Generated Valid Checksum:', checksum);

    // 3. Send POST request to your callback URL
    // We use URLSearchParams to send as application/x-www-form-urlencoded
    const params = new URLSearchParams(mockParams);

    // Use env var or default to localhost
    const API_BASE_URL = process.env.API_BASE_URL;
    console.log(`📡 Sending callback to: ${API_BASE_URL}/api/payments/callback`);

    const response = await fetch(`${API_BASE_URL}/api/payments/callback`, {
      method: 'POST',
      body: params,
      // headers: { 'Content-Type': 'application/x-www-form-urlencoded' } // fetch adds this automatically for URLSearchParams
    });

    // 4. Check Response (Should be a 302 Redirect or 200 depending on implementation)
    // The current implementation res.redirect(...) sends a 302.
    console.log('📡 Response Status:', response.status);
    console.log('🔗 Redirected To:', response.url); 
    
    if (response.status === 200 || response.type === 'opaqueredirect' || response.redirected) {
      console.log('✅ Callback verification SUCCESSFUL! Backend accepted the checksum.');
    } else {
      console.log('❌ Callback verification FAILED.');
      const text = await response.text();
      console.log('Response:', text);
    }

  } catch (error) {
    console.error('❌ Test Error:', error);
  }
}

testCallback();

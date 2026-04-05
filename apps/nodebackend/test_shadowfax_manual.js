import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
// Load .env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const { createShadowfaxOrder } = await import('./src/utils/shadowfax.js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY; // Corrected key

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Missing Supabase Credentials");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function testShadowfaxCreation() {
  console.log("🚀 Starting Shadowfax Manual Test...");

  // 1. Get the latest confirmed order
  const { data: order, error: orderError } = await supabase
    .from('orders')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  if (orderError || !order) {
    console.error("❌ Could not fetch an order to test:", orderError);
    return;
  }
  
  console.log(`\n📋 Using Order: ${order.order_number} (ID: ${order.id})`);

// 2. Get the vendor for this order
  const { data: vendor, error: vendorError } = await supabase
    .from('vendors')
    .select('*')
    .eq('id', order.vendor_id)
    .single();

  // Create a unique test ID to avoid "Order Id already created" error
  const uniqueOrderId = `${order.order_number}_TEST_${Date.now()}`;
  console.log(`🆔 Using Unique Order ID: ${uniqueOrderId}`);
  order.order_number = uniqueOrderId;

  if (vendorError || !vendor) {
    console.error("❌ Could not fetch vendor:", vendorError);
    return;
  }

  console.log(`👨‍🍳 Vendor: ${vendor.name}`);

  // 3. Parse delivery address just to be sure it's valid JSON (utils usually handles this but good to check)
  let deliveryAddress = order.delivery_address;
  if (typeof deliveryAddress === 'string') {
      try {
          deliveryAddress = JSON.parse(deliveryAddress);
          // Patch it back for the util function if it expects an object
          order.delivery_address = deliveryAddress; 
      } catch(e) {
          console.error("❌ Invalid delivery address JSON");
          return;
      }
  }

  console.log("📍 Delivery Address Object:", JSON.stringify(deliveryAddress, null, 2));

  console.log("\n🔄 Sending Request to Shadowfax...");
  
  try {
      const response = await createShadowfaxOrder(order, vendor);
      
      console.log("\n✅ SHADOWFAX RESPONSE RECEIVED:");
      console.log(JSON.stringify(response, null, 2));

      if (response && response.data) {
          console.log("\n🎉 SUCCESS! Order accepted by Shadowfax.");
      } else if (response && response.error) {
          console.log("\n❌ Shadowfax returned an error.");
      }

  } catch (error) {
      console.error("\n❌ EXCEPTION during Shadowfax call:", error.message);
      if (error.response) {
          console.error("Response Data:", error.response.data);
      }
  }
}

testShadowfaxCreation();

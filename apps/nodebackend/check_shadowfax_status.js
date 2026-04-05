import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load .env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Missing Supabase Credentials");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkStatus() {
  console.log("🚀 Checking specific Shadowfax Order Status...");

  // Try Client Order ID instead of Flash ID
  const flashId = "GZ202512301951PSXH_TEST_1767108346508"; 

  console.log(`🆔 Tracking Flash Order ID: ${flashId}`);

  // 2. Call Tracking API
  try {
      // Dynamic import to use the project's utility
      const { trackShadowfaxOrder } = await import('./src/utils/shadowfax.js');
      console.log("🔄 Calling Shadowfax Tracking API...");
      
      const trackingData = await trackShadowfaxOrder(flashId);
      
      console.log("\n✅ SHADOWFAX TRACKING RESPONSE:");
      console.log(JSON.stringify(trackingData, null, 2));

      if (trackingData?.rider_details) {
          console.log("\n🚴 Rider Details:");
          console.log(`Name: ${trackingData.rider_details.name}`);
          console.log(`Phone: ${trackingData.rider_details.contact_number}`);
          console.log(`Location:`, trackingData.rider_details.current_location);
      } else {
          console.log("\n⚠️ No rider assigned yet.");
      }

  } catch (e) {
      console.error("❌ Tracking Error:", e);
  }
}

checkStatus();

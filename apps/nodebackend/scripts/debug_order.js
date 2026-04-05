
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

const ORDER_NUMBER = 'GZ202601012340AKI9'; // From user screenshot/logs

async function debugOrder() {
  console.log(`\n🔍 Checking Order: ${ORDER_NUMBER}`);
  
  const { data: order, error } = await supabase
    .from('orders')
    .select('*, vendor:vendors(*)')
    .eq('order_number', ORDER_NUMBER)
    .single();

  if (error) {
    console.error('❌ DB Error or Not Found:', error.message);
    if (error.code === 'PGRST116') {
        console.log('⚠️ Order definitely does not exist in the "orders" table.');
    }
  } else {
    console.log('✅ Order Found:', {
        id: order.id,
        order_number: order.order_number,
        user_id: order.user_id,
        status: order.status,
        vendor_id: order.vendor_id,
        vendor_name: order.vendor?.name,
        vendor_address: order.vendor?.address,
        vendor_city: order.vendor?.city
    });

    if (!order.vendor?.address) {
        console.warn('⚠️ Vendor address is MISSING! This explains the Shadowfax "Unable to fetch Pickup location" error.');
    }
  }
}

debugOrder();

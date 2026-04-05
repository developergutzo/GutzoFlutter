import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load .env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

const orderId = process.argv[2];

async function checkOrder() {
  if (orderId) {
      console.log(`Checking Order: ${orderId}`);
      const { data: order, error } = await supabase
        .from('orders')
        .select('*') // Select all columns
        .eq('order_number', orderId)
        .single();

      if (error) {
        console.error("Error fetching order:", error);
      } else {
        console.log("ORDER DETAILS:", order);
        console.log("--------------------------------");
        console.log(`Status: ${order.status}`);
        console.log(`Delivery Status: ${order.delivery_status}`);
        console.log(`Rider: ${JSON.stringify(order.rider_coordinates)}`);
      }
  } else {
      console.log("No Order ID provided. Listing last 5 orders:");
      const { data, error } = await supabase
        .from('orders')
        .select('id, order_number, status, total_amount, user_id, created_at')
        .order('created_at', { ascending: false })
        .limit(5);
        
    if (error) {
        console.error('Error listing orders:', error);
        return;
    }
    
    console.log(`Found ${data.length} orders.`);
    console.log(JSON.stringify(data, null, 2));
  }
}

checkOrder();

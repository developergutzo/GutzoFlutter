import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function findUserFromOrders() {
  const { data: orders, error } = await supabase
    .from('orders')
    .select('user_id, delivery_address, created_at')
    .order('created_at', { ascending: false })
    .limit(5);

  if (error) {
     console.error("Error fetching orders:", error);
     return;
  }
  
  if (orders.length > 0) {
      console.log('Recent Order User IDs:', orders.map(o => o.user_id));
      console.log('Details:', orders);
  } else {
      console.log('No orders found.');
  }
}

findUserFromOrders();

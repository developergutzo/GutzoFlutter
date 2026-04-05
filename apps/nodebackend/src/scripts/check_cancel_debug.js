
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve('./.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

const orderId = 'b1f5e5c0-bda3-4418-9426-be91757aa22b';

async function checkOrder() {
  const { data: order, error } = await supabase
    .from('orders')
    .select('id, status, delivery_partner_details, delivery_otp')
    .eq('id', orderId)
    .single();

  if (error) {
    console.error('Error fetching order:', error);
    return;
  }

  console.log('Order Details:', JSON.stringify(order, null, 2));
  
  // Also check deliveries
  const { data: delivery, error: delError } = await supabase
    .from('deliveries')
    .select('*')
    .eq('order_id', orderId);
    
   console.log('Deliveries Table:', JSON.stringify(delivery, null, 2));
}

checkOrder();

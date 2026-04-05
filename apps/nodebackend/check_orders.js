import { supabaseAdmin } from './src/config/supabase.js';

async function checkOrders() {
  console.log('Checking latest orders...');
  const { data, error } = await supabaseAdmin
    .from('orders')
    .select('id, order_number, user_id, status, payment_status, total_amount, created_at')
    .order('created_at', { ascending: false })
    .limit(5);

  if (error) {
    console.error('Error fetching orders:', error);
  } else {
    console.table(data);
  }
}

checkOrders();

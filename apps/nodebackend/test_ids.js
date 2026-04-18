import { supabaseAdmin } from './src/config/supabase.js';

async function testData() {
  const { data: orders } = await supabaseAdmin.from('orders').select('user_id, vendor_id, user_phone').limit(1);
  console.log('ORDER:', JSON.stringify(orders[0], null, 2));
  
  const { data: vendors } = await supabaseAdmin.from('vendors').select('id, name').limit(1);
  console.log('VENDOR:', JSON.stringify(vendors[0], null, 2));
}

testData();

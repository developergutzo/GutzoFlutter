import { supabaseAdmin } from './src/config/supabase.js';
import { v4 as uuidv4 } from 'uuid';

async function simulateOrder() {
  const vendorId = '3109c7d3-95e0-4a7a-86dd-9783e778d50e';
  const productId = '2606b152-46a3-46e9-82ef-c356575fc851';
  const userId = '550e8400-e29b-41d4-a716-446655440000'; // Test UUID
  const userPhone = '+919876543210';
  
  const orderNumber = 'TEST-' + Math.random().toString(36).substring(2, 6).toUpperCase();

  console.log('--- STEP 1: PLACING ORDER ---');
  const { data: order, error } = await supabaseAdmin.from('orders').insert({
    order_number: orderNumber,
    user_id: userId,
    vendor_id: vendorId,
    total_amount: 199,
    subtotal: 199,
    delivery_fee: 0,
    platform_fee: 0,
    packaging_fee: 0,
    status: 'placed',
    payment_status: 'paid',
    payment_method: 'online',
    delivery_address: JSON.stringify({area: 'SITRA', city: 'Coimbatore'})
  }).select().single();

  if (error) {
    console.error('FAILED TO PLACE ORDER:', error);
    return;
  }

  console.log('SUCCESS: Order Placed:', order.id, '(' + orderNumber + ')');

  // Wait for partner app to pick it up (Simulated)
  console.log('--- WAITING 5 SECONDS FOR SYNC ---');
  await new Promise(r => setTimeout(r, 5000));

  console.log('--- STEP 2: NOTIFYING CUSTOMER (KITCHEN ACCEPTS) ---');
  console.log('--- Simulating status change to PREPARING ---');
  
  const { error: updateError } = await supabaseAdmin.from('orders')
    .update({ status: 'preparing' })
    .eq('id', order.id);

  if (updateError) {
    console.error('FAILED TO UPDATE STATUS:', updateError);
    return;
  }

  // Insert notification manually since my script doesn't trigger the express route logic
  await supabaseAdmin.from('notifications').insert({
      user_id: userId,
      type: 'order_update',
      title: 'Order Preparing 🍳',
      message: `The kitchen has started preparing your order #${orderNumber}`,
      data: { order_id: order.id }
  });

  console.log('SUCCESS: Status updated and notification sent.');
}

simulateOrder();

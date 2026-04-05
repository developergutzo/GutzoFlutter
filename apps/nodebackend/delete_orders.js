import { supabaseAdmin } from './src/config/supabase.js';

async function deleteUserOrders() {
  const phone = '+919944751745';
  console.log(`Searching for user with phone: ${phone}`);

  // 1. Find User ID
  const { data: user, error: userError } = await supabaseAdmin
    .from('users')
    .select('id')
    .eq('phone', phone)
    .single();

  if (userError || !user) {
    console.error('User not found:', userError);
    return;
  }

  const userId = user.id;
  console.log(`Found User ID: ${userId}`);

  // 2. Delete Orders (Cascade should handle items/payments if configured, otherwise might need manual)
  // Payments link to orders. If FK is cascade, deleting order deletes payment?
  // Usually payments are valuable. But for test, we delete.
  
  // First delete payments linked to these orders to be safe (if no cascade)
  const { data: orders } = await supabaseAdmin.from('orders').select('order_number').eq('user_id', userId);
  
  if (orders && orders.length > 0) {
      const orderNumbers = orders.map(o => o.order_number);
      console.log(`Deleting payments for orders: ${orderNumbers.join(', ')}`);
      
      const { error: payError } = await supabaseAdmin
        .from('payments')
        .delete()
        .in('merchant_order_id', orderNumbers);
        
      if (payError) console.error('Error deleting payments:', payError);
      else console.log('Payments deleted.');
  }

  console.log(`Deleting all orders for User ID: ${userId}`);
  
  const { error: deleteError, count } = await supabaseAdmin
    .from('orders')
    .delete()
    .eq('user_id', userId);

  if (deleteError) {
    console.error('Error deleting orders:', deleteError);
  } else {
    console.log(`Successfully deleted orders.`);
  }
}

deleteUserOrders();

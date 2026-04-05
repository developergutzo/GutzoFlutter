import { supabaseAdmin } from './src/config/supabase.js';

async function checkUser() {
  const userId = 'b59be4e6-cc63-4f38-895f-c73e813f973c'; // ID from previous check_orders.js output
  console.log('Checking user details for:', userId);
  
  const { data: user, error } = await supabaseAdmin
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) {
    console.error('Error fetching user:', error);
  } else {
    console.log('User found:', user);
  }

  console.log('Checking ALL users with similar phone...');
  if (user) {
     const rawPhone = user.phone.replace('+91', '');
     const { data: users } = await supabaseAdmin
        .from('users')
        .select('id, phone, created_at')
        .ilike('phone', `%${rawPhone}%`);
     console.table(users);
  }
}

checkUser();

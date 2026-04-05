import { supabaseAdmin } from './src/config/supabase.js';

async function checkVerification() {
  const userId = 'b59be4e6-cc63-4f38-895f-c73e813f973c';
  console.log('Checking verification for:', userId);
  
  const { data: user, error } = await supabaseAdmin
    .from('users')
    .select('id, phone, verified')
    .eq('id', userId)
    .single();

  if (error) {
    console.error('Error fetching user:', error);
  } else {
    console.log('User status:', user);
    
    if (user && !user.verified) {
       console.log('User is NOT verified. Fixing...');
       const { error: updateError } = await supabaseAdmin
         .from('users')
         .update({ verified: true })
         .eq('id', userId);
         
       if (updateError) console.error('Update failed:', updateError);
       else console.log('User manually VERIFIED.');
    }
  }
}

checkVerification();

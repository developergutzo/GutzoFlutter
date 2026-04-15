import { supabaseAdmin } from './src/config/supabase.js';

async function openAllVendors() {
  console.log('🔓 Opening all vendors for testing...');
  const { data, error } = await supabaseAdmin
    .from('vendors')
    .update({ is_open: true })
    .eq('is_active', true);

  if (error) {
    console.error('❌ Error opening vendors:', error);
  } else {
    console.log('✅ All active vendors are now OPEN.');
  }
  process.exit(0);
}

openAllVendors();

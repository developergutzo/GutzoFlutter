import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import path from 'path';
import { fileURLToPath } from 'url';

// Load .env from nodebackend root
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

console.log('Testing Supabase Connection...');
console.log('URL:', supabaseUrl);
console.log('Key exists:', !!supabaseServiceKey);

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing Supabase credentials!');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function testConnection() {
  try {
    // 1. Test Vendors Table
    console.log('\n--- Fetching Vendors ---');
    const { data: vendors, error: vendorError } = await supabase
      .from('vendors')
      .select('id, name')
      .limit(3);

    if (vendorError) {
      console.error('Error fetching vendors:', vendorError.message);
      // It might be a connection error
      if (vendorError.message.includes('fetch failed') || vendorError.code === 'PGRST301') {
         console.error('Network or Connection Refused. Check URL and connectivity.');
      }
    } else {
      console.log(`Success! Found ${vendors.length} vendors.`);
      if (vendors.length > 0) console.log('Sample:', vendors[0]);
    }

    // 2. Fetch a Valid User for API Testing
    console.log('\n--- Fetching a Test User ---');
    const { data: users, error: userError } = await supabase
      .from('users')
      .select('phone, name, id')
      .eq('verified', true)
      .limit(1);

    if (userError) {
      console.error('Error fetching users:', userError.message);
    } else if (users && users.length > 0) {
      console.log('Valid Test User Found:', users[0]);
      console.log('Use this phone for x-user-phone header:', users[0].phone);
    } else {
      console.warn('No verified users found in the database.');
    }

  } catch (err) {
    console.error('Unexpected error:', err);
  }
}

testConnection();

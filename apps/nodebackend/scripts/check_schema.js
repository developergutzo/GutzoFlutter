
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function checkSchema() {
  console.log(`\n🔍 Checking Vendors Table Schema...`);
  
  // Fetch one vendor and log keys
  const { data: vendor, error } = await supabase
    .from('vendors')
    .select('*')
    .limit(1)
    .single();

  if (error) {
    console.error('❌ Error fetching vendor:', error.message);
  } else {
    console.log('✅ Vendor Keys:', Object.keys(vendor));
    if (!Object.keys(vendor).includes('city')) {
        console.error('❌ "city" column is MISSING from vendors table!');
    }
     if (!Object.keys(vendor).includes('area')) {
        console.error('❌ "area" column is MISSING from vendors table!');
    }
  }
}

checkSchema();

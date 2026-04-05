import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function runMigration() {
  console.log('Testing connection...');
  // Instead of raw execute (which may not exist), we can call a generic RPC if it exists 'exec_sql'
  // Or we can just try to see if we can insert a dummy product to see if it complains about original_price
  const { data, error } = await supabase.rpc('exec_sql', { sql: 'SELECT 1;' });
  
  if (error) {
    console.error('RPC exec_sql failed, might not be installed. Error:', error.message);
    
    // Attempting REST API to check columns by just getting 1 product
    const { data: pData, error: pErr } = await supabase.from('products').select('*').limit(1).single();
    if (pErr) console.error('Error fetching product:', pErr);
    else console.log('Current Product Columns:', Object.keys(pData));
  } else {
    console.log('RPC exec_sql works!');
  }
}

runMigration();

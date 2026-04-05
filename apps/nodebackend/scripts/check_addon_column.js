import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing Supabase credentials!');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkColumns() {
  console.log('Checking columns in "products"...');
  
  const { data, error } = await supabase
    .from('products')
    .select('id, addon_ids, is_veg')
    .limit(1);

  if (error) {
    console.error('Error selecting columns:', error.message);
    if (error.message.includes('is_veg')) {
         console.log('VERDICT: "is_veg" column missing or schema cache stale!');
    }
  } else {
    console.log('Success! All columns (addon_ids, is_veg) exist.');
    if(data.length > 0) console.log('Sample data:', data[0]);
  }
}

checkColumns();

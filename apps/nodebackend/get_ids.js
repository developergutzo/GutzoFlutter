import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load .env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function getIds() {
  const { data: vendor } = await supabase.from('vendors').select('id, name').limit(1).single();
  const { data: user } = await supabase.from('users').select('id, phone').limit(1).single();
  
  console.log("VENDOR:", vendor);
  console.log("USER:", user);
}

getIds();

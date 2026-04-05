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

async function checkSchema() {
  const { data: order, error } = await supabase
    .from('orders')
    .select('*')
    .limit(1)
    .single();

  if (error) {
    console.error("Error fetching order:", error);
    return;
  }

  if (order) {
    console.log("Existing Columns:", Object.keys(order));
  } else {
    console.log("No orders found to check schema. Please create one manually or check migrations.");
  }
}

checkSchema();

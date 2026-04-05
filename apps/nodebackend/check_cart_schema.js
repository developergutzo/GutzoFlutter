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
  // Query 1 row from cart
  const { data: cartItem, error } = await supabase
    .from('cart')
    .select('*')
    .limit(1)
    .single();

  if (error) {
    if (error.code === 'PGRST116') {
        console.log("Cart is empty (no rows). Cannot check schema via * select.");
        // We can try to inserting a dummy item to see columns, or just assume it's missing if we can't see it?
        // Actually, if we use limit(0) maybe? No.
        // Let's try to insert a dummy row that fails but returns columns structure? No.
        return;
    }
    console.error("Error fetching cart:", error);
    return;
  }

  if (cartItem) {
    console.log("Cart Columns:", Object.keys(cartItem));
    if (cartItem.metadata !== undefined) {
        console.log("✅ METADATA column exists!");
    } else {
        console.log("❌ METADATA column MISSING.");
    }
  }
}

checkSchema();

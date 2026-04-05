import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function testInsert() {
  // 1. Get a product
  const { data: product } = await supabase.from('products').select('id, vendor_id').limit(1).single();
  if (!product) {
      console.log("No products found.");
      return;
  }

  // 2. Try insert with metadata
  const { data, error } = await supabase.from('cart').insert({
      user_phone: '+919999999999', // Dummy phone
      product_id: product.id,
      vendor_id: product.vendor_id,
      quantity: 1, 
      metadata: { test: true }
  }).select();

  if (error) {
      console.log("Insert Failed:", error.message);
      if (error.message.includes('column "metadata" of relation "cart" does not exist')) {
          console.log("❌ METADATA COLUMN DOES NOT EXIST");
      }
  } else {
      console.log("✅ Insert Successful! Metadata column exists.");
      // Cleanup
      await supabase.from('cart').delete().eq('id', data[0].id);
  }
}

testInsert();

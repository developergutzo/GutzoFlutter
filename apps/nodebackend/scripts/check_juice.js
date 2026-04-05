import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkProduct() {
    const { data: pData, error: pErr } = await supabase.from('products').select('*').ilike('name', '%ABC Juice%').limit(1).single();
    if (pErr) console.error(pErr);
    else console.log('Product Data:', pData);
}

checkProduct();

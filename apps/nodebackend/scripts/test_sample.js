import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkSample() {
    const { data: pData, error: pErr } = await supabase.from('products').select('*').limit(3);
    if (pErr) console.error(pErr);
    else console.log('Sample Products:', JSON.stringify(pData.map(p => ({
        name: p.name,
        price: p.price,
        discount_price: p.discount_price,
        discount_percent: p.discount_percent
    })), null, 2));
}

checkSample();

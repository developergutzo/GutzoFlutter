
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error("Missing Env Vars");
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function testInsert() {
    console.log("Testing Direct Update...");
    
    // Let's try to find an exitsting delivery to UPDATE
    const { data: existing } = await supabase.from('deliveries').select('id, pickup_otp, delivery_otp').limit(1).single();
    
    if (existing) {
        console.log("Found existing delivery:", existing);
        const { data, error } = await supabase
            .from('deliveries')
            .update({ pickup_otp: '7777', delivery_otp: '6666' })
            .eq('id', existing.id)
            .select();
            
        if (error) console.error("Update Error:", error);
        else console.log("Update Success:", data);
    } else {
        console.log("No deliveries found to test update.");
    }
}

testInsert();

import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const supabaseAdmin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function testJoin() {
    const orderUUID = '0db1e17e-377f-4e72-be7d-2db233269353';
    console.log(`Checking Join for UUID: ${orderUUID}`);

    // Mimic orders.js Query
    const { data: order, error } = await supabaseAdmin
        .from('orders')
        .select(`
            *,
            delivery:deliveries(*)
        `)
        .eq('id', orderUUID)
        .single();
    
    if (error) {
        console.log("❌ Join Query Error:", error);
        return;
    }

    if (!order) {
        console.log("❌ Order NOT FOUND");
        return;
    }

    console.log("✅ Order Found Status:", order.status);
    
    if (!order.delivery || order.delivery.length === 0) {
        console.log("❌ JOIN FAIL: 'delivery' field is missing or empty!");
        console.log("   Actual delivery field:", order.delivery);
    } else {
        console.log("✅ JOIN SUCCESS: 'delivery' field has data:");
        console.log(JSON.stringify(order.delivery, null, 2));
    }
}

testJoin();

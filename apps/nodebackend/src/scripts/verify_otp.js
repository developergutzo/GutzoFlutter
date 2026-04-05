import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function checkOrder() {
    const orderUUID = '0db1e17e-377f-4e72-be7d-2db233269353';
    console.log(`Checking Order UUID: ${orderUUID}`);

    // 1. Get Order
    const { data: order, error } = await supabase.from('orders').select('id, status').eq('id', orderUUID).single();
    
    if (error || !order) {
        console.log("❌ Order NOT FOUND by UUID. Error:", error);
        return;
    }
    console.log("✅ Order Found Status:", order.status);
    console.log("   Order Table Delivery OTP:", order.delivery_otp);

    // 2. Get Delivery Record
    const { data: delivery } = await supabase.from('deliveries').select('*').eq('order_id', orderUUID).single();

    if (!delivery) {
        console.log("❌ Delivery Record NOT FOUND in 'deliveries' table");
    } else {
        console.log("✅ Delivery Record Found (FULL):");
        console.log(JSON.stringify(delivery, null, 2));
    }
}

checkOrder();

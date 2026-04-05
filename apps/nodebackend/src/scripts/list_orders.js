import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function listRecentOrders() {
    const { data: orders, error } = await supabase
        .from('orders')
        .select('order_number, id, created_at')
        .order('created_at', { ascending: false })
        .limit(5);

    if (error) {
        console.error("Error fetching orders:", error);
        return;
    }

    console.log("Recent Orders:");
    orders.forEach(o => {
        console.log(`- ${o.order_number} (ID: ${o.id})`);
    });
}

listRecentOrders();

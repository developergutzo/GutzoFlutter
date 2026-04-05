
import { supabaseAdmin } from './src/config/supabase.js';
import dotenv from 'dotenv';
dotenv.config();

async function checkVendors() {
    console.log("🔍 Checking Vendors...");
    const { data: vendors, error } = await supabaseAdmin.from('vendors').select('*');
    
    if (error) {
        console.error("Error:", error);
        return;
    }

    vendors.forEach(v => {
        console.log(`\nVendor: ${v.name} (${v.id})`);
        console.log(`Address: ${v.address}`);
        console.log(`Lat: ${v.latitude}, Lng: ${v.longitude}`);
        console.log(`Phone: ${v.phone}`);
    });
}

checkVendors();

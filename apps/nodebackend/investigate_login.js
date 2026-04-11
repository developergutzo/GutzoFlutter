
import { supabaseAdmin } from './src/config/supabase.js';
import dotenv from 'dotenv';
dotenv.config();

async function investigate() {
    console.log("🔍 Investigating Login for ccsitra@gutzo.com...");
    const { data: vendor, error } = await supabaseAdmin
        .from('vendors')
        .select('*')
        .eq('email', 'ccsitra@gutzo.com')
        .single();
    
    if (error) {
        console.error("❌ Error finding vendor:", error.message);
        // Try searching by name match if email fails
        console.log("\nSearching by name 'SITRA'...");
        const { data: partners } = await supabaseAdmin
            .from('vendors')
            .select('*')
            .ilike('name', '%SITRA%');
        
        if (partners && partners.length > 0) {
            partners.forEach(p => {
                console.log(`\nFound SITRA Partner: ${p.name}`);
                console.log(`Email: ${p.email}`);
                console.log(`Password: ${p.password}`);
                console.log(`Is Active: ${p.is_active}`);
                console.log(`Phone: ${p.phone}`);
            });
        }
        return;
    }

    console.log("\n✅ Found Vendor:");
    console.log(`Name: ${vendor.name}`);
    console.log(`Email: ${vendor.email}`);
    console.log(`Password: ${vendor.password}`);
    console.log(`Is Active: ${vendor.is_active}`);
    console.log(`Phone: ${vendor.phone}`);
}

investigate();

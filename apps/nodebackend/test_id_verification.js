import dotenv from 'dotenv';
import fetch from 'node-fetch';
dotenv.config();

// Config
const TOKEN = process.env.SHADOWFAX_API_TOKEN;
const URL_BASE = process.env.SHADOWFAX_API_URL;
const SF_ID = '21027231'; // Correct matching ID for YWPE
const INTERNAL_ID = 'GZ202601042212YWPE'; 

async function testFetch(idLabel, idValue) {
    console.log(`\n🔍 Testing ${idLabel}: ${idValue}`);
    const url = `${URL_BASE}/order/track/${idValue}/`;
    console.log(`   URL: ${url}`);
    
    try {
        const res = await fetch(url, {
            method: 'GET',
            headers: { 'Authorization': TOKEN }
        });

        const txt = await res.text();
        console.log(`   Status: ${res.status}`);
        console.log(`   Response: ${txt.substring(0, 200)}...`); // Log first 200 chars

        if (res.ok) {
             console.log("   ✅ SUCCESS: Valid Shadowfax ID");
        } else {
             console.log("   ❌ FAILED: Invalid Shadowfax ID (or expired)");
        }

    } catch (e) {
        console.error("   ⚠️ EXCEPTION:", e.message);
    }
}

async function run() {
    console.log("🛠️  Running Inline API Test...");
    await testFetch("Shadowfax ID", SF_ID);
    await testFetch("Internal GZ ID", INTERNAL_ID);
}

run();

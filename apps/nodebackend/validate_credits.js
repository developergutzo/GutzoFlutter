import fetch from 'node-fetch';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load .env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const SHADOWFAX_API_URL = process.env.SHADOWFAX_API_URL;
const SHADOWFAX_API_TOKEN = process.env.SHADOWFAX_API_TOKEN;
const SHADOWFAX_CREDITS_KEY = process.env.SHADOWFAX_CREDITS_KEY;

async function validateKey() {
    console.log("🔑 Validating Credits Key...");
    console.log(`URL: ${SHADOWFAX_API_URL}/order/credits/key/validate/`);
    console.log(`Key: ${SHADOWFAX_CREDITS_KEY}`);

    try {
        const response = await fetch(`${SHADOWFAX_API_URL}/order/credits/key/validate/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': SHADOWFAX_API_TOKEN
            },
            body: JSON.stringify({
                credits_key: SHADOWFAX_CREDITS_KEY,
                store_brand_id: 0
            })
        });

        const data = await response.json();
        console.log("\n✅ Response:");
        console.log(JSON.stringify(data, null, 2));

    } catch (e) {
        console.error("❌ Error:", e);
    }
}

validateKey();

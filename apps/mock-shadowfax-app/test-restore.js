
import fetch from 'node-fetch';

const BASE_URL = 'http://localhost:3002';
const CLIENT_ID = 'GZ2026020706379LFR';

async function test() {
    try {
        console.log(`Checking tracking for restored order: ${CLIENT_ID}`);
        const res = await fetch(`${BASE_URL}/order/track/${CLIENT_ID}/`);
        const data = await res.json();

        console.log('Response:', data);

        if (data.status === 'FAILED') {
            console.error('❌ Still failing to track restored order');
            process.exit(1);
        } else {
            console.log('✅ Successfully tracked restored order');
        }

    } catch (e) {
        console.error('Test Failed:', e);
    }
}

test();

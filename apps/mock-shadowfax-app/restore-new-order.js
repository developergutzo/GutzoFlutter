
import fetch from 'node-fetch';

const BASE_URL = 'http://localhost:3002';
const MISSING_ORDER_ID = 'GZ202602070659WNNN';

async function restore() {
    try {
        console.log(`Creating missing order: ${MISSING_ORDER_ID}`);

        const res = await fetch(`${BASE_URL}/order/create/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                order_details: { order_id: MISSING_ORDER_ID },
                pickup_details: {
                    address: "Coimbatore Cafe, SITRA",
                    latitude: 11.0, longitude: 77.0
                },
                drop_details: {
                    address: "Customer Location",
                    latitude: 11.1, longitude: 77.1
                },
                validations: {
                    pickup: { otp: "8888" },
                    drop: { otp: "9999" }
                }
            })
        });

        const data = await res.json();
        console.log('Creation Response:', data);

        if (data.is_order_created) {
            console.log('✅ Successfully created missing order in Mock App');
        } else {
            console.error('❌ Failed to create order');
        }

    } catch (e) {
        console.error('Restore Failed:', e);
    }
}

restore();

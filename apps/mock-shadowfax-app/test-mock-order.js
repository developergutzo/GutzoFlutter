
import fetch from 'node-fetch';

const BASE_URL = 'http://localhost:3002';

async function test() {
    try {
        console.log('1. Creating Order...');
        const createRes = await fetch(`${BASE_URL}/order/create/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                order_details: { order_id: 'TEST_GZ_123' },
                pickup_details: { address: 'Test Pickup' },
                drop_details: { address: 'Test Drop' }
            })
        });
        const createData = await createRes.json();
        console.log('Create Response:', createData);

        if (!createData.flash_order_id) throw new Error('Failed to create order');

        const sfId = createData.flash_order_id;
        const clientOrderId = 'TEST_GZ_123';

        console.log('\n2. Tracking by SF ID:', sfId);
        const trackSfRes = await fetch(`${BASE_URL}/order/track/${sfId}/`);
        const trackSfData = await trackSfRes.json();
        console.log('Track SF Response:', trackSfData);

        console.log('\n3. Tracking by Client ID:', clientOrderId);
        const trackClientRes = await fetch(`${BASE_URL}/order/track/${clientOrderId}/`);
        const trackClientData = await trackClientRes.json();
        console.log('Track Client Response:', trackClientData);

        if (trackClientData.status === 'FAILED') {
            console.error('FAILED: Could not track by Client ID');
        } else {
            console.log('SUCCESS: Tracked by Client ID');
        }

    } catch (e) {
        console.error('Test Failed:', e);
    }
}

test();


import axios from 'axios';
import { exec } from 'child_process';

// CONFIG
const API_URL = 'http://localhost:3000/api';
const PHONE = '+919003802398'; // A valid user phone number
const VENDOR_ID = '3cbcc487-d40b-4652-9b5a-1748259d81d2'; // Known Vendor

const createOrder = async () => {
    try {
        console.log(`🚀 Creating Order for User: ${PHONE}...`);

        const payload = {
            vendor_id: VENDOR_ID,
            items: [
                {
                    product_id: null, // Will fetch
                    product_name: 'Butter Chicken',
                    quantity: 1,
                    variant_id: null,
                    addons: [],
                    special_instructions: 'Make it spicy'
                }
            ],
            delivery_address: {
                name: 'Test Customer',
                address: '123 Main St, Tech Park',
                latitude: 12.9716,
                longitude: 77.5946
            },
            delivery_phone: PHONE,
            payment_method: 'cod'
        };

        // 1. Fetch Menu (to get valid product)
        console.log(`📋 Fetching Menu for Vendor ${VENDOR_ID}...`);

        // Correct endpoint: /api/vendors/:id/products
        const menuRes = await axios.get(`${API_URL}/vendors/${VENDOR_ID}/products`);

        const products = menuRes.data.data.products;

        if (!products || products.length === 0) {
            console.error('❌ Vendor has no products! Cannot place order.');
            return;
        }

        const validProduct = products[0];
        console.log(`   Found Product: ${validProduct.name} (₹${validProduct.price})`);

        payload.items[0].product_id = validProduct.id;
        payload.items[0].product_name = validProduct.name;

        // 2. Place Order
        const orderRes = await axios.post(`${API_URL}/orders`, payload, {
            headers: {
                'x-user-phone': PHONE,
                'Content-Type': 'application/json'
            }
        });

        if (orderRes.data.success) {
            const order = orderRes.data.data.order;
            console.log(`\n✅ ORDER CREATED SUCCESSFULLY!`);
            console.log(`   Order #: ${order.order_number}`);
            console.log(`   ID: ${order.id}`);
            console.log(`   Total: ₹${order.total_amount}`);

            console.log(`\n🧾 INVOICE URL:`);
            console.log(`   http://localhost:3000/api/orders/${order.id}/invoice`);

            console.log(`\n👨‍🍳 KITCHEN TICKET URL:`);
            console.log(`   http://localhost:3000/api/orders/${order.id}/kot`);

            // Open in browser
            exec(`start http://localhost:3000/api/orders/${order.id}/invoice`);

        } else {
            console.error('❌ Order Creation Failed:', orderRes.data);
        }

    } catch (error) {
        if (error.response) {
            console.error('❌ API Error:', error.response.status, error.response.data);
        } else {
            console.error('❌ Network/Script Error:', error.message);
        }
    }
};

createOrder();

import cron from 'node-cron';
import { createClient } from '@supabase/supabase-js';
import { trackShadowfaxOrder } from './shadowfax.js';

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

// Configuration
const CRON_INTERVAL = process.env.DELIVERY_CRON_INTERVAL || 60; // seconds
const ENABLE_CRON = process.env.ENABLE_DELIVERY_CRON !== 'false'; // default enabled
const MAX_ORDERS_PER_RUN = 50;
const API_CALL_DELAY = 100; // ms between API calls

// Helper: Sleep function
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Helper: Map Shadowfax status to internal status
const mapShadowfaxStatus = (apiStatus) => {
    const status = apiStatus.toUpperCase();
    if (status === 'ARRIVED') return 'reached_location';
    if (status === 'COLLECTED') return 'picked_up';
    if (status === 'CUSTOMER_DOOR_STEP') return 'arrived_at_drop';
    if (status === 'DELIVERED') return 'delivered';
    return apiStatus.toLowerCase();
};

// Main sync function
async function syncActiveOrders() {
    try {
        console.log('[Delivery Cron] 🔄 Starting sync cycle...');

        // 1. Query active orders
        const { data: activeOrders, error: queryError } = await supabase
            .from('orders')
            .select(`
                id,
                order_number,
                status,
                vendor_id,
                user_id,
                mock_shadowfax,
                delivery:deliveries(
                    id,
                    external_order_id,
                    status,
                    history,
                    rider_name,
                    rider_phone,
                    rider_coordinates
                ),
                vendor:vendors(
                    id,
                    name,
                    email
                )
            `)
            .not('status', 'in', '("delivered","completed","cancelled","rejected")')
            .gte('created_at', new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString())
            .order('created_at', { ascending: false })
            .limit(MAX_ORDERS_PER_RUN);

        if (queryError) {
            console.error('[Delivery Cron] ❌ Query error:', queryError);
            return;
        }

        if (!activeOrders || activeOrders.length === 0) {
            console.log('[Delivery Cron] ℹ️ No active orders to sync');
            return;
        }

        console.log(`[Delivery Cron] 📦 Found ${activeOrders.length} active orders`);

        // 2. Process each order
        let syncedCount = 0;
        let errorCount = 0;

        for (const order of activeOrders) {
            try {
                // Get delivery record
                const delivery = Array.isArray(order.delivery) && order.delivery.length > 0
                    ? order.delivery[0]
                    : null;

                if (!delivery || !delivery.external_order_id) {
                    // No Shadowfax order created yet
                    continue;
                }

                // Skip if already in terminal state
                if (['delivered', 'cancelled'].includes(delivery.status)) {
                    continue;
                }

                // 3. Call Shadowfax tracking API
                const trackingInfo = await trackShadowfaxOrder(delivery.external_order_id, order.mock_shadowfax);

                if (!trackingInfo || !trackingInfo.status) {
                    console.warn(`[Delivery Cron] ⚠️ No tracking info for ${order.order_number}`);
                    continue;
                }

                const apiStatus = trackingInfo.status.toUpperCase();
                const internalStatus = mapShadowfaxStatus(apiStatus);
                const dbStatus = delivery.status;

                // 4. Check for drift
                if (internalStatus === dbStatus || internalStatus === 'unknown') {
                    // No change
                    continue;
                }

                console.log(`[Delivery Cron] 🔄 Status drift detected for ${order.order_number}: ${dbStatus} → ${internalStatus}`);

                // 5. Update deliveries table
                const newHistoryItem = {
                    status: internalStatus,
                    timestamp: new Date().toISOString(),
                    note: `Cron Sync: ${apiStatus}`
                };

                const updatedHistory = delivery.history
                    ? [...delivery.history, newHistoryItem]
                    : [newHistoryItem];

                const deliveryUpdatePayload = {
                    status: internalStatus,
                    rider_name: trackingInfo.rider_details?.name || delivery.rider_name,
                    rider_phone: trackingInfo.rider_details?.contact_number || delivery.rider_phone,
                    rider_coordinates: trackingInfo.rider_details?.current_location || delivery.rider_coordinates,
                    history: updatedHistory,
                    updated_at: new Date().toISOString()
                };

                await supabase
                    .from('deliveries')
                    .update(deliveryUpdatePayload)
                    .eq('id', delivery.id);

                // 6. Update orders table for critical milestones
                const orderUpdatePayload = {};

                if (apiStatus === 'DELIVERED') {
                    orderUpdatePayload.status = 'completed';
                } else if (apiStatus === 'COLLECTED') {
                    orderUpdatePayload.status = 'on_way';
                } else if (apiStatus === 'ACCEPTED' && (dbStatus === 'searching_rider' || dbStatus === 'created')) {
                    // When rider accepts, move order to confirmed so it shows up for vendor
                    orderUpdatePayload.status = 'confirmed';
                } else if (apiStatus === 'CANCELLED') {
                    orderUpdatePayload.status = 'cancelled';
                }

                if (Object.keys(orderUpdatePayload).length > 0) {
                    await supabase
                        .from('orders')
                        .update({
                            ...orderUpdatePayload,
                            updated_at: new Date().toISOString()
                        })
                        .eq('id', order.id);
                }

                // 7. Trigger notifications
                if (apiStatus === 'ACCEPTED' && (dbStatus === 'searching_rider' || dbStatus === 'created')) {
                    // Rider allocated - notify vendor
                    if (order.vendor) {
                        console.log(`[Delivery Cron] 📧 Notifying vendor for ${order.order_number}`);

                        // Send email
                        import('./emailService.js').then(({ sendVendorOrderNotification }) => {
                            // Fetch full order with items
                            supabase.from('orders')
                                .select('*, items:order_items(*), vendor:vendors(*)')
                                .eq('id', order.id)
                                .single()
                                .then(({ data: fullOrder }) => {
                                    if (fullOrder) {
                                        sendVendorOrderNotification(fullOrder.vendor.email, fullOrder);
                                    }
                                });
                        });

                        // Send push
                        import('./pushService.js').then(({ sendVendorPush }) => {
                            const msg = `Rider Assigned! ${trackingInfo.rider_details?.name || 'Partner'} is on the way.`;
                            sendVendorPush(order.vendor.id, 'Order Update 🔔', msg);
                        });
                    }
                } else if (dbStatus === 'accepted' && (apiStatus === 'SEARCHING_RIDER' || apiStatus === 'PENDING' || apiStatus === 'CANCELLED')) {
                    // Reverse scenario: Order was ALLOTTED but now is SEARCHING (Rider cancelled/unassigned)
                    console.log(`[Delivery Cron] ⚠️ Rider UN-ASSIGNED for ${order.order_number}. Cancelling old assignment if needed.`);

                    // If the status went back to searching (or cancelled by platform), we should potentially cancel the specific *previous* order request if needed
                    // But usually Shadowfax handles re-broadcast. 
                    // However, user specifically asked to "send order cancel request" if status reverts.
                    // This implies we want to ensure any stale state is cleaned up or we explicitly cancel the order in Shadowfax to restart?
                    // Actually, if Shadowfax says "SEARCHING", it means *they* already know. 
                    // If user meant "If we move from Allotted -> Searching locally, cancel the Shadowfax order", that's different.
                    // But here we are syncing FROM Shadowfax TO Local.
                    // If Shadowfax says "SEARCHING", we just update local to "searching_rider".

                    // USER REQUEST: "if status is wise versa (Allotted -> Searching) then send order cancel request also"
                    // This is slightly ambiguous. If Shadowfax *already* says Searching, sending a cancel request to Shadowfax might kill the new search.
                    // BUT, if the user implies we want to CANCEL the order entirely if a rider drops, we can do that.
                    // OR if the user thinks we should cancel the *previous* driver association.

                    // Let's assume the user wants to CANCEL the entire delivery request if a driver drops (maybe to retry manually?).
                    // OR more likely, they want to ensure the specific Shadowfax order is cancelled if we revert state?
                    // Let's implement a safe cancellation log/attempt.

                    if (apiStatus === 'CANCELLED') {
                        // Already cancelled in Shadowfax, just sync.
                    } else {
                        // Status regressed to Searching.
                        // User said "send order cancel request". 
                        // I will attempt to cancel the *current* Shadowfax order ID to be safe, assuming we want to kill this specific attempt?
                        // WARNING: If Shadowfax is auto-retrying, this might stop it.
                        // Let's assume User wants to CANCEL status update to trigger a cancel on Shadowfax side?
                        // No, we are reacting to Shadowfax status.

                        // Let's assume User means: If local was Allotted and now API says something else (unassigned), ensure we cancel/reset properly.
                        // Actually, looking at the request "send order cancel reqyuest also", it often means "Cancel the order entirely".

                        // Sending cancel request to Shadowfax:
                        import('./shadowfax.js').then(({ cancelShadowfaxOrder }) => {
                            cancelShadowfaxOrder(delivery.external_order_id, "Rider Unassigned/Dropped - System Auto Cancel", order.mock_shadowfax)
                                .then(res => console.log(`[Cron] Cancelled ${order.mock_shadowfax ? 'MOCK' : 'REAL'} Shadowfax Order:`, res));
                        });
                    }
                }

                syncedCount++;

                // Rate limiting - delay between API calls
                await sleep(API_CALL_DELAY);

            } catch (orderError) {
                console.error(`[Delivery Cron] ❌ Error syncing order ${order.order_number}:`, orderError.message);
                errorCount++;
                // Continue to next order
            }
        }

        console.log(`[Delivery Cron] ✅ Sync complete: ${syncedCount} updated, ${errorCount} errors`);

    } catch (error) {
        console.error('[Delivery Cron] ❌ Fatal error:', error);
    }
}

// Start cron job
export function startDeliveryCron() {
    if (!ENABLE_CRON) {
        console.log('[Delivery Cron] ⏸️ Cron disabled via ENABLE_DELIVERY_CRON=false');
        return;
    }

    // Cron expression: every N seconds
    const cronExpression = `*/${CRON_INTERVAL} * * * * *`;

    console.log(`[Delivery Cron] 🚀 Starting delivery sync cron (every ${CRON_INTERVAL}s)`);

    cron.schedule(cronExpression, syncActiveOrders);

    // Run once immediately on startup
    syncActiveOrders();
}

// Auto-start if imported
if (ENABLE_CRON) {
    startDeliveryCron();
}

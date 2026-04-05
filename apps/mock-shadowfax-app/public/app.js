// API Base URL
const API_BASE = '';

// State
let orders = [];
let selectedOrder = null;

// Status progression map (Happy Path)
const STATUS_FLOW = {
    'CREATED': 'ACCEPTED',
    'ACCEPTED': 'ARRIVED',
    'ARRIVED': 'COLLECTED',
    'COLLECTED': 'CUSTOMER_DOOR_STEP',
    'CUSTOMER_DOOR_STEP': 'DELIVERED',
    // RTS Flow
    'RTS_INITIATED': 'RTS_COMPLETED'
};

const CANCEL_REASONS = [
    "Cancelled by Customer",
    "Rider Not Available or is Late",
    "Customer Not Available",
    "Duplicate Order",
    "Delivery Address Unserviceable or Incorrect",
    "Operational Issue with order",
    "Cancelled by Seller",
    "Rider not having enough cash for purchase",
    "Delivered by seller",
    "Item not available",
    "Incorrect seller location",
    "Customer Not responding / Phone switched off",
    "Placed order by mistake",
    "Order item is not ready",
    "Got faster option from other provider",
    "Expected a shorter wait time",
    "Delivery partner refused pickup"
];

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    fetchOrders();
    // Auto-refresh every 5 seconds
    setInterval(fetchOrders, 5000);
    createCancelModal(); // Inject modal on load
});

// Fetch all orders
async function fetchOrders() {
    try {
        const response = await fetch(`${API_BASE}/api/orders`);
        const data = await response.json();
        orders = data.orders || [];
        renderOrders();
        updateStats();
    } catch (error) {
        console.error('Failed to fetch orders:', error);
    }
}

// Render orders grid
function renderOrders() {
    const emptyState = document.getElementById('emptyState');
    const ordersContainer = document.getElementById('ordersContainer');
    const ordersGrid = document.getElementById('ordersGrid');

    if (orders.length === 0) {
        emptyState.style.display = 'block';
        ordersContainer.style.display = 'none';
        return;
    }

    emptyState.style.display = 'none';
    ordersContainer.style.display = 'block';

    ordersGrid.innerHTML = orders.map(order => `
        <div class="order-card" onclick="openOrderModal('${order.shadowfax_id}')">
            <div class="order-header">
                <div class="order-id">${order.client_order_id}</div>
                <div class="status-badge status-${order.status}">${order.status}</div>
            </div>
            
            <div class="order-details">
                <div class="detail-row">
                    <span class="detail-label">Shadowfax ID</span>
                    <span class="detail-value">${order.shadowfax_id.substring(0, 20)}...</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Pickup</span>
                    <span class="detail-value">${order.pickup_details?.name || 'N/A'}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Drop</span>
                    <span class="detail-value">${order.drop_details?.name || 'N/A'}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Created</span>
                    <span class="detail-value">${formatTime(order.created_at)}</span>
                </div>
                ${order.rider_details ? `
                <div class="detail-row">
                    <span class="detail-label">Rider</span>
                    <span class="detail-value">${order.rider_details.name}</span>
                </div>
                ` : ''}
                ${order.rider_details && order.rider_details.latitude ? `
                <div class="detail-row">
                    <span class="detail-label">Location</span>
                    <span class="detail-value" style="font-family:monospace; font-size:11px;">
                        ${parseFloat(order.rider_details.latitude).toFixed(4)}, ${parseFloat(order.rider_details.longitude).toFixed(4)}
                    </span>
                </div>
                ` : ''}
            </div>

            <div class="order-actions" onclick="event.stopPropagation()">
                ${renderActionButtons(order)}
            </div>
        </div>
    `).join('');
}

// Render action buttons based on status
function renderActionButtons(order) {
    const buttons = [];

    // Standard Progression Buttons
    const progression = ['ACCEPTED', 'ARRIVED', 'COLLECTED', 'CUSTOMER_DOOR_STEP', 'DELIVERED'];
    const nextStatus = STATUS_FLOW[order.status];

    progression.forEach(status => {
        const isNext = (status === nextStatus);
        const isCurrent = (status === order.status);
        const isPast = order.history.some(h => h.status === status) && !isCurrent;
        
        let btnClass = 'btn-secondary';
        let disabledAttr = '';
        let labelSuffix = '';

        if (isNext) {
            btnClass = 'btn-primary';
        } else if (isCurrent || isPast) {
            btnClass = 'btn-success';
            disabledAttr = 'disabled';
            labelSuffix = ' ✓';
        } else {
            disabledAttr = 'disabled';
            btnClass = 'btn-disabled';
        }

        const label = getStatusLabel(status);
        
        // Special Case: ACCEPTED calls assignRider if current status is CREATED
        const clickAction = (status === 'ACCEPTED' && order.status === 'CREATED') 
            ? `assignRider('${order.shadowfax_id}')` 
            : `updateStatus('${order.shadowfax_id}', '${status}')`;

        buttons.push(`
            <button class="btn ${btnClass}" ${disabledAttr} onclick="${clickAction}">
                ${label}${labelSuffix}
            </button>
        `);
    });

    // New Line for Secondary/Admin Actions
    buttons.push('<div style="width: 100%; height: 8px;"></div>');

    // RTS Option (Available after Pickup)
    // const rtsActiveStatuses = ['COLLECTED', 'CUSTOMER_DOOR_STEP'];
    // if (rtsActiveStatuses.includes(order.status)) {
    //     buttons.push(`
    //         <button class="btn btn-warning" onclick="updateStatus('${order.shadowfax_id}', 'RTS_INITIATED')" style="background-color: #f59e0b; color: white; border: none;">
    //             🔄 RTS
    //         </button>
    //     `);
    // }

    // Cancel button (if not delivered/cancelled/rts_completed)
    if (!['DELIVERED', 'CANCELLED', 'RTS_COMPLETED'].includes(order.status)) {
        buttons.push(`
            <button class="btn btn-danger" onclick="openCancelModal('${order.shadowfax_id}')">
                🚫 Cancel
            </button>
        `);
    }

    // Map Button (Location Simulation)
    if (!['CANCELLED', 'REJECTED'].includes(order.status)) {
        buttons.push(`
            <button class="btn" onclick="openLocationModal('${order.shadowfax_id}')" style="background-color: #3b82f6; color: white; border: none;">
                📍 Map
            </button>
        `);
    }

    return buttons.join('');
}

// Get friendly status label
function getStatusLabel(status) {
    const labels = {
        'ACCEPTED': 'Accepted',
        'ARRIVED': 'Arrived',
        'COLLECTED': 'Collected',
        'CUSTOMER_DOOR_STEP': 'Doorstep',
        'DELIVERED': 'Delivered',
        'RTS_INITIATED': 'RTS',
        'RTS_COMPLETED': 'RTS done'
    };
    return labels[status] || status;
}

// Assign rider to order
async function assignRider(orderId) {
    try {
        const response = await fetch(`${API_BASE}/api/orders/${orderId}/assign-rider`, {
            method: 'POST'
        });

        if (response.ok) {
            console.log('✅ Rider assigned');
            await fetchOrders();
        }
    } catch (error) {
        console.error('Failed to assign rider:', error);
        alert('Failed to assign rider');
    }
}

// Update order status
async function updateStatus(orderId, newStatus) {
    try {
        const response = await fetch(`${API_BASE}/api/orders/${orderId}/update-status`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: newStatus })
        });

        if (response.ok) {
            console.log(`✅ Status updated to ${newStatus}`);
            await fetchOrders();
        }
    } catch (error) {
        console.error('Failed to update status:', error);
        alert('Failed to update status');
    }
}

// --- CANCELLATION MODAL LOGIC ---

function createCancelModal() {
    const modalHtml = `
    <div class="modal" id="cancelModal">
        <div class="modal-content" style="max-width: 500px;">
            <div class="modal-header">
                <h2>Cancel Order</h2>
                <button class="close-btn" onclick="closeCancelModal()">×</button>
            </div>
            <div class="modal-body">
                <p>Please select a reason for cancellation:</p>
                <select id="cancelReasonInput" style="width: 100%; padding: 10px; margin-bottom: 20px; border: 1px solid #ddd; border-radius: 8px;">
                    ${CANCEL_REASONS.map(r => `<option value="${r}">${r}</option>`).join('')}
                </select>
                
                <p>Cancelled By:</p>
                <div class="radio-group" style="display: flex; gap: 20px; margin-bottom: 20px;">
                    <label style="display: flex; align-items: center; gap: 8px;">
                        <input type="radio" name="cancelledBy" value="sfx" checked> Shadowfax (sfx)
                    </label>
                    <label style="display: flex; align-items: center; gap: 8px;">
                        <input type="radio" name="cancelledBy" value="client"> Client
                    </label>
                </div>

                <div style="display: flex; gap: 10px; justify-content: flex-end;">
                    <button class="btn" onclick="closeCancelModal()" style="background: #e5e7eb; color: #374151;">Close</button>
                    <button class="btn btn-danger" onclick="submitCancel()">Confirm Cancellation</button>
                </div>
            </div>
        </div>
    </div>
    `;
    document.body.insertAdjacentHTML('beforeend', modalHtml);
}

let orderToCancel = null;

function openCancelModal(orderId) {
    orderToCancel = orderId;
    document.getElementById('cancelModal').classList.add('active');
}

function closeCancelModal() {
    document.getElementById('cancelModal').classList.remove('active');
    orderToCancel = null;
}

async function submitCancel() {
    if (!orderToCancel) return;

    const reason = document.getElementById('cancelReasonInput').value;
    const cancelledBy = document.querySelector('input[name="cancelledBy"]:checked').value;

    try {
        const response = await fetch(`${API_BASE}/order/cancel/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                order_id: orderToCancel,
                cancellation_reason: reason,
                cancelled_by: cancelledBy
            })
        });

        if (response.ok) {
            console.log('✅ Order cancelled');
            closeCancelModal();
            await fetchOrders();
        } else {
            const err = await response.json();
            alert('Failed to cancel: ' + err.message);
        }
    } catch (error) {
        console.error('Failed to cancel order:', error);
        alert('Failed to cancel order');
    }
}


// Open order detail modal
function openOrderModal(orderId) {
    const order = orders.find(o => o.shadowfax_id === orderId);
    if (!order) return;

    selectedOrder = order;
    const modal = document.getElementById('orderModal');
    const modalBody = document.getElementById('modalBody');

    modalBody.innerHTML = `
        <div class="info-section">
            <h3>Order Information</h3>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Client Order ID</span>
                    <span class="info-value">${order.client_order_id}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Shadowfax ID</span>
                    <span class="info-value">${order.shadowfax_id}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Status</span>
                    <span class="info-value">
                        <span class="status-badge status-${order.status}">${order.status}</span>
                    </span>
                </div>
                <div class="info-item">
                    <span class="info-label">Created At</span>
                    <span class="info-value">${formatDateTime(order.created_at)}</span>
                </div>
            </div>
        </div>

        <div class="info-section">
            <h3>Pickup Details</h3>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Name</span>
                    <span class="info-value">${order.pickup_details?.name || 'N/A'}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Contact</span>
                    <span class="info-value">${order.pickup_details?.contact_number || 'N/A'}</span>
                </div>
                <div class="info-item" style="grid-column: 1 / -1;">
                    <span class="info-label">Address</span>
                    <span class="info-value">${order.pickup_details?.address || 'N/A'}</span>
                </div>
            </div>
        </div>

        <div class="info-section">
            <h3>Drop Details</h3>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Name</span>
                    <span class="info-value">${order.drop_details?.name || 'N/A'}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Contact</span>
                    <span class="info-value">${order.drop_details?.contact_number || 'N/A'}</span>
                </div>
                <div class="info-item" style="grid-column: 1 / -1;">
                    <span class="info-label">Address</span>
                    <span class="info-value">${order.drop_details?.address || 'N/A'}</span>
                </div>
            </div>
        </div>

        ${order.rider_details ? `
        <div class="info-section">
            <h3>Rider Details</h3>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Name</span>
                    <span class="info-value">${order.rider_details.name}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Contact</span>
                    <span class="info-value">${order.rider_details.contact_number}</span>
                </div>
            </div>
        </div>
        ` : ''}

        <div class="info-section">
            <h3>Order History</h3>
            <div class="history-timeline">
                ${order.history.map(item => `
                    <div class="history-item">
                        <div class="history-status">${item.status}</div>
                        <div class="history-time">${formatDateTime(item.timestamp)}</div>
                        ${item.note ? `<div class="history-note">${item.note}</div>` : ''}
                    </div>
                `).join('')}
            </div>
        </div>
    `;

    modal.classList.add('active');
}

// Close modal
function closeModal() {
    const modal = document.getElementById('orderModal');
    modal.classList.remove('active');
    selectedOrder = null;
}

// Update stats
function updateStats() {
    const total = orders.length;
    const active = orders.filter(o => !['DELIVERED', 'CANCELLED', 'RTS_COMPLETED'].includes(o.status)).length;
    const delivered = orders.filter(o => o.status === 'DELIVERED').length;

    document.getElementById('totalOrders').textContent = total;
    document.getElementById('activeOrders').textContent = active;
    document.getElementById('deliveredOrders').textContent = delivered;
}

// Format time (relative)
function formatTime(timestamp) {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = Math.floor((now - date) / 1000); // seconds

    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
}

// Format date time
function formatDateTime(timestamp) {
    const date = new Date(timestamp);
    return date.toLocaleString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Close modal on outside click
document.getElementById('orderModal')?.addEventListener('click', (e) => {
    if (e.target.id === 'orderModal') {
        closeModal();
    }
});

// --- MAP SIMULATION LOGIC ---
let map = null;
let riderMarker = null;
let newRiderLocation = null;

function openLocationModal(shadowfaxId) {
    const order = orders.find(o => o.shadowfax_id === shadowfaxId);
    if (!order) return;

    selectedOrder = order;
    document.getElementById('location-modal').style.display = 'block';

    // Defer map init to ensure container is visible
    setTimeout(() => {
        initMap(order);
    }, 100);
}

function closeLocationModal() {
    document.getElementById('location-modal').style.display = 'none';
}

function initMap(order) {
    // Default: Coimbatore (or Order Loc)
    let defaultLat = 11.0168;
    let defaultLng = 76.9558;

    if (order.pickup_details?.latitude) {
        defaultLat = parseFloat(order.pickup_details.latitude);
        defaultLng = parseFloat(order.pickup_details.longitude);
    }

    if (!map) {
        map = L.map('simulation-map').setView([defaultLat, defaultLng], 13);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap'
        }).addTo(map);

        map.on('click', function (e) {
            updateRiderMarker(e.latlng.lat, e.latlng.lng);
        });
    }

    // Clear existing markers
    map.eachLayer((layer) => {
        if (layer instanceof L.Marker) map.removeLayer(layer);
    });

    // Add Markers
    // Pickup (Green)
    if (order.pickup_details?.latitude) {
        const pLat = parseFloat(order.pickup_details.latitude);
        const pLng = parseFloat(order.pickup_details.longitude);
        const pickupIcon = L.icon({
            iconUrl: 'https://cdn-icons-png.flaticon.com/512/684/684908.png', // Location pin
            iconSize: [32, 32],
            iconAnchor: [16, 32]
        });
        L.marker([pLat, pLng], { icon: pickupIcon }).addTo(map).bindPopup('🏠 Pickup: ' + (order.pickup_details.name || ''));
    }

    // Drop (Red)
    if (order.drop_details?.latitude) {
        const dLat = parseFloat(order.drop_details.latitude);
        const dLng = parseFloat(order.drop_details.longitude);
        const dropIcon = L.icon({
            iconUrl: 'https://cdn-icons-png.flaticon.com/512/684/684908.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            className: 'hue-rotate-180' // Hack to change color
        });
        L.marker([dLat, dLng]).addTo(map).bindPopup('🏁 Drop: ' + (order.drop_details.name || ''));
    }

    // Rider (Bike)
    let rLat = order.rider_details?.latitude ? parseFloat(order.rider_details.latitude) : defaultLat;
    let rLng = order.rider_details?.longitude ? parseFloat(order.rider_details.longitude) : defaultLng;

    updateRiderMarker(rLat, rLng);
    map.setView([rLat, rLng], 14);
}

function updateRiderMarker(lat, lng) {
    if (riderMarker) map.removeLayer(riderMarker);
    const icon = L.icon({
        iconUrl: 'https://cdn-icons-png.flaticon.com/512/3082/3082383.png',
        iconSize: [40, 40],
        iconAnchor: [20, 20]
    });

    riderMarker = L.marker([lat, lng], { icon: icon, draggable: true }).addTo(map);
    riderMarker.bindPopup("🛵 Rider (Drag Me)").openPopup();

    riderMarker.on('dragend', function (event) {
        const position = event.target.getLatLng();
        newRiderLocation = { lat: position.lat, lng: position.lng };
    });

    newRiderLocation = { lat, lng };
}

async function confirmLocationUpdate() {
    if (!selectedOrder || !newRiderLocation) return;

    try {
        const response = await fetch(`${API_BASE}/api/orders/${selectedOrder.shadowfax_id}/update-location`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                latitude: newRiderLocation.lat,
                longitude: newRiderLocation.lng
            })
        });

        if (response.ok) {
            console.log("Rider location updated");
            closeLocationModal();
            // Don't full refresh to avoid closing modal? No, we closed it.
            fetchOrders();
        } else {
            alert("Update failed");
        }
    } catch (e) { console.error(e); alert("Update failed"); }
}

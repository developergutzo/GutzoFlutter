# Mock Shadowfax - Delivery Partner Dashboard

A standalone mock application that simulates the Shadowfax delivery partner API
and provides a UI dashboard for managing orders.

## Features

✅ **Mock Shadowfax API** - Fully compatible endpoints\
✅ **UI Dashboard** - Visual order management\
✅ **In-Memory Storage** - No database required\
✅ **Status Progression** - Manual order lifecycle control\
✅ **Auto-Refresh** - Real-time updates every 5 seconds\
✅ **Gutzo Design System** - Consistent branding

---

## Quick Start

### 1. Install Dependencies

```bash
cd mock-shadowfax-app
npm install
```

### 2. Start Server

```bash
npm start
```

Server will start on **http://localhost:3002**

### 3. Open Dashboard

Visit **http://localhost:3002** in your browser

---

## API Endpoints

### Create Order

```http
POST http://localhost:3002/order/create/
Content-Type: application/json
Authorization: any_token

{
  "order_details": {
    "order_id": "GZ123",
    "is_prepaid": true,
    "cash_to_be_collected": 0
  },
  "pickup_details": {
    "name": "Vendor Name",
    "contact_number": "+919876543210",
    "address": "123 Main St"
  },
  "drop_details": {
    "name": "Customer Name",
    "contact_number": "+919123456789",
    "address": "456 Park Ave"
  },
  "validations": {
    "pickup": { "is_otp_required": true, "otp": "1234" },
    "drop": { "is_otp_required": true, "otp": "5678" }
  }
}
```

**Response**:

```json
{
    "status": "CREATED",
    "order_id": "SFX_MOCK_1738412345678_abc123",
    "awb_number": "SFX_MOCK_1738412345678_abc123"
}
```

### Track Order

```http
GET http://localhost:3002/order/track/{orderId}/
```

**Response**:

```json
{
    "status": "COLLECTED",
    "awb_number": "SFX_MOCK_...",
    "rider_name": "Rajesh Kumar",
    "rider_contact_number": "+919876543210",
    "rider_latitude": 12.9716,
    "rider_longitude": 77.5946
}
```

### Cancel Order

```http
POST http://localhost:3002/order/cancel/
Content-Type: application/json

{
  "order_id": "SFX_MOCK_...",
  "cancellation_reason": "Customer requested"
}
```

---

## Dashboard Features

### Order List

- View all orders in real-time
- Status badges with color coding
- Quick actions for each order

### Status Progression

1. **CREATED** → Click "Accept & Assign Rider" → **ALLOTTED**
2. **ALLOTTED** → Click "Mark Arrived" → **ARRIVED**
3. **ARRIVED** → Click "Mark Picked Up" → **COLLECTED**
4. **COLLECTED** → Click "At Customer Door" → **CUSTOMER_DOOR_STEP**
5. **CUSTOMER_DOOR_STEP** → Click "Mark Delivered" → **DELIVERED**

### Actions

- **Accept Order**: Assigns a random rider and updates status to ALLOTTED
- **Progress Status**: Moves order to next status in the flow
- **Cancel Order**: Cancels the order at any stage
- **View Details**: Click on any order card to see full details

---

## Integration with Gutzo App

### Option 1: Environment Variable

Add to `nodebackend/.env`:

```env
USE_MOCK_SHADOWFAX=true
MOCK_SHADOWFAX_URL=http://localhost:3002
```

### Option 2: Update shadowfax.js

Modify `/nodebackend/src/utils/shadowfax.js`:

```javascript
const SHADOWFAX_API_URL = process.env.USE_MOCK_SHADOWFAX === "true"
    ? process.env.MOCK_SHADOWFAX_URL
    : process.env.SHADOWFAX_API_URL;
```

### Option 3: Checkout Page Toggle

Add checkbox in checkout page to toggle mock mode at runtime.

---

## Status Codes

| Status               | Description                      |
| -------------------- | -------------------------------- |
| `CREATED`            | Order created, waiting for rider |
| `ALLOTTED`           | Rider assigned                   |
| `ARRIVED`            | Rider reached pickup location    |
| `COLLECTED`          | Order picked up                  |
| `CUSTOMER_DOOR_STEP` | Rider at delivery location       |
| `DELIVERED`          | Order delivered successfully     |
| `CANCELLED`          | Order cancelled                  |

---

## Development

### Run with Auto-Reload

```bash
npm run dev
```

### Project Structure

```
mock-shadowfax-app/
├── server.js           # Express server with API
├── public/
│   ├── index.html      # Dashboard UI
│   ├── style.css       # Gutzo design system styles
│   └── app.js          # Frontend logic
├── package.json
└── README.md
```

---

## Testing

### 1. Create Test Order

```bash
curl -X POST http://localhost:3002/order/create/ \
  -H "Content-Type: application/json" \
  -d '{
    "order_details": {"order_id": "TEST123"},
    "pickup_details": {"name": "Test Vendor"},
    "drop_details": {"name": "Test Customer"}
  }'
```

### 2. Check Dashboard

Open http://localhost:3002 - order should appear

### 3. Accept Order

Click "Accept & Assign Rider" button

### 4. Track Order

```bash
curl http://localhost:3002/order/track/SFX_MOCK_.../
```

---

## Notes

- **In-Memory Storage**: Orders reset when server restarts
- **No Authentication**: Mock API accepts any token
- **Auto-Refresh**: Dashboard updates every 5 seconds
- **Port**: Runs on 3002 (configurable in server.js)

---

## Support

For issues or questions, check the main Gutzo documentation or contact the
development team.

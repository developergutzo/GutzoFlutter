# Gutzo API - Node.js/Express.js Backend

Complete RESTful API for the Gutzo food marketplace.

## Quick Start

```bash
cd nodebackend
cp .env.example .env
# Edit .env with your Supabase credentials
npm install
npm run dev
```

API runs on: `http://localhost:5000`

## API Endpoints

### Auth

| Method | Endpoint               | Description        |
| ------ | ---------------------- | ------------------ |
| POST   | `/api/auth/send-otp`   | Send OTP to phone  |
| POST   | `/api/auth/verify-otp` | Verify OTP & login |
| GET    | `/api/auth/status`     | Check auth status  |
| POST   | `/api/auth/logout`     | Logout             |

### Users

| Method | Endpoint                           | Description    |
| ------ | ---------------------------------- | -------------- |
| GET    | `/api/users/me`                    | Get profile    |
| PUT    | `/api/users/me`                    | Update profile |
| GET    | `/api/users/addresses`             | Get addresses  |
| POST   | `/api/users/addresses`             | Add address    |
| PUT    | `/api/users/addresses/:id`         | Update address |
| DELETE | `/api/users/addresses/:id`         | Delete address |
| PATCH  | `/api/users/addresses/:id/default` | Set default    |

### Vendors

| Method | Endpoint                    | Description      |
| ------ | --------------------------- | ---------------- |
| GET    | `/api/vendors`              | List vendors     |
| GET    | `/api/vendors/featured`     | Featured vendors |
| GET    | `/api/vendors/:id`          | Get vendor       |
| GET    | `/api/vendors/:id/products` | Vendor products  |
| GET    | `/api/vendors/:id/reviews`  | Vendor reviews   |
| GET    | `/api/vendors/:id/schedule` | Operating hours  |

### Products

| Method | Endpoint                     | Description       |
| ------ | ---------------------------- | ----------------- |
| GET    | `/api/products`              | List products     |
| GET    | `/api/products/featured`     | Featured products |
| GET    | `/api/products/bestsellers`  | Bestsellers       |
| GET    | `/api/products/:id`          | Get product       |
| GET    | `/api/products/:id/variants` | Product variants  |
| GET    | `/api/products/:id/addons`   | Product addons    |

### Cart

| Method | Endpoint             | Description   |
| ------ | -------------------- | ------------- |
| GET    | `/api/cart`          | Get cart      |
| POST   | `/api/cart`          | Add to cart   |
| PUT    | `/api/cart/:id`      | Update item   |
| DELETE | `/api/cart/:id`      | Remove item   |
| DELETE | `/api/cart`          | Clear cart    |
| POST   | `/api/cart/validate` | Validate cart |

### Orders

| Method | Endpoint                  | Description  |
| ------ | ------------------------- | ------------ |
| POST   | `/api/orders`             | Create order |
| GET    | `/api/orders`             | User orders  |
| GET    | `/api/orders/:id`         | Get order    |
| GET    | `/api/orders/:id/track`   | Track order  |
| POST   | `/api/orders/:id/cancel`  | Cancel order |
| POST   | `/api/orders/:id/rate`    | Rate order   |
| POST   | `/api/orders/:id/reorder` | Reorder      |

### Subscriptions

| Method | Endpoint                        | Description         |
| ------ | ------------------------------- | ------------------- |
| GET    | `/api/subscriptions`            | User subscriptions  |
| POST   | `/api/subscriptions`            | Create subscription |
| GET    | `/api/subscriptions/:id`        | Get subscription    |
| POST   | `/api/subscriptions/:id/pause`  | Pause               |
| POST   | `/api/subscriptions/:id/resume` | Resume              |
| POST   | `/api/subscriptions/:id/cancel` | Cancel              |
| POST   | `/api/subscriptions/:id/skip`   | Skip delivery       |

### Meal Plans

| Method | Endpoint                           | Description      |
| ------ | ---------------------------------- | ---------------- |
| GET    | `/api/meal-plans`                  | List meal plans  |
| GET    | `/api/meal-plans/featured`         | Featured plans   |
| GET    | `/api/meal-plans/:id`              | Get plan         |
| POST   | `/api/meal-plans/:id/subscribe`    | Subscribe        |
| GET    | `/api/meal-plans/subscriptions/me` | My subscriptions |

### Reviews

| Method | Endpoint                | Description   |
| ------ | ----------------------- | ------------- |
| GET    | `/api/reviews`          | Get reviews   |
| POST   | `/api/reviews`          | Create review |
| PUT    | `/api/reviews/:id`      | Update review |
| DELETE | `/api/reviews/:id`      | Delete review |
| POST   | `/api/reviews/:id/vote` | Vote helpful  |

### Coupons

| Method | Endpoint                  | Description    |
| ------ | ------------------------- | -------------- |
| GET    | `/api/coupons`            | Active coupons |
| POST   | `/api/coupons/apply`      | Apply coupon   |
| GET    | `/api/coupons/code/:code` | Get by code    |

### Payments

| Method | Endpoint                   | Description      |
| ------ | -------------------------- | ---------------- |
| POST   | `/api/payments/initiate`   | Initiate payment |
| POST   | `/api/payments/callback`   | Payment webhook  |
| GET    | `/api/payments/status/:id` | Check status     |
| POST   | `/api/payments/:id/refund` | Request refund   |

### Notifications

| Method | Endpoint                         | Description        |
| ------ | -------------------------------- | ------------------ |
| GET    | `/api/notifications`             | Get notifications  |
| POST   | `/api/notifications/:id/read`    | Mark as read       |
| POST   | `/api/notifications/read-all`    | Read all           |
| GET    | `/api/notifications/preferences` | Get preferences    |
| PUT    | `/api/notifications/preferences` | Update preferences |

### Favorites

| Method | Endpoint                | Description   |
| ------ | ----------------------- | ------------- |
| GET    | `/api/favorites`        | Get favorites |
| POST   | `/api/favorites`        | Add favorite  |
| DELETE | `/api/favorites/:id`    | Remove        |
| POST   | `/api/favorites/toggle` | Toggle        |

### Support

| Method | Endpoint                 | Description   |
| ------ | ------------------------ | ------------- |
| GET    | `/api/support`           | User tickets  |
| POST   | `/api/support`           | Create ticket |
| GET    | `/api/support/:id`       | Get ticket    |
| POST   | `/api/support/:id/reply` | Reply         |
| POST   | `/api/support/:id/close` | Close ticket  |

### Search

| Method | Endpoint              | Description             |
| ------ | --------------------- | ----------------------- |
| GET    | `/api/search`         | Search products/vendors |
| GET    | `/api/search/suggest` | Autocomplete            |
| GET    | `/api/search/popular` | Popular searches        |

### Delivery Zones

| Method | Endpoint                          | Description          |
| ------ | --------------------------------- | -------------------- |
| GET    | `/api/delivery-zones`             | List zones           |
| POST   | `/api/delivery-zones/check`       | Check serviceability |
| GET    | `/api/delivery-zones/:id/vendors` | Vendors in zone      |

### Banners

| Method | Endpoint                 | Description   |
| ------ | ------------------------ | ------------- |
| GET    | `/api/banners`           | Get banners   |
| GET    | `/api/banners/all`       | All positions |
| POST   | `/api/banners/:id/click` | Track click   |

## Authentication

Include phone number in headers:

```
x-user-phone: +919876543210
```

## Response Format

```json
{
  "success": true,
  "message": "Success",
  "data": { ... }
}
```

Error:

```json
{
  "success": false,
  "message": "Error message",
  "errors": [ ... ]
}
```

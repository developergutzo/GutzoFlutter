import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import dotenv from 'dotenv';

// Get the directory path for ES Modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load .env from project root (one level up from src/)
dotenv.config({ path: join(__dirname, '..', '.env') });

// Import routes
import authRoutes from './routes/auth.js';
import userRoutes from './routes/users.js';
import vendorRoutes from './routes/vendors.js';
import productRoutes from './routes/products.js';
import categoryRoutes from './routes/categories.js';
import cartRoutes from './routes/cart.js';
import orderRoutes from './routes/orders.js';
import subscriptionRoutes from './routes/subscriptions.js';
import mealPlanRoutes from './routes/mealPlans.js';
import reviewRoutes from './routes/reviews.js';
import couponRoutes from './routes/coupons.js';
import paymentRoutes from './routes/payments.js';
import notificationRoutes from './routes/notifications.js';
import favoriteRoutes from './routes/favorites.js';
import supportRoutes from './routes/support.js';
import searchRoutes from './routes/search.js';
import deliveryZoneRoutes from './routes/deliveryZones.js';
import bannerRoutes from './routes/banners.js';
import deliveryRoutes from './routes/delivery.js';
import vendorLeadsRoutes from './routes/vendorLeads.js';
import vendorAuthRoutes from './routes/vendorAuth.js'; // [NEW]
import uploadRoutes from './routes/upload.js'; // [NEW]
import shadowfaxRoutes from './routes/shadowfax.js'; // [NEW]
import mealTemplateRoutes from './routes/mealTemplates.js'; // [NEW]
import mealCalendarRoutes from './routes/mealCalendar.js'; // [NEW]

// Import middleware
import { errorHandler, notFound } from './middleware/errorHandler.js';

// Import and start cron services
import './utils/deliveryCronService.js'; // Auto-starts delivery status sync cron

const app = express();
const PORT = process.env.PORT;

// Trust proxy
app.use(cors({
  origin: function (origin, callback) {
    const allowedOrigins = [
      'http://localhost:8000',
      'https://192-168-1-36.nip.io',
      'http://localhost:3000',
      'http://localhost:3001',
      'http://192.168.1.36:3000',
      'http://192.168.1.36:3001',
      'http://10.128.0.3:3000',
      'http://10.128.0.3:3001',
      'https://gutzo.in',
      'https://www.gutzo.in',
      'https://api.gutzo.in',
      'http://localhost',       // Android Capacitor default
      'https://localhost',      // Android Capacitor (HTTPS scheme)
      'capacitor://localhost'   // iOS Capacitor default
    ];
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);

    if (allowedOrigins.indexOf(origin) === -1) {
      if (process.env.NODE_ENV === 'development') {
        // console.log('⚠️ CORS Warning: Origin not in allow list but allowed in DEV:', origin);
        return callback(null, true);
      }

      console.error('❌ CORS Error: Blocked Origin:', origin);
      const msg = 'The CORS policy for this site does not allow access from the specified Origin.';
      return callback(new Error(msg), false);
    }
    return callback(null, true);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  //allowedHeaders: ['Content-Type', 'Authorization', 'x-user-phone', 'x-vendor-id', 'x-admin-key']
  allowedHeaders: '*'
}));

// Security
app.use(helmet());

// DEBUG: Log Origin (Simplified)
app.use((req, res, next) => {
  // console.log('DEBUG: Incoming Request:', req.method, req.path);
  // console.log('DEBUG: Origin Header:', req.headers.origin);
  next();
});

// Trust proxy (required for correct IP detection behind Caddy/Nginx)
app.set('trust proxy', 1);

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 2000, // Increased for dev/testing
  message: { success: false, message: 'Too many requests, please try again later.' },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});
app.use('/api/', limiter);

// Stricter limit for OTP
const otpLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10, // Increased for dev/testing
  message: { success: false, message: 'Too many OTP requests. Wait 1 minute.' }
});
app.use('/api/auth/send-otp', otpLimiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging
app.use(morgan(process.env.NODE_ENV === 'development' ? 'dev' : 'combined'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: 'Gutzo API is running',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: process.env.NODE_ENV
  });
});

// ============================================
// API ROUTES
// ============================================
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/vendors', vendorRoutes);
app.use('/api/products', productRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/meal-plans', mealPlanRoutes);
app.use('/api/meal-templates', mealTemplateRoutes);
app.use('/api/meal-calendar', mealCalendarRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/coupons', couponRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/favorites', favoriteRoutes);
app.use('/api/support', supportRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/delivery-zones', deliveryZoneRoutes);
app.use('/api/banners', bannerRoutes);
app.use('/api/delivery', deliveryRoutes);
app.use('/api/vendor-leads', vendorLeadsRoutes);
app.use('/api/vendor-auth', vendorAuthRoutes);
app.use('/api/upload', uploadRoutes); // [NEW]
app.use('/api/shadowfax', shadowfaxRoutes); // [NEW]


// 404 handler
app.use(notFound);

// Error handler
app.use(errorHandler);

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔═══════════════════════════════════════════════╗
║       🍽️  GUTZO API SERVER STARTED  🍽️         ║
╠═══════════════════════════════════════════════╣
║  Port:        ${PORT}                              ║
║  Environment: ${(process.env.NODE_ENV).padEnd(28)}║
║  Health:      http://localhost:${PORT}/api/health   ║
╚═══════════════════════════════════════════════╝
  `);
});

export default app;

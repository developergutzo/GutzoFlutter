import Joi from 'joi';
import { ApiError } from './errorHandler.js';

// Validation middleware factory
export const validate = (schema, property = 'body') => (req, res, next) => {
  const { error, value } = schema.validate(req[property], {
    abortEarly: false,
    stripUnknown: true
  });

  if (error) {
    const errors = error.details.map(d => ({
      field: d.path.join('.'),
      message: d.message.replace(/"/g, '')
    }));
    throw new ApiError(400, 'Validation failed', errors);
  }

  req[property] = value;
  next();
};

// ============================================
// VALIDATION SCHEMAS
// ============================================

// Common patterns
const phonePattern = /^\+91[6-9]\d{9}$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const schemas = {
  // ========== AUTH ==========
  sendOtp: Joi.object({
    phone: Joi.string().pattern(phonePattern).required()
      .messages({ 'string.pattern.base': 'Invalid phone. Use format: +919876543210' })
  }),

  verifyOtp: Joi.object({
    phone: Joi.string().pattern(phonePattern).required(),
    otp: Joi.string().length(6).pattern(/^\d+$/).required()
      .messages({ 'string.pattern.base': 'OTP must be 6 digits' })
  }),

  // ========== USER ==========
  updateUser: Joi.object({
    name: Joi.string().min(2).max(100),
    email: Joi.string().email(),
    profile_image: Joi.string().uri(),
    date_of_birth: Joi.date().max('now'),
    gender: Joi.string().valid('male', 'female', 'other'),
    language_preference: Joi.string().valid('en', 'ta', 'hi'),
    dietary_preference: Joi.array().items(Joi.string()),
    allergies: Joi.array().items(Joi.string()),
    health_goals: Joi.array().items(Joi.string())
  }),

  // ========== ADDRESS ==========
  createAddress: Joi.object({
    label: Joi.string().valid('Home', 'Work', 'Other').required(),
    custom_label: Joi.string().max(50).when('label', { is: 'Other', then: Joi.required() }),
    street: Joi.string().max(200).required(),
    area: Joi.string().max(200).required(),
    landmark: Joi.string().max(200).allow(''),
    full_address: Joi.string().max(500).allow(''),
    city: Joi.string().default(''),
    state: Joi.string().default(''),
    zipcode: Joi.string().pattern(/^\d{6}$/).required(),
    latitude: Joi.number().min(-90).max(90),
    longitude: Joi.number().min(-180).max(180),
    delivery_notes: Joi.string().max(500).allow(''),
    is_default: Joi.boolean().default(false)
  }),

  // ========== CART ==========
  addToCart: Joi.object({
    product_id: Joi.string().pattern(uuidPattern).required(),
    vendor_id: Joi.string().pattern(uuidPattern).required(),
    variant_id: Joi.string().pattern(uuidPattern),
    quantity: Joi.number().integer().min(1).max(20).default(1),
    addons: Joi.array().items(Joi.object({
      addon_id: Joi.string().pattern(uuidPattern).required(),
      quantity: Joi.number().integer().min(1).max(5).default(1)
    })),
    special_instructions: Joi.string().max(200),
    metadata: Joi.object().unknown()
  }),

  updateCartItem: Joi.object({
    quantity: Joi.number().integer().min(0).max(20).required(),
    addons: Joi.array().items(Joi.object({
      addon_id: Joi.string().pattern(uuidPattern).required(),
      quantity: Joi.number().integer().min(1).max(5).default(1)
    })),
    special_instructions: Joi.string().max(200),
    metadata: Joi.object().unknown()
  }),

  // ========== ORDER ==========
    createOrder: Joi.object({
    vendor_id: Joi.string().pattern(uuidPattern).required(),
    items: Joi.array().items(Joi.object({
      product_id: Joi.string().pattern(uuidPattern).required(),
      variant_id: Joi.string().pattern(uuidPattern),
      quantity: Joi.number().integer().min(1).required(),
      addons: Joi.array().items(Joi.object({
        addon_id: Joi.string().pattern(uuidPattern).required(),
        quantity: Joi.number().integer().min(1).default(1)
      })),
      special_instructions: Joi.string().max(200)
    })).min(1).required(),
    delivery_address: Joi.object().required(),
    delivery_phone: Joi.string().required(),
    coupon_code: Joi.string().uppercase(),
    tip_amount: Joi.number().min(0).default(0),
    special_instructions: Joi.string().max(500).allow(''),
    payment_method: Joi.string().valid('upi', 'card', 'wallet', 'cod').required(),
    order_source: Joi.string().valid('app', 'web', 'whatsapp', 'subscription').default('app'),
    // Fee overrides (optional, for syncing with frontend calculations)
    delivery_fee: Joi.number().min(0),
    platform_fee: Joi.number().min(0),
    packaging_fee: Joi.number().min(0),
    taxes: Joi.number().min(0),
    discount_amount: Joi.number().min(0),
    mock_shadowfax: Joi.boolean()
  }),

  // ========== SUBSCRIPTION ==========
  createSubscription: Joi.object({
    vendor_id: Joi.string().pattern(uuidPattern).required(),
    products: Joi.array().items(Joi.object({
      product_id: Joi.string().pattern(uuidPattern).required(),
      quantity: Joi.number().integer().min(1).default(1)
    })).min(1).required(),
    frequency: Joi.string().valid('daily', 'weekly', 'monthly', 'custom').required(),
    delivery_days: Joi.array().items(Joi.number().integer().min(0).max(6)).min(1).required(),
    delivery_time: Joi.string().required(),
    start_date: Joi.date().min('now').required(),
    end_date: Joi.date().greater(Joi.ref('start_date')),
    delivery_address: Joi.object().required(),
    auto_renew: Joi.boolean().default(false)
  }),

  // ========== MEAL PLAN ==========
  subscribeMealPlan: Joi.object({
    meal_plan_id: Joi.string().pattern(uuidPattern).required(),
    chosen_meals: Joi.array().items(Joi.string().valid('breakfast', 'lunch', 'dinner', 'snacks')).min(1).required(),
    chosen_days: Joi.array().items(Joi.number().integer().min(0).max(6)).min(1).required(),
    custom_times: Joi.object(),
    duration: Joi.string().valid('Trial Week', '1 Month', '3 Months').required(),
    start_date: Joi.date().min('now').required(),
    delivery_address: Joi.object().required()
  }),

  // ========== REVIEW ==========
  createReview: Joi.object({
    vendor_id: Joi.string().pattern(uuidPattern).required(),
    product_id: Joi.string().pattern(uuidPattern),
    order_id: Joi.string().pattern(uuidPattern),
    rating: Joi.number().integer().min(1).max(5).required(),
    comment: Joi.string().max(1000),
    images: Joi.array().items(Joi.string().uri()).max(5)
  }),

  // ========== COUPON ==========
  applyCoupon: Joi.object({
    code: Joi.string().uppercase().required(),
    vendor_id: Joi.string().pattern(uuidPattern),
    order_total: Joi.number().min(0).required()
  }),

  // ========== SUPPORT ==========
  createTicket: Joi.object({
    order_id: Joi.string().pattern(uuidPattern),
    subject: Joi.string().min(5).max(200).required(),
    description: Joi.string().min(10).max(2000).required(),
    category: Joi.string().valid('order', 'payment', 'delivery', 'refund', 'other').required(),
    priority: Joi.string().valid('low', 'medium', 'high').default('medium'),
    attachments: Joi.array().items(Joi.string().uri()).max(5)
  }),

  // ========== PAGINATION ==========
  pagination: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(20),
    sort: Joi.string(),
    order: Joi.string().valid('asc', 'desc').default('desc')
  }),

  // ========== UUID PARAM ==========
  uuidParam: Joi.object({
    id: Joi.string().pattern(uuidPattern).required()
  })
};

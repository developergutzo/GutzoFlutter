import { supabaseAdmin } from '../config/supabase.js';
import { ApiError } from './errorHandler.js';

// Authenticate user by phone number (from header)
export const authenticate = async (req, res, next) => {
  try {
    const phone = req.headers['x-user-phone'];
    
    if (!phone) {
      throw new ApiError(401, 'Authentication required. Provide x-user-phone header.');
    }

    // Verify user exists and is verified
    const { data: user, error } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('phone', phone)
      .eq('verified', true)
      .single();

    if (error || !user) {
      throw new ApiError(401, 'User not found or not verified. Please login first.');
    }

    if (user.is_blocked) {
      throw new ApiError(403, `Account blocked: ${user.blocked_reason || 'Contact support'}`);
    }

    // Update last login
    await supabaseAdmin
      .from('users')
      .update({ last_login_at: new Date().toISOString() })
      .eq('id', user.id);

    req.user = user;
    next();
  } catch (error) {
    next(error instanceof ApiError ? error : new ApiError(401, error.message));
  }
};

// Optional auth - doesn't fail if no user, just attaches if available
export const optionalAuth = async (req, res, next) => {
  try {
    const phone = req.headers['x-user-phone'];
    
    if (phone) {
      const { data: user } = await supabaseAdmin
        .from('users')
        .select('*')
        .eq('phone', phone)
        .eq('verified', true)
        .single();

      if (user && !user.is_blocked) {
        req.user = user;
      }
    }
    next();
  } catch (error) {
    // Silently continue without user
    next();
  }
};

// Authenticate vendor by vendor_id header
export const authenticateVendor = async (req, res, next) => {
  try {
    const vendorId = req.headers['x-vendor-id'];
    
    if (!vendorId) {
      throw new ApiError(401, 'Vendor authentication required. Provide x-vendor-id header.');
    }

    const { data: vendor, error } = await supabaseAdmin
      .from('vendors')
      .select('*')
      .eq('id', vendorId)
      .eq('is_active', true)
      .single();

    if (error || !vendor) {
      throw new ApiError(401, 'Vendor not found or inactive');
    }

    if (vendor.status === 'suspended') {
      throw new ApiError(403, 'Vendor account suspended');
    }

    req.vendor = vendor;
    next();
  } catch (error) {
    next(error instanceof ApiError ? error : new ApiError(401, error.message));
  }
};

// Admin middleware (for future admin panel)
export const authenticateAdmin = async (req, res, next) => {
  try {
    const adminKey = req.headers['x-admin-key'];
    
    if (!adminKey || adminKey !== process.env.ADMIN_SECRET_KEY) {
      throw new ApiError(403, 'Admin access denied');
    }

    next();
  } catch (error) {
    next(error);
  }
};

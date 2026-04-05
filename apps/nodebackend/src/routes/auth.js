import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { validate, schemas } from '../middleware/validate.js';

const router = express.Router();

// ============================================
// SEND OTP VIA WHATSAPP
// POST /api/auth/send-otp
// ============================================
router.post('/send-otp', validate(schemas.sendOtp), asyncHandler(async (req, res) => {
  const { phone } = req.body;



  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();

  // Set expiration time (5 minutes from now)
  const expiresAt = new Date();
  expiresAt.setMinutes(expiresAt.getMinutes() + 5);

  // Store OTP in database using upsert
  const { error: dbError } = await supabaseAdmin
    .from('otp_verification')
    .upsert({
      phone,
      otp,
      expires_at: expiresAt.toISOString(),
      verified: false,
      attempts: 0,
      created_at: new Date().toISOString()
    }, {
      onConflict: 'phone'
    });

  if (dbError) {
    console.error('Database error storing OTP:', dbError);
    throw new ApiError(500, 'Failed to store OTP', dbError.message);
  }

  // Get WhatsApp credentials
  const whatsappToken = process.env.WHATSAPP_ACCESS_TOKEN;
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;

  if (!whatsappToken || !phoneNumberId) {
    console.error('Missing WhatsApp environment variables');

    // In development, still return success with OTP for testing
    if (process.env.NODE_ENV === 'development') {
      // console.log(`[DEV] OTP for ${phone}: ${otp}`);
      return successResponse(res, {
        phone,
        message: 'OTP generated (WhatsApp not configured)',
        otp, // Only in development!
        expiresIn: 300
      }, 'OTP generated successfully');
    }

    throw new ApiError(500, 'WhatsApp service not configured');
  }

  // WhatsApp message payload using template
  const whatsappMessage = {
    messaging_product: 'whatsapp',
    to: phone.replace('+', ''),
    type: 'template',
    template: {
      name: 'signincode',
      language: { code: 'en_US' },
      components: [
        {
          type: 'body',
          parameters: [
            { type: 'text', text: otp }
          ]
        },
        {
          type: 'button',
          sub_type: 'url',
          index: '0',
          parameters: [
            { type: 'text', text: otp }
          ]
        }
      ]
    }
  };

  // Send WhatsApp message via Facebook Graph API
  try {
    const whatsappResponse = await fetch(
      `https://graph.facebook.com/v22.0/${phoneNumberId}/messages`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${whatsappToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(whatsappMessage)
      }
    );

    if (!whatsappResponse.ok) {
      const errorText = await whatsappResponse.text();
      console.error('WhatsApp API error:', {
        status: whatsappResponse.status,
        error: errorText
      });
      throw new ApiError(500, `WhatsApp API error (${whatsappResponse.status}): ${errorText}`);
    }

    const whatsappResult = await whatsappResponse.json();

    successResponse(res, {
      phone,
      message: 'OTP sent successfully via WhatsApp',
      whatsappResult, // Return the raw result for debugging
      expiresIn: 300
    }, 'OTP sent to your WhatsApp');

  } catch (fetchError) {
    console.error('WhatsApp fetch error:', fetchError);
    throw new ApiError(500, 'Failed to send WhatsApp message');
  }
}));

// ============================================
// VERIFY OTP
// POST /api/auth/verify-otp
// ============================================
router.post('/verify-otp', validate(schemas.verifyOtp), asyncHandler(async (req, res) => {
  const { phone, otp } = req.body;



  // Query for matching OTP record
  const { data: otpRecord, error: queryError } = await supabaseAdmin
    .from('otp_verification')
    .select('*')
    .eq('phone', phone)
    .eq('otp', otp)
    .eq('verified', false)
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  if (queryError && queryError.code !== 'PGRST116') {
    console.error('Database error querying OTP:', queryError);
    throw new ApiError(500, 'Failed to verify OTP');
  }

  if (!otpRecord) {
    throw new ApiError(400, 'Invalid or expired OTP');
  }

  // Check if OTP has expired
  const now = new Date();
  const expirationTime = new Date(otpRecord.expires_at);

  if (now > expirationTime) {
    throw new ApiError(400, 'OTP has expired. Please request a new one.');
  }

  // Mark OTP as verified
  const { error: updateError } = await supabaseAdmin
    .from('otp_verification')
    .update({
      verified: true,
      verified_at: new Date().toISOString()
    })
    .eq('id', otpRecord.id);

  if (updateError) {
    console.error('Database error updating OTP:', updateError);
    throw new ApiError(500, 'Failed to verify OTP');
  }

  // Check if user exists
  let { data: user, error: userError } = await supabaseAdmin
    .from('users')
    .select('*')
    .eq('phone', phone)
    .single();

  let isNewUser = false;

  if (userError && userError.code === 'PGRST116') {
    // User doesn't exist - create new user
    isNewUser = true;
    const referralCode = `GZ${phone.slice(-6)}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;

    const { data: newUser, error: createError } = await supabaseAdmin
      .from('users')
      .insert({
        phone,
        verified: true,
        referral_code: referralCode,
        membership_tier: 'bronze',
        loyalty_points: 0,
        total_orders: 0,
        total_spent: 0,
        created_at: new Date().toISOString()
      })
      .select()
      .single();

    if (createError) {
      console.error('Failed to create user:', createError);
      throw new ApiError(500, 'Failed to create user account');
    }
    user = newUser;
  } else if (userError) {
    console.error('Database error checking user:', userError);
    throw new ApiError(500, 'Database error');
  } else {
    // Update existing user
    await supabaseAdmin
      .from('users')
      .update({
        verified: true,
        last_login_at: new Date().toISOString()
      })
      .eq('phone', phone);
  }



  successResponse(res, {
    user,
    isNewUser,
    message: isNewUser ? 'Account created successfully!' : 'Welcome back!'
  }, 'OTP verified successfully');
}));

// ============================================
// CHECK USER EXISTS
// POST /api/auth/check-user
// ============================================
router.post('/check-user', asyncHandler(async (req, res) => {
  const { phone } = req.body;

  if (!phone) {
    throw new ApiError(400, 'Phone number is required');
  }



  const { data: user, error } = await supabaseAdmin
    .from('users')
    .select('id, phone, name, email, created_at')
    .eq('phone', phone)
    .single();

  if (error && error.code !== 'PGRST116') {
    console.error('Database error checking user:', error);
    throw new ApiError(500, 'Failed to check user');
  }

  const exists = !!user;


  successResponse(res, {
    exists,
    user: exists ? user : null
  });
}));

// ============================================
// VALIDATE USER
// POST /api/auth/validate-user
// ============================================
router.post('/validate-user', asyncHandler(async (req, res) => {
  const { phone } = req.body;

  if (!phone) {
    throw new ApiError(400, 'Phone number is required');
  }



  const { data: user, error } = await supabaseAdmin
    .from('users')
    .select('verified')
    .eq('phone', phone)
    .single();

  if (error) {
    if (error.code === 'PGRST116') {
      // console.log(`❌ User not found for phone: ${phone}`);
      return successResponse(res, { userExists: false, verified: false });
    }
    throw new ApiError(500, 'Database validation failed');
  }

  const userExists = !!user;
  const verified = user?.verified || false;



  successResponse(res, { userExists, verified });
}));

// ============================================
// CREATE USER (After OTP verification)
// POST /api/auth/create-user
// ============================================
router.post('/create-user', asyncHandler(async (req, res) => {
  const { phone, name, email } = req.body;

  // Email is optional for phone-first auth
  if (!phone) {
    throw new ApiError(400, 'Phone number is required');
  }



  // Check if user already exists - if so, return them (idempotent)
  const { data: existingUser } = await supabaseAdmin
    .from('users')
    .select('*')
    .eq('phone', phone)
    .single();

  if (existingUser) {
    // If user exists, update their profile with provided name/email (if new ones match signup intent)
    // This fixes the issue where verify-otp creates a shell user and create-user was ignoring the name payload
    const updates = {};
    if (name) updates.name = name;
    if (email) updates.email = email;

    if (Object.keys(updates).length > 0) {
      const { data: updatedUser, error: updateError } = await supabaseAdmin
        .from('users')
        .update(updates)
        .eq('phone', phone)
        .select()
        .single();

      if (!updateError && updatedUser) {
        return successResponse(res, { user: updatedUser }, 'User profile updated', 200);
      }
    }

    // console.log('User already exists, returning existing profile:', phone);
    return successResponse(res, { user: existingUser }, 'User already exists', 200);
  }

  // Generate referral code
  const referralCode = `GZ${phone.slice(-6)}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;

  // Create user
  const { data: newUser, error: createError } = await supabaseAdmin
    .from('users')
    .insert({
      phone,
      name: name || 'User', // Default name
      email: email || null, // Optional email
      verified: true,
      referral_code: referralCode,
      membership_tier: 'bronze',
      loyalty_points: 0,
      total_orders: 0,
      total_spent: 0,
      created_at: new Date().toISOString()
    })
    .select()
    .single();

  if (createError) {
    console.error('Failed to create user:', createError);
    throw new ApiError(500, 'Failed to create user');
  }



  successResponse(res, { user: newUser }, 'Account created successfully', 201);
}));

// ============================================
// CHECK AUTH STATUS
// GET /api/auth/status
// ============================================
router.get('/status', asyncHandler(async (req, res) => {
  const phone = req.headers['x-user-phone'];

  if (!phone) {
    return successResponse(res, { isAuthenticated: false });
  }

  const { data: user } = await supabaseAdmin
    .from('users')
    .select('*')
    .eq('phone', phone)
    .eq('verified', true)
    .single();

  if (!user) {
    return successResponse(res, { isAuthenticated: false });
  }

  successResponse(res, { isAuthenticated: true, user });
}));

// ============================================
// LOGOUT
// POST /api/auth/logout
// ============================================
router.post('/logout', asyncHandler(async (req, res) => {
  const phone = req.headers['x-user-phone'];

  if (phone) {
    await supabaseAdmin
      .from('otp_verification')
      .update({ verified: false })
      .eq('phone', phone);
  }

  successResponse(res, null, 'Logged out successfully');
}));

export default router;

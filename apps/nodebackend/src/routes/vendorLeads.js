import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import { sendVendorLeadNotification, sendVendorAcknowledgment } from '../utils/emailService.js';

const router = express.Router();

// ============================================
// CREATE VENDOR LEAD
// POST /api/vendor-leads
// ============================================
router.post('/', asyncHandler(async (req, res) => {
  const { kitchen_name, contact_name, phone, email, city, food_type } = req.body;

  // Detailed Validation
  if (!kitchen_name || kitchen_name.length < 3) {
    throw new ApiError(400, 'Kitchen Name must be at least 3 characters.');
  }

  const nameRegex = /^[a-zA-Z\s]+$/;
  if (!contact_name || contact_name.length < 3 || !nameRegex.test(contact_name)) {
    throw new ApiError(400, 'Contact Name must be at least 3 characters and contain only letters.');
  }

  // Basic Phone Cleaning & Validation (assuming 10 digits for India)
  const phoneRegex = /^[6-9]\d{9}$/;
  const cleanPhone = phone ? phone.replace(/\D/g, '').slice(-10) : '';
  if (!cleanPhone || !phoneRegex.test(cleanPhone)) {
    throw new ApiError(400, 'Please provide a valid 10-digit mobile number.');
  }

  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  if (!email || !emailRegex.test(email)) {
    throw new ApiError(400, 'Valid email address is required.');
  }

  if (!city) {
    throw new ApiError(400, 'City is required.');
  }

  if (!food_type || food_type.length < 10) {
    throw new ApiError(400, 'Food Type must be at least 10 characters.');
  }

  // Insert into DB
  const { data: lead, error } = await supabaseAdmin
    .from('vendor_leads')
    .insert({
      kitchen_name,
      contact_name,
      phone,
      email,
      city,
      food_type,
      status: 'open'
    })
    .select()
    .single();

  if (error) {
    console.error('DB Insert Error:', error);
    throw new ApiError(500, 'Failed to save vendor lead');
  }

  // Trigger Email Notification (Non-blocking)
  sendVendorLeadNotification(lead).catch(err => console.error('Email trigger failed', err));
  if (email) {
    sendVendorAcknowledgment(lead).catch(err => console.error('Ack Email trigger failed', err));
  }

  successResponse(res, lead, 'Thank you! We will contact you shortly.', 201);
}));

export default router;

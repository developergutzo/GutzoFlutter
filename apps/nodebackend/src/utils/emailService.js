import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

// Create reusable transporter object using the default SMTP transport
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
});

/**
 * Send notification email to Gutzo Ops about a new vendor lead
 * @param {Object} leadData - The vendor lead data
 * @returns {Promise<void>}
 */
export const sendVendorLeadNotification = async (leadData) => {
  const { kitchen_name, contact_name, phone, email, city, food_type } = leadData;

  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: process.env.OPS_EMAIL,
    subject: `🚨 New Vendor Interest: ${kitchen_name}`,
    html: `
      <h2>New Vendor Lead Received</h2>
      <p><strong>Kitchen Name:</strong> ${kitchen_name}</p>
      <p><strong>Contact Person:</strong> ${contact_name}</p>
      <p><strong>Phone:</strong> <a href="tel:${phone}">${phone}</a></p>
      <p><strong>Email:</strong> <a href="mailto:${email}">${email}</a></p>
      <p><strong>City:</strong> ${city}</p>
      <p><strong>Food Type:</strong> ${food_type}</p>
      <hr />
      <p>Please review this lead in the database and contact them shortly.</p>
    `
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('📧 Lead notification email sent:', info.messageId);
  } catch (error) {
    console.error('❌ Error sending lead notification email:', error);
    // Don't throw, so we don't block the API response if email fails (it's secondary to DB save)
  }
};

/**
 * Send acknowledgment email to the vendor
 * @param {Object} leadData - The vendor lead data
 * @returns {Promise<void>}
 */
export const sendVendorAcknowledgment = async (leadData) => {
  const { kitchen_name, contact_name, phone, email, city } = leadData;

  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: "Thank you for your interest in partnering with Gutzo",
    html: `
      <h2>We received your request!</h2>
      <p>Hi ${contact_name},</p>
      <p>Thank you for expressing interest in becoming a specialized kitchen partner with Gutzo.</p>
      <p>Our team will review your details and get back to you shortly.</p>
      <br>
      <p><strong>Your Details:</strong></p>
      <ul>
        <li><strong>Kitchen Name:</strong> ${kitchen_name}</li>
        <li><strong>Phone:</strong> ${phone}</li>
        <li><strong>City:</strong> ${city}</li>
      </ul>
      <br>
      <p>Best regards,</p>
      <p><strong>The Gutzo Team</strong></p>
    `,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log("📧 Vendor acknowledgment email sent:", info.messageId);
  } catch (error) {
    console.error("❌ Error sending vendor acknowledgment email:", error);
    // Don't throw here to avoid failing the whole request if just the ack email fails
  }
};

/**
 * Send OTP email to vendor for password reset
 * @param {string} email - Vendor email
 * @param {string} otp - The OTP code
 * @returns {Promise<void>}
 */
export const sendVendorOTP = async (email, otp) => {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: "Gutzo Partner Code: Your One-Time Password",
    html: `
      <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
        <h2>Password Reset Request</h2>
        <p>Use the code below to reset your partner portal password.</p>
        <div style="background: #f4f4f4; padding: 15px; border-radius: 8px; text-align: center; margin: 20px 0;">
          <h1 style="color: #1BA672; margin: 0; letter-spacing: 5px;">${otp}</h1>
        </div>
        <p>This code will expire in 5 minutes.</p>
        <p style="color: #666; font-size: 12px; margin-top: 30px;">If you didn't request this, please ignore this email.</p>
      </div>
    `
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log("📧 Vendor OTP email sent:", info.messageId);
  } catch (error) {
    console.error("❌ Error sending vendor OTP email:", error);
    throw new Error("Failed to send OTP email");
  }
};

/**
 * Send New Order Notification to Vendor
 * @param {string} email - Vendor email
 * @param {Object} order - Order details
 * @returns {Promise<void>}
 */
export const sendVendorOrderNotification = async (email, order) => {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: `🔔 New Order #${order.order_number} Received!`,
    html: `
      <div style="font-family: Arial, sans-serif; color: #333;">
        <h2 style="color: #1BA672;">New Order Received!</h2>
        <p>You have a new order to prepare.</p>
        
        <div style="background: #f9f9f9; padding: 15px; border-radius: 8px; margin: 15px 0;">
          <p><strong>Order ID:</strong> #${order.order_number}</p>
          <p><strong>Items:</strong> ${order.items ? order.items.length : 'Check App'}</p>
          <p><strong>Total:</strong> ₹${order.total_amount}</p>
        </div>

        <a href="https://partner.gutzo.in/orders" style="display: inline-block; background: #1BA672; color: #fff; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Order</a>
      </div>
    `
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`📧 Vendor Order Notification sent to ${email}:`, info.messageId);
  } catch (error) {
    console.error("❌ Error sending vendor order notification:", error);
  }
};

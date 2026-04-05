import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, paginatedResponse, ApiError } from '../middleware/errorHandler.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticate);

// CREATE SUPPORT TICKET
router.post('/', asyncHandler(async (req, res) => {
  const { order_id, subject, description, category, priority = 'medium', attachments } = req.body;

  if (!subject || !description || !category) {
    throw new ApiError(400, 'Subject, description, and category required');
  }

  const { data: ticket, error } = await supabaseAdmin
    .from('support_tickets')
    .insert({
      user_id: req.user.id, order_id, subject, description, category, priority,
      attachments: attachments || [], status: 'open'
    })
    .select().single();

  if (error) throw new ApiError(500, 'Failed to create ticket');

  successResponse(res, ticket, 'Ticket created. We will respond within 24 hours.', 201);
}));

// GET USER TICKETS
router.get('/', asyncHandler(async (req, res) => {
  const { status, page = 1, limit = 20 } = req.query;

  let query = supabaseAdmin
    .from('support_tickets')
    .select('*, order:orders(order_number, vendor_name)', { count: 'exact' })
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false });

  if (status) query = query.eq('status', status);

  const from = (page - 1) * limit;
  query = query.range(from, from + limit - 1);

  const { data, error, count } = await query;
  if (error) throw new ApiError(500, 'Failed to fetch tickets');

  paginatedResponse(res, data, page, limit, count);
}));

// GET TICKET BY ID
router.get('/:id', asyncHandler(async (req, res) => {
  const { data: ticket, error } = await supabaseAdmin
    .from('support_tickets')
    .select('*, order:orders(*)')
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !ticket) throw new ApiError(404, 'Ticket not found');
  successResponse(res, ticket);
}));

// ADD REPLY TO TICKET
router.post('/:id/reply', asyncHandler(async (req, res) => {
  const { message, attachments } = req.body;
  if (!message) throw new ApiError(400, 'Message required');

  // Verify ownership
  const { data: ticket } = await supabaseAdmin
    .from('support_tickets')
    .select('id, description')
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .single();

  if (!ticket) throw new ApiError(404, 'Ticket not found');

  // Append to description (simple approach - could use separate replies table)
  const updatedDescription = `${ticket.description}\n\n--- User Reply (${new Date().toISOString()}) ---\n${message}`;

  const { data, error } = await supabaseAdmin
    .from('support_tickets')
    .update({ 
      description: updatedDescription, 
      status: 'open',
      updated_at: new Date().toISOString() 
    })
    .eq('id', req.params.id)
    .select().single();

  if (error) throw new ApiError(500, 'Failed to add reply');
  successResponse(res, data, 'Reply added');
}));

// CLOSE TICKET
router.post('/:id/close', asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('support_tickets')
    .update({ status: 'closed', resolved_at: new Date().toISOString() })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .select().single();

  if (error) throw new ApiError(400, 'Cannot close ticket');
  successResponse(res, data, 'Ticket closed');
}));

export default router;

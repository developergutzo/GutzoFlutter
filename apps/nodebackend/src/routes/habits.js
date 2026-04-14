import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { authenticate } from '../middleware/auth.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import axios from 'axios';

const router = express.Router();
router.use(authenticate);

const SHADOWFAX_BASE_URL = process.env.SHADOWFAX_API_URL;
const SHADOWFAX_TOKEN = process.env.SHADOWFAX_API_TOKEN;

// ─────────────────────────────────────────────────────────────
// GET /api/habits/vendor/today
// Returns active habit packs for today for the given vendor
// (Called by partner app to show today's habit subscribers)
// ─────────────────────────────────────────────────────────────
router.get('/vendor/today', asyncHandler(async (req, res) => {
  const { vendor_id } = req.query;
  if (!vendor_id) throw new ApiError(400, 'vendor_id is required');

  const today = new Date().toISOString().split('T')[0];

  const { data: habits, error } = await supabaseAdmin
    .from('habit_packs')
    .select('*, product:products(name, image)')
    .eq('vendor_id', vendor_id)
    .eq('status', 'active')
    .lte('start_date', today)
    .gte('end_date', today);

  if (error) throw new ApiError(500, `Failed to fetch habits: ${error.message}`);

  // For each habit, check if today's order already exists
  const habitsWithStatus = await Promise.all((habits || []).map(async (habit) => {
    const todayDay = habit.days_done + 1;
    const skipped = (habit.skip_dates || []).includes(today);
    const { data: existingOrder } = await supabaseAdmin
      .from('orders')
      .select('id')
      .eq('habit_pack_id', habit.id)
      .eq('habit_day', todayDay)
      .maybeSingle();

    return {
      ...habit,
      today_order_exists: !!existingOrder,
      is_today_skipped: skipped,
    };
  }));

  // Filter out skipped days
  const actionable = habitsWithStatus.filter(h => !h.is_today_skipped);
  successResponse(res, actionable);
}));

// ─────────────────────────────────────────────────────────────
// GET /api/habits
// Returns the user's active habit pack (or recent history)
// ─────────────────────────────────────────────────────────────
router.get('/', asyncHandler(async (req, res) => {
  const { data: habits, error } = await supabaseAdmin
    .from('habit_packs')
    .select(`
      *,
      vendor:vendors(id, name, image, address, latitude, longitude, phone),
      product:products(id, name, image, price),
      day_orders:orders(id, status, habit_day, created_at, delivery_address)
    `)
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false })
    .limit(10);

  if (error) throw new ApiError(500, 'Failed to fetch habit packs');
  successResponse(res, habits);
}));

// ─────────────────────────────────────────────────────────────
// GET /api/habits/:id
// Returns a single habit pack with all day orders
// ─────────────────────────────────────────────────────────────
router.get('/:id', asyncHandler(async (req, res) => {
  const { data: habit, error } = await supabaseAdmin
    .from('habit_packs')
    .select(`
      *,
      vendor:vendors(*),
      product:products(*),
      day_orders:orders(
        id, status, habit_day, created_at, 
        delivery:deliveries(status, rider_name, rider_phone, delivery_otp, pickup_otp, history)
      )
    `)
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !habit) throw new ApiError(404, 'Habit pack not found');
  successResponse(res, habit);
}));

// ─────────────────────────────────────────────────────────────
// POST /api/habits
// Creates a new habit pack (called after checkout when isHabit=true)
// ─────────────────────────────────────────────────────────────
router.post('/', asyncHandler(async (req, res) => {
  const {
    vendor_id, product_id, health_goal,
    per_day_price, total_paid, delivery_address
  } = req.body;

  if (!vendor_id || !product_id || !per_day_price)
    throw new ApiError(400, 'vendor_id, product_id, per_day_price are required');

  // Fetch product name/image
  const { data: product } = await supabaseAdmin
    .from('products').select('name, image').eq('id', product_id).single();

  const today = new Date();
  const endDate = new Date(today);
  endDate.setDate(today.getDate() + 4); // 5-day pack: today + 4 days

  const { data: habit, error } = await supabaseAdmin
    .from('habit_packs')
    .insert({
      user_id: req.user.id,
      vendor_id,
      product_id,
      product_name: product?.name || 'Habit Meal',
      product_image: product?.image,
      health_goal,
      per_day_price,
      total_paid,
      delivery_address,
      start_date: today.toISOString().split('T')[0],
      end_date: endDate.toISOString().split('T')[0],
    })
    .select()
    .single();

  if (error) throw new ApiError(500, `Failed to create habit pack: ${error.message}`);
  successResponse(res, habit, 'Habit pack created', 201);
}));

// ─────────────────────────────────────────────────────────────
// POST /api/habits/:id/skip
// Skip today's delivery — extends end_date by 1 day
// ─────────────────────────────────────────────────────────────
router.post('/:id/skip', asyncHandler(async (req, res) => {
  const { data: habit, error } = await supabaseAdmin
    .from('habit_packs')
    .select('*')
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !habit) throw new ApiError(404, 'Habit pack not found');
  if (habit.status !== 'active') throw new ApiError(400, 'Only active habits can be skipped');

  const today = new Date().toISOString().split('T')[0];
  const skipDates = habit.skip_dates || [];

  if (skipDates.includes(today)) throw new ApiError(400, 'Today is already skipped');

  // Extend end date by 1 day
  const currentEnd = new Date(habit.end_date);
  currentEnd.setDate(currentEnd.getDate() + 1);

  const { data: updated } = await supabaseAdmin
    .from('habit_packs')
    .update({
      skip_dates: [...skipDates, today],
      end_date: currentEnd.toISOString().split('T')[0],
    })
    .eq('id', req.params.id)
    .select().single();

  // Notify user
  await supabaseAdmin.from('notifications').insert({
    user_id: req.user.id,
    type: 'habit_skipped',
    title: 'Day Skipped ⏭️',
    message: `No worries! Your pack extends by 1 day. New end date: ${updated.end_date}`,
    data: { habit_pack_id: req.params.id }
  });

  successResponse(res, updated, 'Today skipped — end date extended by 1 day');
}));

// ─────────────────────────────────────────────────────────────
// POST /api/habits/:id/cancel
// Cancel the habit pack
// ─────────────────────────────────────────────────────────────
router.post('/:id/cancel', asyncHandler(async (req, res) => {
  const { reason } = req.body;

  const { data: habit, error } = await supabaseAdmin
    .from('habit_packs')
    .select('*')
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !habit) throw new ApiError(404, 'Habit pack not found');
  if (habit.status === 'cancelled') throw new ApiError(400, 'Already cancelled');

  const { data: updated } = await supabaseAdmin
    .from('habit_packs')
    .update({
      status: 'cancelled',
      cancellation_reason: reason || 'User cancelled',
      cancelled_at: new Date().toISOString(),
    })
    .eq('id', req.params.id)
    .select().single();

  // Notify user
  await supabaseAdmin.from('notifications').insert({
    user_id: req.user.id,
    type: 'habit_cancelled',
    title: 'Habit Pack Cancelled',
    message: `Your ${habit.days_done}/${habit.days_total}-day habit has been cancelled. Contact support for refund queries.`,
    data: { habit_pack_id: req.params.id, days_completed: habit.days_done }
  });

  successResponse(res, updated, 'Habit pack cancelled');
}));

// ─────────────────────────────────────────────────────────────
// POST /api/habits/:id/trigger-today
// Called by Kitchen Partner to start today's habit delivery
// Creates a standard order + triggers Shadowfax on-demand
// ─────────────────────────────────────────────────────────────
router.post('/:id/trigger-today', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: habit, error } = await supabaseAdmin
    .from('habit_packs')
    .select('*, vendor:vendors(*), product:products(*)')
    .eq('id', id)
    .single();

  if (error || !habit) throw new ApiError(404, 'Habit pack not found');
  if (habit.status !== 'active') throw new ApiError(400, 'Habit is not active');

  const today = new Date().toISOString().split('T')[0];
  if ((habit.skip_dates || []).includes(today)) {
    throw new ApiError(400, 'Today is marked as skipped');
  }

  const todayDay = habit.days_done + 1;
  if (todayDay > habit.days_total) throw new ApiError(400, 'All days already completed');

  // Check if today's order already exists
  const { data: existingOrder } = await supabaseAdmin
    .from('orders')
    .select('id, status')
    .eq('habit_pack_id', id)
    .eq('habit_day', todayDay)
    .maybeSingle();

  if (existingOrder) {
    return successResponse(res, { order_id: existingOrder.id, already_created: true });
  }

  // Generate order number
  const orderNumber = `HBT-${Date.now()}`;

  // Create order
  const { data: order, error: orderErr } = await supabaseAdmin
    .from('orders')
    .insert({
      user_id: habit.user_id,
      vendor_id: habit.vendor_id,
      habit_pack_id: id,
      habit_day: todayDay,
      order_number: orderNumber,
      status: 'confirmed',
      payment_status: 'paid',
      payment_method: 'prepaid_habit',
      subtotal: habit.per_day_price,
      total: habit.per_day_price,
      delivery_address: habit.delivery_address,
      items: [{
        product_id: habit.product_id,
        product_name: habit.product_name,
        quantity: 1,
        unit_price: habit.per_day_price,
      }],
      is_habit: true,
    })
    .select()
    .single();

  if (orderErr) throw new ApiError(500, `Failed to create order: ${orderErr.message}`);

  // Create delivery record
  const deliveryOtp = Math.floor(1000 + Math.random() * 9000).toString();
  const pickupOtp = Math.floor(1000 + Math.random() * 9000).toString();

  await supabaseAdmin.from('deliveries').insert({
    order_id: order.id,
    status: 'pending',
    pickup_otp: pickupOtp,
    delivery_otp: deliveryOtp,
    history: [{ status: 'pending', timestamp: new Date().toISOString(), note: 'Habit Day Triggered' }],
  });

  // Trigger Shadowfax on-demand order
  try {
    const sfPayload = {
      pickup_details: {
        name: habit.vendor?.name,
        contact_number: habit.vendor?.phone,
        address: habit.vendor?.address,
        latitude: Number(habit.vendor?.latitude),
        longitude: Number(habit.vendor?.longitude),
      },
      drop_details: {
        name: habit.delivery_address?.name,
        contact_number: habit.delivery_address?.phone,
        address: habit.delivery_address?.address,
        latitude: habit.delivery_address?.latitude,
        longitude: habit.delivery_address?.longitude,
      },
      order_details: {
        order_id: orderNumber,
        is_prepaid: true,
        cash_to_be_collected: 0,
        rts_required: true,
      },
      validations: {
        pickup: { is_otp_required: true, otp: pickupOtp },
        drop: { is_otp_required: true, otp: deliveryOtp },
      },
    };

    const sfRes = await axios.post(`${SHADOWFAX_BASE_URL}/order/create/`, sfPayload, {
      headers: { Authorization: SHADOWFAX_TOKEN, 'Content-Type': 'application/json' },
    });

    if (sfRes.data?.order_id) {
      await supabaseAdmin.from('deliveries').update({
        external_order_id: sfRes.data.order_id,
        status: 'searching_rider',
      }).eq('order_id', order.id);
    }
  } catch (sfErr) {
    console.error('Shadowfax trigger failed (non-fatal):', sfErr.message);
    // Non-fatal — order is created, Shadowfax can be retried
  }

  // Notify user: Today's meal is on its way!
  await supabaseAdmin.from('notifications').insert({
    user_id: habit.user_id,
    type: 'habit_day_started',
    title: `Day ${todayDay} Habit Meal 🔥`,
    message: `${habit.product_name} is being prepared! Your rider will be assigned soon.`,
    data: { habit_pack_id: id, order_id: order.id, habit_day: todayDay }
  });

  successResponse(res, { order_id: order.id, habit_day: todayDay, order_number: orderNumber });
}));

// ─────────────────────────────────────────────────────────────
// Internal helper: called by orders webhook on DELIVERED
// Increments days_done and marks complete if all done
// ─────────────────────────────────────────────────────────────
export async function onHabitDayDelivered(habitPackId) {
  const { data: habit } = await supabaseAdmin
    .from('habit_packs')
    .select('*')
    .eq('id', habitPackId)
    .single();

  if (!habit) return;

  const newDaysDone = habit.days_done + 1;
  const isComplete = newDaysDone >= habit.days_total;

  await supabaseAdmin.from('habit_packs').update({
    days_done: newDaysDone,
    status: isComplete ? 'completed' : 'active',
    completed_at: isComplete ? new Date().toISOString() : null,
  }).eq('id', habitPackId);

  // Push notification
  await supabaseAdmin.from('notifications').insert({
    user_id: habit.user_id,
    type: isComplete ? 'habit_completed' : 'habit_day_delivered',
    title: isComplete ? 'Mission Complete! 🏆' : `Day ${newDaysDone} Done! 🔥`,
    message: isComplete
      ? `You completed your full 5-Day Habit Mission! Start another one to keep the gains.`
      : `Day ${newDaysDone} of ${habit.days_total} delivered. Keep going! ${habit.days_total - newDaysDone} days left.`,
    data: { habit_pack_id: habitPackId, days_done: newDaysDone }
  });
}

export default router;

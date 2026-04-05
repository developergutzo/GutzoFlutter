import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';

const router = express.Router();

// GET ALL DELIVERY ZONES
router.get('/', asyncHandler(async (req, res) => {
  const { city = '' } = req.query;

  const { data: zones, error } = await supabaseAdmin
    .from('delivery_zones')
    .select('*')
    .eq('city', city)
    .eq('is_active', true)
    .order('name');

  if (error) throw new ApiError(500, 'Failed to fetch zones');
  successResponse(res, zones);
}));

// CHECK IF LOCATION IS SERVICEABLE
router.post('/check', asyncHandler(async (req, res) => {
  const { latitude, longitude, vendor_id } = req.body;

  if (!latitude || !longitude) throw new ApiError(400, 'Coordinates required');

  // Get all active zones
  const { data: zones } = await supabaseAdmin
    .from('delivery_zones')
    .select('*')
    .eq('is_active', true);

  // Find matching zone (simple radius check)
  const matchedZone = zones?.find(zone => {
    if (!zone.center_lat || !zone.center_lng || !zone.radius_km) return false;
    const distance = haversineDistance(
      latitude, longitude,
      parseFloat(zone.center_lat), parseFloat(zone.center_lng)
    );
    return distance <= zone.radius_km;
  });

  if (!matchedZone) {
    return successResponse(res, { 
      serviceable: false, 
      message: 'Sorry, we do not deliver to this location yet.' 
    });
  }

  // If vendor specified, check vendor delivers to this zone
  if (vendor_id) {
    const { data: vendorZone } = await supabaseAdmin
      .from('vendor_delivery_zones')
      .select('*, zone:delivery_zones(*)')
      .eq('vendor_id', vendor_id)
      .eq('zone_id', matchedZone.id)
      .eq('is_active', true)
      .single();

    if (!vendorZone) {
      return successResponse(res, {
        serviceable: false,
        message: 'This vendor does not deliver to your location.'
      });
    }

    return successResponse(res, {
      serviceable: true,
      zone: matchedZone,
      delivery_fee: vendorZone.delivery_fee,
      delivery_time: `${vendorZone.min_delivery_time}-${vendorZone.max_delivery_time} min`,
      minimum_order: vendorZone.minimum_order
    });
  }

  successResponse(res, { 
    serviceable: true, 
    zone: matchedZone,
    message: 'Delivery available in your area!'
  });
}));

// GET VENDORS IN ZONE
router.get('/:id/vendors', asyncHandler(async (req, res) => {
  const { data: vendorZones, error } = await supabaseAdmin
    .from('vendor_delivery_zones')
    .select(`
      *,
      vendor:vendors(id, name, image, rating, cuisine_type, delivery_time, is_open)
    `)
    .eq('zone_id', req.params.id)
    .eq('is_active', true);

  if (error) throw new ApiError(500, 'Failed to fetch vendors');

  const vendors = vendorZones?.map(vz => ({
    ...vz.vendor,
    delivery_fee: vz.delivery_fee,
    min_delivery_time: vz.min_delivery_time,
    max_delivery_time: vz.max_delivery_time,
    minimum_order: vz.minimum_order
  })) || [];

  successResponse(res, vendors);
}));

// Haversine formula for distance calculation
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg) {
  return deg * (Math.PI / 180);
}

export default router;

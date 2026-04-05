import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';

const router = express.Router();

// ============================================
// GET ALL CATEGORIES
// GET /api/categories
// ============================================
router.get('/', asyncHandler(async (req, res) => {
  const { featured, parent_id } = req.query;

  let query = supabaseAdmin
    .from('categories')
    .select('*')
    .eq('is_active', true)
    .order('sort_order', { ascending: true });

  if (featured === 'true') query = query.eq('is_featured', true);
  if (parent_id) query = query.eq('parent_category_id', parent_id);
  if (parent_id === 'null') query = query.is('parent_category_id', null);

  const { data: categories, error } = await query;

  if (error) throw new ApiError(500, 'Failed to fetch categories');

  successResponse(res, categories);
}));

// ============================================
// GET CATEGORY BY ID
// GET /api/categories/:id
// ============================================
router.get('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data: category, error } = await supabaseAdmin
    .from('categories')
    .select(`
      *,
      subcategories:categories!parent_category_id(*)
    `)
    .eq('id', id)
    .eq('is_active', true)
    .single();

  if (error || !category) throw new ApiError(404, 'Category not found');

  // Get product count for this category
  const { count } = await supabaseAdmin
    .from('products')
    .select('*', { count: 'exact', head: true })
    .eq('category', category.name)
    .eq('is_available', true);

  successResponse(res, { ...category, product_count: count });
}));

// ============================================
// GET CATEGORY BY SLUG
// GET /api/categories/slug/:slug
// ============================================
router.get('/slug/:slug', asyncHandler(async (req, res) => {
  const { slug } = req.params;

  const { data: category, error } = await supabaseAdmin
    .from('categories')
    .select('*')
    .eq('slug', slug)
    .eq('is_active', true)
    .single();

  if (error || !category) throw new ApiError(404, 'Category not found');

  successResponse(res, category);
}));

// ============================================
// GET PRODUCTS BY CATEGORY NAME
// GET /api/categories/:name/products
// ============================================
router.get('/:name/products', asyncHandler(async (req, res) => {
  const { name } = req.params;
  const { page = 1, limit = 20, sort = 'sort_order', order = 'asc' } = req.query;

  const from = (page - 1) * limit;
  const to = from + limit - 1;

  const { data: products, error, count } = await supabaseAdmin
    .from('products')
    .select(`
      *,
      vendor:vendors(id, name, image, rating, is_open)
    `, { count: 'exact' })
    .eq('category', name)
    .eq('is_available', true)
    .order(sort, { ascending: order === 'asc' })
    .range(from, to);

  if (error) throw new ApiError(500, 'Failed to fetch products');

  successResponse(res, {
    products,
    pagination: {
      page: parseInt(page),
      limit: parseInt(limit),
      total: count,
      totalPages: Math.ceil(count / limit)
    }
  });
}));

export default router;

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

console.log('Current directory:', process.cwd());
console.log('Env loaded, SUPABASE_URL exists:', !!process.env.SUPABASE_URL);

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function fixJan25() {
  const vendorId = '3109c7d3-95e0-4a7a-86dd-9783e778d50c';
  console.log(`Checking Jan 25 data for vendor ${vendorId}...`);

  // 1. Get Meal Plan ID
  const { data: plans, error: planError } = await supabase
    .from('meal_plans')
    .select('id')
    .eq('vendor_id', vendorId)
    .limit(1);

  if (planError || !plans || plans.length === 0) {
    console.error('Error finding meal plan:', planError);
    return;
  }

  const mealPlanId = plans[0].id;
  console.log('Found Meal Plan ID:', mealPlanId);

  // 2. Get Template ID for GZ_7 (Fish Curry) - or any valid template
  const { data: templates, error: templateError } = await supabase
    .from('meal_templates')
    .select('id, template_code, item_name')
    .eq('vendor_id', vendorId)
    .eq('template_code', 'GZ_7')
    .limit(1);
    
  let lunchTemplateId = null;
  let lunchTemplateCode = null;

  if (templates && templates.length > 0) {
      lunchTemplateId = templates[0].id;
      lunchTemplateCode = templates[0].template_code;
      console.log(`Found template: ${lunchTemplateCode} (${templates[0].item_name})`);
  } else {
      console.error('Template GZ_7 not found! fetching any template...');
       const { data: anyTemp } = await supabase.from('meal_templates').select('id, template_code').eq('vendor_id', vendorId).limit(1);
       if(anyTemp && anyTemp.length > 0) {
           lunchTemplateId = anyTemp[0].id;
           lunchTemplateCode = anyTemp[0].template_code;
           console.log(`Fallback template: ${lunchTemplateCode}`);
       }
  }

  // 3. Insert or Update Calendar Entry
  const { data: upsertData, error: upsertError } = await supabase
    .from('meal_plan_calendar')
    .upsert({
      meal_plan_id: mealPlanId,
      menu_date: '2026-01-25',
      lunch_template_id: lunchTemplateId,
      lunch_template_code: lunchTemplateCode,
       // Clear others to match "Lunch Only" requirement
      breakfast_template_id: null,
      breakfast_template_code: null,
      dinner_template_id: null,
      dinner_template_code: null,
      snack_template_id: null,
      snack_template_code: null,
      is_available: true
    }, { onConflict: 'meal_plan_id, menu_date' })
    .select();

  if (upsertError) {
    console.error('Error upserting Jan 25 entry:', upsertError);
  } else {
    console.log('✅ Successfully upserted Jan 25 entry:', upsertData);
  }

  // 4. Verify View
  const { data: viewData, error: viewError } = await supabase
    .from('meal_plan_menu_view')
    .select('*')
    .eq('menu_date', '2026-01-25')
    .eq('vendor_id', vendorId);

  console.log('View verify:', viewData);
}

fixJan25();

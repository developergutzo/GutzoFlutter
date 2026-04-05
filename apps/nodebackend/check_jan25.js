const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkJan25() {
  console.log('Checking Jan 25 data for vendor 3109c7d3-95e0-4a7a-86dd-9783e778d50c...');

  const { data, error } = await supabase
    .from('meal_plan_menu_view')
    .select('*')
    .eq('menu_date', '2026-01-25')
    .eq('vendor_id', '3109c7d3-95e0-4a7a-86dd-9783e778d50c');

  if (error) {
    console.error('Error fetching view:', error);
  } else {
    console.log('View Data Count:', data.length);
    console.log('View Data for Jan 25:', JSON.stringify(data, null, 2));
  }
}

checkJan25();

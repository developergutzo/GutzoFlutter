import { supabaseAdmin } from './src/config/supabase.js';

async function test() {
  const { data, error } = await supabaseAdmin.from('user_addresses').select('*').limit(1);
  if (error) {
    console.error("Error:", error);
  } else if (data.length > 0) {
    console.log("Columns:", Object.keys(data[0]));
  } else {
    // If empty, let's try to fetch another table maybe user_addresses doesn't exist
    console.log("No data found or table empty.");
  }
}
test();

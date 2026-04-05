import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load .env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkMoodCategories() {
  const { data, error } = await supabase
    .from('MoodCategory')
    .select('*')
    .limit(1);

  if (error) {
    console.error("Error/Table might not exist:", error.message);
    process.exit(1);
  } else {
    console.log("Table 'MoodCategory' exists and data was fetched successfully.");
    process.exit(0);
  }
}

checkMoodCategories();

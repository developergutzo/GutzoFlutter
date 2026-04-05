import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load .env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in .env");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkCategoriesSchema() {
  console.log("Connecting to Supabase at:", supabaseUrl);
  
  const { data, error } = await supabase
    .from('categories')
    .select('*')
    .limit(1);

  if (error) {
    console.error("Error fetching categories:", error);
    return;
  }

  if (data && data.length > 0) {
    const category = data[0];
    console.log("Categories Table Structure (Columns):");
    console.log(JSON.stringify(Object.keys(category), null, 2));
    console.log("\nSample Data:");
    console.log(JSON.stringify(category, null, 2));
  } else {
    console.log("No categories found in the 'categories' table.");
    
    // Try to list tables if possible (Supabase doesn't have a direct "list tables" in JS SDK easily without RPC)
    // But we can check if the table exists by trying a count
    const { count, error: countError } = await supabase
      .from('categories')
      .select('*', { count: 'exact', head: true });
    
    if (countError) {
      console.error("Table 'categories' might not exist or is inaccessible:", countError.message);
    } else {
      console.log("Table 'categories' exists but is empty.");
    }
  }
}

checkCategoriesSchema();

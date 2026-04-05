import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function updateUser() {
  console.log('Updating user profile for +919944751745...');
  
  const { data, error } = await supabase
    .from('users')
    .update({ 
        name: 'Madhan', 
        email: 'madhan@gutzo.in' 
    })
    .eq('phone', '+919944751745')
    .select();

  if (error) {
    console.error('Error updating user:', error);
  } else {
    console.log('User updated successfully:', data);
  }
}

updateUser();

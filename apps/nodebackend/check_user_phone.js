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

const phoneArg = process.argv[2];

if (!phoneArg) {
    console.error("Please provide a phone number");
    process.exit(1);
}

const searchPhone = phoneArg.startsWith('+') ? phoneArg : `+91${phoneArg.replace(/^\+91/, '')}`;

async function checkUserByPhone() {
    console.log(`Checking user for Phone: ${searchPhone}`);
    
    const { data: user, error } = await supabase
        .from('users')
        .select('*') // Get everything to see ID
        .eq('phone', searchPhone)
        .single();
    
    if (error || !user) {
        // Try without +91 just in case
        console.log("Not found with +91, trying raw...");
         const { data: user2, error: error2 } = await supabase
            .from('users')
            .select('*')
            .eq('phone', process.argv[2])
            .single();

        if (user2) {
             console.log(`FOUND RAW! ID: ${user2.id}`);
             console.log(`Stored Phone: ${user2.phone}`);
             return;
        }

        console.error("User not found:", error);
        return;
    }

    console.log(`FOUND! ID: ${user.id}`);
    console.log(`Stored Phone: ${user.phone}`);
    console.log(`Name: ${user.name}`);
}

checkUserByPhone();

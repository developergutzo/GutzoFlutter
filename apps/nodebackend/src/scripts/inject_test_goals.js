
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error("Missing Env Vars");
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function injectGoals() {
    console.log("🚀 Starting Health Goal Injection...");
    
    // 1. Fetch 4 available products to tag
    const { data: products, error: fetchError } = await supabase
        .from('products')
        .select('id, name')
        .eq('is_available', true)
        .limit(4);
        
    if (fetchError || !products || products.length < 4) {
        console.error("❌ Error: Need at least 4 available products to test.", fetchError);
        return;
    }

    const testGoals = [
        { name: products[0].name, goal: 'Low Calorie', mission: 'Flat Tummy' },
        { name: products[1].name, goal: 'High Protein', mission: 'Muscle Gain' },
        { name: products[2].name, goal: 'High Fiber', mission: 'Skin Glow' },
        { name: products[3].name, goal: 'Sugar Free', mission: 'Clinical/Sugar' }
    ];

    console.log("📝 Mapping products to missions:");
    
    for (let i = 0; i < products.length; i++) {
        const item = testGoals[i];
        console.log(`   - ${item.name} ➔ ${item.mission} (${item.goal})`);
        
        const { error: updateError } = await supabase
            .from('products')
            .update({ 
                category: item.goal,
                tags: [item.goal] 
            })
            .eq('id', products[i].id);
            
        if (updateError) {
            console.error(`❌ Failed to update ${item.name}:`, updateError);
        }
    }

    console.log("✅ Injection Complete! Perform a Hot Restart and check the 4 goals.");
}

injectGoals();

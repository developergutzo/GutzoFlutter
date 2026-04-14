import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

const SITRA_DEW_UPDATES = [
    {
        id: '17fe48cc-53f8-405b-aa37-c5f17b92df61',
        name: 'ABC Juice',
        nutrition: { calories: 120, protein: 1, carbs: 28, fat: 0, fiber: 4, sugar: 18 }
    },
    {
        id: '477a52e5-cae8-4b3c-af27-47ff65395b15',
        name: 'Green Detox Juice',
        nutrition: { calories: 80, protein: 2, carbs: 18, fat: 0, fiber: 5, sugar: 12 }
    },
    {
        id: 'fc8b0583-b9ae-4fde-809f-4e690c3cfb31',
        name: 'Lean Protein Salad',
        nutrition: { calories: 320, protein: 28, carbs: 12, fat: 16, fiber: 7, sugar: 4 }
    },
    {
        id: '0c1ad1f5-bacb-4c94-ad70-aff670b4e3f2',
        name: 'Antioxidant Berry Bowl',
        nutrition: { calories: 280, protein: 6, carbs: 45, fat: 8, fiber: 9, sugar: 15 }
    },
    {
        id: 'd53b0eb4-1157-4bd4-ade1-6c0393842c37',
        name: 'Sugar-Free Almond Crunch',
        nutrition: { calories: 210, protein: 5, carbs: 12, fat: 15, fiber: 4, sugar: 4 }
    }
];

async function seedData() {
    console.log("🚀 Seeding CC Sitra Nutrition Data...");
    
    for (const item of SITRA_DEW_UPDATES) {
        console.log(`Updating ${item.name}...`);
        const { error } = await supabase
            .from('products')
            .update({ nutritional_info: item.nutrition })
            .eq('id', item.id);
            
        if (error) {
            console.error(`❌ Error updating ${item.name}:`, error);
        } else {
            console.log(`✅ ${item.name} updated successfully.`);
        }
    }
    
    console.log("🏁 Seeding Finished!");
}

seedData();

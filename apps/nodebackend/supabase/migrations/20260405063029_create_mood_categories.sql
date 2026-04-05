-- Create MoodCategory table
CREATE TABLE IF NOT EXISTS public."MoodCategory" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    image_url TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public."MoodCategory" ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Allow public read access" ON public."MoodCategory"
    FOR SELECT USING (true);

-- Insert initial data based on mock items in home_screen.dart
INSERT INTO public."MoodCategory" (name, image_url, sort_order)
VALUES 
    ('Bowls', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c', 1),
    ('Breakfast', 'https://images.unsplash.com/photo-1525351484163-7529414344d8', 2),
    ('Salads', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd', 3),
    ('Soups', 'https://images.unsplash.com/photo-1547592166-23ac45744acd', 4),
    ('Wraps', 'https://images.unsplash.com/photo-1626700051175-6818013e184f', 5),
    ('Smoothies', 'https://images.unsplash.com/photo-1623065422902-30a2ad299bb4', 6),
    ('Juices', 'https://images.unsplash.com/photo-1613478223719-2ab802602423', 7),
    ('Mains', 'https://images.unsplash.com/photo-1546793665-c74683c3f38d', 8),
    ('Snacks', 'https://images.unsplash.com/photo-1599490659213-e2b9527bb087', 9),
    ('Desserts', 'https://images.unsplash.com/photo-1551024601-bec78aea704b', 10);

-- =============================================================================
-- Rafiq — reference data
-- -----------------------------------------------------------------------------
-- Idempotent inserts for cities and categories. Run after migrations:
--   psql $SUPABASE_DB_URL -f supabase/seed.sql
-- =============================================================================

begin;

insert into public.cities (slug, name_ar, name_en, region_ar, region_en, sort_order) values
  ('cairo',       'القاهرة',     'Cairo',       'القاهرة الكبرى', 'Greater Cairo', 10),
  ('giza',        'الجيزة',      'Giza',        'القاهرة الكبرى', 'Greater Cairo', 20),
  ('alexandria',  'الإسكندرية',  'Alexandria',  'الساحل الشمالي', 'North Coast',   30),
  ('mansoura',    'المنصورة',    'Mansoura',    'الدلتا',         'Delta',         40),
  ('tanta',       'طنطا',        'Tanta',       'الدلتا',         'Delta',         50),
  ('luxor',       'الأقصر',      'Luxor',       'الصعيد',         'Upper Egypt',   60),
  ('aswan',       'أسوان',       'Aswan',       'الصعيد',         'Upper Egypt',   70),
  ('hurghada',    'الغردقة',     'Hurghada',    'البحر الأحمر',   'Red Sea',       80),
  ('sharm',       'شرم الشيخ',   'Sharm El-Sheikh', 'البحر الأحمر', 'Red Sea',     90)
on conflict (slug) do update
set name_ar = excluded.name_ar,
    name_en = excluded.name_en,
    region_ar = excluded.region_ar,
    region_en = excluded.region_en,
    sort_order = excluded.sort_order,
    updated_at = now();

insert into public.categories (slug, name_ar, name_en, icon_key, sort_order) values
  ('food',          'طعام',         'Food',          'food',          10),
  ('entertainment', 'ترفيه',        'Entertainment', 'entertainment', 20),
  ('tourism',       'سياحي',        'Tourism',       'tourism',       30),
  ('culture',       'ثقافي',        'Culture',       'culture',       40),
  ('sports',        'رياضة',        'Sports',        'sports',        50),
  ('shopping',      'تسوّق',         'Shopping',      'shopping',      60),
  ('family',        'عائلة',        'Family',        'family',        70),
  ('nightlife',     'سهرات',        'Nightlife',     'nightlife',     80)
on conflict (slug) do update
set name_ar = excluded.name_ar,
    name_en = excluded.name_en,
    icon_key = excluded.icon_key,
    sort_order = excluded.sort_order,
    updated_at = now();

commit;

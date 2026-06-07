-- =============================================================================
-- 0051  Remove unrecoverable phone-local place image paths
-- -----------------------------------------------------------------------------
-- These legacy values pointed at a picker cache on one Android device. No
-- matching Storage object exists, so keeping them only produces broken images.
-- =============================================================================

begin;

update public.places
   set image_path = null,
       updated_at = now()
 where image_path is not null
   and trim(image_path) <> ''
   and image_path not like 'https://%'
   and image_path not like 'http://%'
   and image_path not like 'place-images://%'
   and image_path not like 'assets/%';

commit;

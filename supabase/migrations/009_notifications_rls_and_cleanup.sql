-- Migration 009: Fix Notifications RLS, clean up demo notifications, and update system settings

-- 1. Remove obsolete demo seed notifications
DELETE FROM public.notifications 
WHERE id IN (
  'notif-67f79394-088f-47a5-ba28-4182baa92784',
  'notif-a319918c-73aa-49d2-87a8-d64c35ba21cf',
  'notif-50772509-0596-4ca2-9f51-8612ce24662f',
  'notif-c35ab755-6cfc-410e-9821-8db133f6c835'
) OR title ILIKE '%Water Shutdown Notice%';

-- 2. Drop existing restrictive policies on notifications
DROP POLICY IF EXISTS "Recipient reads own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Service inserts notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;

-- 3. Create comprehensive RLS policies on notifications
-- SELECT: Admins can view all; tenants can view their own or broadcasts
CREATE POLICY "notifications_select_policy"
ON public.notifications
FOR SELECT
TO authenticated
USING (
  recipient_id = auth.uid() 
  OR recipient_id IS NULL 
  OR for_role IN ('tenant', 'all')
  OR EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- INSERT: Authenticated users / admins can insert notifications
CREATE POLICY "notifications_insert_policy"
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- UPDATE: Users can mark their notifications as read
CREATE POLICY "notifications_update_policy"
ON public.notifications
FOR UPDATE
TO authenticated
USING (
  recipient_id = auth.uid()
  OR recipient_id IS NULL
  OR EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (true);

-- DELETE: Users can remove notifications
CREATE POLICY "notifications_delete_policy"
ON public.notifications
FOR DELETE
TO authenticated
USING (
  recipient_id = auth.uid()
  OR recipient_id IS NULL
  OR EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 4. Update system_settings with Google Drive APK link and version
INSERT INTO public.system_settings (key, value, description)
VALUES 
  ('app_version', '1.1.0+3', 'Current release version of Rentify'),
  ('apk_download_url', 'https://drive.google.com/file/d/17iyA3iucFCk4YTtYbj_X_HpyYXS8C_zx/view?usp=sharing', 'Google Drive download link for latest APK'),
  ('app_release_notes', 'Enhanced tenant experience, read-only Details tab, live notifications, and persistent biometric app lock.', 'Release changelog')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = now();

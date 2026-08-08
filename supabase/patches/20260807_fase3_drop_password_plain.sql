-- Fase 3: eliminar contraseñas en texto plano de admin_credenciales
ALTER TABLE public.admin_credenciales DROP COLUMN IF EXISTS password_plain;

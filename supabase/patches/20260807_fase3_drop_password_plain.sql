-- Fase 3: eliminar contraseñas en texto plano de admin_credenciales
-- Paso 1: borrar todos los valores existentes (por si quedan registros viejos)
UPDATE public.admin_credenciales SET password_plain = NULL;

-- Paso 2: eliminar la columna definitivamente
ALTER TABLE public.admin_credenciales DROP COLUMN IF EXISTS password_plain;

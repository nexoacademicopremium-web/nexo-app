// ============================================================
// NEXO ACADÉMICO — Supabase Configuration
// Replace with your actual Supabase project values.
// Find them in: Supabase Dashboard > Settings > API
// ============================================================

const SUPABASE_URL  = 'https://nqomrxitjayarknwdqbj.supabase.co';
const SUPABASE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xb21yeGl0amF5YXJrbndkcWJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExOTkwODYsImV4cCI6MjA5Njc3NTA4Nn0.pA_B2QYsPlEQpJG7DbJTMkNuGDej_30WSKcQgouwI5o';

// Sin subfolder en Netlify — la app cuelga de la raíz del dominio.
const BASE_PATH = '';

// WhatsApp de Manu (admin)
const WHATSAPP_MANU = '34699529399';

// Base URL del app (para links en emails)
const APP_BASE_URL  = 'https://app.nexoacademico.es';

// Inicializar cliente Supabase (disponible como window.db)
const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});

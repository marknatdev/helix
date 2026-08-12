# Helix Smart Helmet - Authentication System Documentation

The Helix Command Hub uses **Supabase Authentication** for secure supervisor & safety officer access, styled using the StitchMCP Industrial Cyber-Clean Dark Theme.

---

## 🔐 Features & Workflow

1. **Supabase Auth Integration**:
   - Uses `supabase.auth.signInWithPassword({ email, password })`.
   - Maintains active session via `supabase.auth.getSession()` and `supabase.auth.onAuthStateChange()`.
   - Top navigation header displays the logged-in supervisor's email and a **Sign Out** button.

2. **Instant Demo Access (Bypass Mode)**:
   - For site demonstrations or offline use without active Supabase credentials, clicking **"Bypass Login (Demo Officer Mode)"** grants instant access to the dashboard.

---

## 🛠 Setting Up Supabase Authentication

1. Open your **Supabase Dashboard** -> **Authentication** -> **Providers** -> **Email**.
2. Ensure Email Auth is **Enabled**.
3. Go to **Authentication** -> **Users** and click **Create User**:
   - **Email**: `admin@construction.com`
   - **Password**: `SafetyFirst2026!`
4. In your `.env` file or Vercel environment variables, set:
   ```env
   VITE_SUPABASE_URL=https://your-project.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-key
   ```

import { createClient } from '@supabase/supabase-js';

// Environment variables for Supabase
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://placeholder-project.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'placeholder-anon-key';

// Initialize Supabase Client
export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Check if valid credentials are configured
export const isSupabaseConfigured = () => {
  return (
    import.meta.env.VITE_SUPABASE_URL &&
    import.meta.env.VITE_SUPABASE_ANON_KEY &&
    !import.meta.env.VITE_SUPABASE_URL.includes('placeholder')
  );
};

// Fetch Helmets & Workers from Supabase
export const fetchLiveHelmetsFromSupabase = async () => {
  if (!isSupabaseConfigured()) return [];
  try {
    const { data: helmetsData, error: hError } = await supabase
      .from('helmets')
      .select('*, workers(*)');

    if (hError || !helmetsData) {
      console.warn('Supabase fetch helmets notice:', hError);
      return [];
    }

    const { data: logsData } = await supabase
      .from('telemetry_logs')
      .select('*')
      .order('timestamp', { ascending: false })
      .limit(20);

    return helmetsData.map(h => {
      const latestLog = logsData?.find(l => l.helmet_id === h.id);
      return {
        id: h.id,
        name: h.workers?.full_name || `Worker ${h.device_id}`,
        role: h.workers?.role || 'Construction Specialist',
        helmetId: h.device_id,
        battery: h.battery_pct ?? 100,
        posture: latestLog?.posture_state || 'STANDING',
        lat: latestLog?.latitude || 13.7563,
        lng: latestLog?.longitude || 100.5018,
        rssi: latestLog?.rssi || -70,
        snr: latestLog?.snr || 8.5,
        zone: 'Site Zone Alpha',
        lastSeen: h.last_seen ? new Date(h.last_seen).toLocaleTimeString() : 'Online'
      };
    });
  } catch (err) {
    console.error('Supabase fetch error:', err);
    return [];
  }
};

// Fetch Incidents from Supabase
export const fetchLiveIncidentsFromSupabase = async () => {
  if (!isSupabaseConfigured()) return [];
  try {
    const { data, error } = await supabase
      .from('incidents')
      .select('*')
      .order('timestamp', { ascending: false })
      .limit(50);

    if (error || !data) return [];

    return data.map(inc => ({
      id: inc.id,
      helmetId: inc.helmet_id || 'HELMET-UNIT',
      workerName: inc.worker_name || 'Worker Unit',
      type: inc.event_type || 'SAFETY_ALERT',
      severity: inc.severity || 'WARNING',
      status: inc.status || 'OPEN',
      location: inc.location || 'Site Perimeter',
      timestamp: inc.timestamp ? new Date(inc.timestamp).toLocaleTimeString() : 'Just now',
      details: inc.details || 'Telemetry event triggered from hardware gateway.'
    }));
  } catch (err) {
    console.error('Supabase fetch incidents error:', err);
    return [];
  }
};

// Clean initial data (No hardcoded demo seed data)
export const initialWorkers = [];
export const initialIncidents = [];

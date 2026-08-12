-- ==========================================================
-- HELIX SMART HELMET SAFETY DASHBOARD - DATABASE SCHEMA
-- Target Database: Supabase PostgreSQL with Realtime
-- ==========================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------
-- 1. WORKERS TABLE
-- Stores worker profile, role, site authorization, emergency contact
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.workers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('Scaffolder', 'Electrician', 'Crane Operator', 'Steel Fixer', 'Site Manager', 'Safety Inspector')),
    blood_type VARCHAR(5),
    emergency_contact TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------
-- 2. HELMETS TABLE
-- Stores helmet hardware serials, LoRa addresses, battery status
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.helmets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id VARCHAR(50) UNIQUE NOT NULL, -- e.g. "HELMET-001"
    lora_address INT NOT NULL,             -- LoRa Node ID
    assigned_worker_id UUID REFERENCES public.workers(id) ON DELETE SET NULL,
    battery_pct INT CHECK (battery_pct BETWEEN 0 AND 100) DEFAULT 100,
    firmware_version VARCHAR(20) DEFAULT 'v1.2.0-esp32',
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------
-- 3. TELEMETRY LOGS TABLE
-- Live stream of sensor readings from Sender ESP32 via Receiver ESP32
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.telemetry_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    helmet_id UUID REFERENCES public.helmets(id) ON DELETE CASCADE,
    worker_id UUID REFERENCES public.workers(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    posture_state VARCHAR(20) NOT NULL CHECK (posture_state IN ('SITTING', 'RUNNING', 'STANDING', 'WALKING', 'FALL_DETECTED')),
    battery_pct INT NOT NULL,
    rssi INT, -- LoRa Signal Strength (dBm)
    snr REAL, -- LoRa Signal-to-Noise Ratio
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast real-time queries
CREATE INDEX IF NOT EXISTS idx_telemetry_helmet_time ON public.telemetry_logs (helmet_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_posture ON public.telemetry_logs (posture_state);

-- ----------------------------------------------------------
-- 4. INCIDENTS TABLE
-- Fall alerts, panic button triggers, hazard area alerts
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    helmet_id UUID REFERENCES public.helmets(id) ON DELETE CASCADE,
    worker_id UUID REFERENCES public.workers(id) ON DELETE CASCADE,
    event_type VARCHAR(30) NOT NULL CHECK (event_type IN ('FALL_DETECTION', 'PANIC_SOS', 'LOW_BATTERY', 'RESTRICTED_ZONE')),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('CRITICAL', 'WARNING', 'INFO')),
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'RESOLVED')),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- ----------------------------------------------------------
-- 5. SUPABASE REALTIME PUBLICATION
-- Enable Realtime WebSockets streaming for telemetry and incidents
-- ----------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE public.telemetry_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.incidents;
ALTER PUBLICATION supabase_realtime ADD TABLE public.helmets;

-- ----------------------------------------------------------
-- 6. SAMPLE SEED DATA
-- ----------------------------------------------------------
INSERT INTO public.workers (id, full_name, role, blood_type, emergency_contact) VALUES
('11111111-1111-1111-1111-111111111111', 'Alex Vance', 'Steel Fixer', 'O+', '+1 (555) 019-2831'),
('22222222-2222-2222-2222-222222222222', 'Marcus Brody', 'Scaffolder', 'A+', '+1 (555) 014-9921'),
('33333333-3333-3333-3333-333333333333', 'Elena Rostova', 'Crane Operator', 'B-', '+1 (555) 017-4409'),
('44444444-4444-4444-4444-444444444444', 'David Miller', 'Electrician', 'AB+', '+1 (555) 012-7788')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.helmets (id, device_id, lora_address, assigned_worker_id, battery_pct, is_active) VALUES
('a1111111-1111-1111-1111-111111111111', 'HELMET-001', 101, '11111111-1111-1111-1111-111111111111', 94, true),
('a2222222-2222-2222-2222-222222222222', 'HELMET-002', 102, '22222222-2222-2222-2222-222222222222', 18, true),
('a3333333-3333-3333-3333-333333333333', 'HELMET-003', 103, '33333333-3333-3333-3333-333333333333', 88, true),
('a4444444-4444-4444-4444-444444444444', 'HELMET-004', 104, '44444444-4444-4444-4444-444444444444', 65, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.incidents (id, helmet_id, worker_id, event_type, severity, status, latitude, longitude, details) VALUES
('c1111111-1111-1111-1111-111111111111', 'a2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'LOW_BATTERY', 'WARNING', 'OPEN', 13.7563, 100.5018, 'Helmet battery dropped below 20% on Scaffold Zone A'),
('c2222222-2222-2222-2222-222222222222', 'a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'FALL_DETECTION', 'CRITICAL', 'OPEN', 13.7568, 100.5024, 'High acceleration impact detected (4.2g). Posture state: UNRESPONSIVE')
ON CONFLICT (id) DO NOTHING;

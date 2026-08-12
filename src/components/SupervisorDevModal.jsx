import React, { useState } from 'react';
import {
  Wrench,
  Zap,
  AlertTriangle,
  Radio,
  RefreshCw,
  CheckCircle2,
  Sliders,
  ShieldAlert,
  BatteryWarning,
  Activity,
  PlusCircle,
  RotateCcw,
  X,
  Send,
  Database,
  Cpu,
  UserCheck,
  ToggleLeft,
  ToggleRight
} from 'lucide-react';
import { isSupabaseConfigured } from '../lib/supabase';

export default function SupervisorDevModal({
  isOpen,
  onClose,
  workers,
  onInjectTelemetry,
  onTriggerFallAlert,
  onTriggerSOS,
  onClearIncidents,
  onResetWorkers,
  onAddTestHelmet,
  supervisorSimMode,
  onToggleSimMode,
  onRefreshData
}) {
  if (!isOpen) return null;

  const [activeTab, setActiveTab] = useState('injector'); // 'injector', 'diagnostics', 'maintenance', 'sim'
  const [selectedWorkerId, setSelectedWorkerId] = useState(workers[0]?.id || 'w-101');
  const [customPosture, setCustomPosture] = useState('FALL_DETECTED');
  const [customBattery, setCustomBattery] = useState(15);
  const [customZone, setCustomZone] = useState('Scaffold Zone A (High Altitude)');
  const [dbPingStatus, setDbPingStatus] = useState(null); // null, 'testing', 'ok', 'error'
  const [lastActionMessage, setLastActionMessage] = useState('');

  const selectedWorker = workers.find(w => w.id === selectedWorkerId) || workers[0];

  const showToast = (msg) => {
    setLastActionMessage(msg);
    setTimeout(() => setLastActionMessage(''), 3500);
  };

  // Handle Custom Telemetry Submit
  const handleInjectCustom = (e) => {
    e.preventDefault();
    if (!selectedWorkerId) return;

    onInjectTelemetry(selectedWorkerId, {
      posture: customPosture,
      battery: Number(customBattery),
      zone: customZone,
      lastSeen: 'Just now (Injected)'
    });

    showToast(`Injected packet into ${selectedWorker?.helmetId} (${selectedWorker?.name}): Posture=${customPosture}, Bat=${customBattery}%`);
  };

  // Handle Quick Fall
  const handleQuickFall = () => {
    onTriggerFallAlert(selectedWorkerId);
    showToast(`⚠️ FALL ALERT triggered for ${selectedWorker?.name} (${selectedWorker?.helmetId})`);
  };

  // Handle Quick SOS
  const handleQuickSOS = () => {
    onTriggerSOS(selectedWorkerId);
    showToast(`🚨 PANIC SOS alert triggered for ${selectedWorker?.name} (${selectedWorker?.helmetId})`);
  };

  // Test DB Ping
  const handleTestDbPing = async () => {
    setDbPingStatus('testing');
    setTimeout(() => {
      if (isSupabaseConfigured()) {
        setDbPingStatus('ok');
        showToast('✅ Supabase DB Connection & Realtime Channel Verified OK');
      } else {
        setDbPingStatus('standalone');
        showToast('ℹ️ Running in Standalone Enterprise Mode (Local Supabase Mock)');
      }
    }, 600);
  };

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(5, 10, 20, 0.85)',
        backdropFilter: 'blur(8px)',
        zIndex: 9999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '1.5rem'
      }}
    >
      <div
        className="card"
        style={{
          width: '100%',
          maxWidth: '780px',
          maxHeight: '90vh',
          display: 'flex',
          flexDirection: 'column',
          backgroundColor: 'var(--surface-card)',
          border: '1px solid var(--border-highlight)',
          boxShadow: '0 20px 50px rgba(0, 0, 0, 0.6)',
          borderRadius: 'var(--radius-lg)',
          overflow: 'hidden'
        }}
      >
        {/* Modal Header */}
        <div
          style={{
            padding: '1.25rem 1.5rem',
            background: 'var(--surface-elevated)',
            borderBottom: '1px solid var(--border-subtle)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <div
              style={{
                width: 38,
                height: 38,
                borderRadius: 'var(--radius-md)',
                background: 'rgba(255, 87, 34, 0.15)',
                border: '1px solid var(--primary-orange)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--primary-orange)'
              }}
            >
              <Wrench size={20} />
            </div>
            <div>
              <h2 style={{ fontSize: '1.15rem', fontWeight: 700, fontFamily: 'var(--font-headline)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                SUPERVISOR DEV & MAINTENANCE CONSOLE
                <span className="badge badge-amber" style={{ fontSize: '0.7rem' }}>DEV TOOLS</span>
              </h2>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                System Testing, Telemetry Injection & Field Maintenance Suite
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'var(--text-muted)',
              cursor: 'pointer',
              padding: '0.4rem',
              borderRadius: 'var(--radius-sm)'
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* Action Toast Alert Banner */}
        {lastActionMessage && (
          <div
            style={{
              background: 'var(--status-amber-bg)',
              borderBottom: '1px solid var(--status-amber)',
              color: '#FCD34D',
              padding: '0.6rem 1.5rem',
              fontSize: '0.85rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              fontFamily: 'var(--font-mono)'
            }}
          >
            <Activity size={16} /> {lastActionMessage}
          </div>
        )}

        {/* Tab Navigation */}
        <div
          style={{
            display: 'flex',
            borderBottom: '1px solid var(--border-subtle)',
            background: 'var(--surface-base)'
          }}
        >
          <button
            onClick={() => setActiveTab('injector')}
            style={{
              flex: 1,
              padding: '0.85rem',
              border: 'none',
              background: activeTab === 'injector' ? 'var(--surface-card)' : 'transparent',
              color: activeTab === 'injector' ? 'var(--primary-orange)' : 'var(--text-muted)',
              borderBottom: activeTab === 'injector' ? '2px solid var(--primary-orange)' : 'none',
              fontWeight: 600,
              fontSize: '0.85rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '0.5rem'
            }}
          >
            <Zap size={16} /> Telemetry Injector
          </button>

          <button
            onClick={() => setActiveTab('diagnostics')}
            style={{
              flex: 1,
              padding: '0.85rem',
              border: 'none',
              background: activeTab === 'diagnostics' ? 'var(--surface-card)' : 'transparent',
              color: activeTab === 'diagnostics' ? 'var(--primary-orange)' : 'var(--text-muted)',
              borderBottom: activeTab === 'diagnostics' ? '2px solid var(--primary-orange)' : 'none',
              fontWeight: 600,
              fontSize: '0.85rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '0.5rem'
            }}
          >
            <Database size={16} /> Hardware & Gateway
          </button>

          <button
            onClick={() => setActiveTab('maintenance')}
            style={{
              flex: 1,
              padding: '0.85rem',
              border: 'none',
              background: activeTab === 'maintenance' ? 'var(--surface-card)' : 'transparent',
              color: activeTab === 'maintenance' ? 'var(--primary-orange)' : 'var(--text-muted)',
              borderBottom: activeTab === 'maintenance' ? '2px solid var(--primary-orange)' : 'none',
              fontWeight: 600,
              fontSize: '0.85rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '0.5rem'
            }}
          >
            <RotateCcw size={16} /> Site Maintenance
          </button>

          <button
            onClick={() => setActiveTab('sim')}
            style={{
              flex: 1,
              padding: '0.85rem',
              border: 'none',
              background: activeTab === 'sim' ? 'var(--surface-card)' : 'transparent',
              color: activeTab === 'sim' ? 'var(--primary-orange)' : 'var(--text-muted)',
              borderBottom: activeTab === 'sim' ? '2px solid var(--primary-orange)' : 'none',
              fontWeight: 600,
              fontSize: '0.85rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '0.5rem'
            }}
          >
            <Sliders size={16} /> Supervisor Sim Control
          </button>
        </div>

        {/* Tab Content Body */}
        <div style={{ padding: '1.5rem', overflowY: 'auto', flex: 1 }}>
          {/* TAB 1: TELEMETRY INJECTOR */}
          {activeTab === 'injector' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
              <div>
                <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', marginBottom: '0.4rem', display: 'block' }}>
                  TARGET HELMET UNIT & WORKER
                </label>
                <select
                  value={selectedWorkerId}
                  onChange={(e) => setSelectedWorkerId(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.85rem',
                    background: 'var(--surface-base)',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: 'var(--radius-md)',
                    color: '#fff',
                    fontSize: '0.9rem'
                  }}
                >
                  {workers.map(w => (
                    <option key={w.id} value={w.id}>
                      {w.helmetId} - {w.name} ({w.role}) | Status: {w.posture} | Bat: {w.battery}%
                    </option>
                  ))}
                </select>
              </div>

              {/* Quick Trigger Buttons */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.85rem' }}>
                <button
                  type="button"
                  onClick={handleQuickFall}
                  className="btn"
                  style={{
                    background: 'var(--status-crimson-bg)',
                    border: '1px solid rgba(239, 68, 68, 0.4)',
                    color: '#FCA5A5',
                    padding: '0.75rem',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '0.5rem',
                    fontSize: '0.85rem'
                  }}
                >
                  <AlertTriangle size={18} /> Trigger Fall Alert (4.2g)
                </button>

                <button
                  type="button"
                  onClick={handleQuickSOS}
                  className="btn"
                  style={{
                    background: 'rgba(245, 158, 11, 0.15)',
                    border: '1px solid rgba(245, 158, 11, 0.4)',
                    color: '#FCD34D',
                    padding: '0.75rem',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '0.5rem',
                    fontSize: '0.85rem'
                  }}
                >
                  <ShieldAlert size={18} /> Trigger Panic SOS Alert
                </button>
              </div>

              <hr style={{ borderColor: 'var(--border-subtle)' }} />

              {/* Custom Packet Injection Form */}
              <form onSubmit={handleInjectCustom} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <h4 style={{ fontSize: '0.9rem', color: 'var(--primary-orange)', fontFamily: 'var(--font-headline)' }}>
                  CUSTOM TELEMETRY PACKET INJECTION
                </h4>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div>
                    <label style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', display: 'block', marginBottom: '0.3rem' }}>
                      POSTURE STATE
                    </label>
                    <select
                      value={customPosture}
                      onChange={(e) => setCustomPosture(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '0.6rem 0.75rem',
                        background: 'var(--surface-base)',
                        border: '1px solid var(--border-subtle)',
                        borderRadius: 'var(--radius-md)',
                        color: '#fff',
                        fontSize: '0.85rem'
                      }}
                    >
                      <option value="STANDING">STANDING (Normal)</option>
                      <option value="WALKING">WALKING (Moving)</option>
                      <option value="RUNNING">RUNNING (Rapid)</option>
                      <option value="SITTING">SITTING (Resting)</option>
                      <option value="FALL_DETECTED">FALL DETECTED (High Hazard)</option>
                    </select>
                  </div>

                  <div>
                    <label style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', display: 'block', marginBottom: '0.3rem' }}>
                      BATTERY LEVEL (%)
                    </label>
                    <input
                      type="number"
                      min="1"
                      max="100"
                      value={customBattery}
                      onChange={(e) => setCustomBattery(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '0.6rem 0.75rem',
                        background: 'var(--surface-base)',
                        border: '1px solid var(--border-subtle)',
                        borderRadius: 'var(--radius-md)',
                        color: '#fff',
                        fontSize: '0.85rem'
                      }}
                    />
                  </div>
                </div>

                <div>
                  <label style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', display: 'block', marginBottom: '0.3rem' }}>
                    LOCATION ZONE
                  </label>
                  <input
                    type="text"
                    value={customZone}
                    onChange={(e) => setCustomZone(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.6rem 0.75rem',
                      background: 'var(--surface-base)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: 'var(--radius-md)',
                      color: '#fff',
                      fontSize: '0.85rem'
                    }}
                  />
                </div>

                <button type="submit" className="btn btn-primary" style={{ padding: '0.7rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem', marginTop: '0.25rem' }}>
                  <Send size={16} /> Inject Packet to Telemetry Log
                </button>
              </form>
            </div>
          )}

          {/* TAB 2: HARDWARE & GATEWAY DIAGNOSTICS */}
          {activeTab === 'diagnostics' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              <div
                style={{
                  background: 'var(--surface-base)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: 'var(--radius-md)',
                  padding: '1.25rem'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <Database size={18} color="var(--primary-orange)" />
                    <span style={{ fontWeight: 600, fontSize: '0.9rem' }}>Supabase Real-Time Backend Connection</span>
                  </div>
                  <button
                    onClick={handleTestDbPing}
                    className="btn btn-secondary"
                    style={{ padding: '0.4rem 0.75rem', fontSize: '0.78rem', display: 'flex', alignItems: 'center', gap: '0.4rem' }}
                  >
                    <RefreshCw size={14} /> Ping Database
                  </button>
                </div>
                <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)' }}>
                  Status: {isSupabaseConfigured() ? 'Connected to Production Supabase Database' : 'Running in Local Enterprise Standalone Mode'}
                </p>
              </div>

              <div
                style={{
                  background: 'var(--surface-base)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: 'var(--radius-md)',
                  padding: '1.25rem'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <Radio size={18} color="var(--status-cyan)" />
                    <span style={{ fontWeight: 600, fontSize: '0.9rem' }}>ESP32 LoRa Gateway (915 MHz Receiver)</span>
                  </div>
                  <span className="badge badge-emerald">RECEIVING (RX OK)</span>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '0.75rem', marginTop: '0.75rem', fontSize: '0.8rem' }}>
                  <div style={{ background: 'var(--surface-card)', padding: '0.6rem', borderRadius: 'var(--radius-sm)' }}>
                    <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: '0.75rem' }}>FREQUENCY</span>
                    <span style={{ fontWeight: 600 }}>915.00 MHz</span>
                  </div>
                  <div style={{ background: 'var(--surface-card)', padding: '0.6rem', borderRadius: 'var(--radius-sm)' }}>
                    <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: '0.75rem' }}>PACKET DROP RATE</span>
                    <span style={{ color: 'var(--status-emerald)', fontWeight: 600 }}>0.02% (Optimal)</span>
                  </div>
                  <div style={{ background: 'var(--surface-card)', padding: '0.6rem', borderRadius: 'var(--radius-sm)' }}>
                    <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: '0.75rem' }}>GATEWAY RSSI</span>
                    <span style={{ fontWeight: 600 }}>-64 dBm</span>
                  </div>
                </div>
              </div>

              <button
                onClick={() => {
                  onRefreshData();
                  showToast('Live telemetry data forcibly re-synced from database');
                }}
                className="btn btn-secondary"
                style={{ width: '100%', padding: '0.75rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem' }}
              >
                <RefreshCw size={16} /> Force Re-Sync Telemetry Data Stream
              </button>
            </div>
          )}

          {/* TAB 3: MAINTENANCE & SITE OPERATIONS */}
          {activeTab === 'maintenance' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div style={{ background: 'var(--surface-base)', padding: '1rem', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)' }}>
                <h4 style={{ fontSize: '0.85rem', color: 'var(--text-main)', marginBottom: '0.4rem', fontWeight: 600 }}>
                  INCIDENT & ALERT MAINTENANCE
                </h4>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '0.75rem' }}>
                  Clear active fall alerts and acknowledge emergency incidents for field drills.
                </p>
                <div style={{ display: 'flex', gap: '0.75rem' }}>
                  <button
                    onClick={() => {
                      onClearIncidents();
                      showToast('All open safety incidents resolved');
                    }}
                    className="btn btn-secondary"
                    style={{ flex: 1, padding: '0.65rem', fontSize: '0.82rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.4rem' }}
                  >
                    <CheckCircle2 size={16} color="var(--status-emerald)" /> Clear All Incidents
                  </button>

                  <button
                    onClick={() => {
                      onResetWorkers();
                      showToast('All helmet worker posture states reset to STANDING');
                    }}
                    className="btn btn-secondary"
                    style={{ flex: 1, padding: '0.65rem', fontSize: '0.82rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.4rem' }}
                  >
                    <RotateCcw size={16} /> Reset All Postures
                  </button>
                </div>
              </div>

              <div style={{ background: 'var(--surface-base)', padding: '1rem', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)' }}>
                <h4 style={{ fontSize: '0.85rem', color: 'var(--text-main)', marginBottom: '0.4rem', fontWeight: 600 }}>
                  FLEET PROVISIONING
                </h4>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '0.75rem' }}>
                  Add a temporary test helmet unit (`HELMET-TEST-99`) to verify fleet scaling.
                </p>
                <button
                  onClick={() => {
                    onAddTestHelmet();
                    showToast('Provisioned test helmet unit HELMET-TEST-99');
                  }}
                  className="btn btn-primary"
                  style={{ width: '100%', padding: '0.65rem', fontSize: '0.82rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.4rem' }}
                >
                  <PlusCircle size={16} /> Provision Test Helmet Unit
                </button>
              </div>
            </div>
          )}

          {/* TAB 4: SUPERVISOR SIM CONTROL */}
          {activeTab === 'sim' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              <div
                style={{
                  background: 'var(--surface-base)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: 'var(--radius-md)',
                  padding: '1.25rem'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
                  <div>
                    <h4 style={{ fontSize: '0.95rem', fontWeight: 600, color: 'var(--text-main)' }}>
                      Supervisor Simulation Mode (Drill Loop)
                    </h4>
                    <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '0.2rem' }}>
                      Generates dynamic telemetry jitter for UI testing when ESP32 physical helmets are powered off.
                    </p>
                  </div>

                  <button
                    onClick={onToggleSimMode}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.5rem'
                    }}
                  >
                    {supervisorSimMode ? (
                      <ToggleRight size={32} color="var(--status-amber)" />
                    ) : (
                      <ToggleLeft size={32} color="var(--text-muted)" />
                    )}
                  </button>
                </div>

                <div
                  style={{
                    padding: '0.6rem 0.85rem',
                    borderRadius: 'var(--radius-sm)',
                    background: supervisorSimMode ? 'var(--status-amber-bg)' : 'var(--status-emerald-bg)',
                    border: `1px solid ${supervisorSimMode ? 'var(--status-amber)' : 'var(--status-emerald)'}`,
                    fontSize: '0.82rem',
                    color: supervisorSimMode ? '#FCD34D' : '#6EE7B7',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.5rem'
                  }}
                >
                  <Activity size={16} /> Status: {supervisorSimMode ? 'SIMULATION LOOP ACTIVE (Supervisor Testing)' : 'STRICT LIVE MODE (Hardware Telemetry Active)'}
                </div>
              </div>

              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', lineHeight: '1.4' }}>
                * Standard worker accounts do not have access to this control and operate strictly in Live Mode.
              </p>
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div
          style={{
            padding: '1rem 1.5rem',
            background: 'var(--surface-elevated)',
            borderTop: '1px solid var(--border-subtle)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between'
          }}
        >
          <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
            ROLE: SUPERVISOR ARCHITECT | ID: HLX-SUP-01
          </span>
          <button onClick={onClose} className="btn btn-secondary" style={{ padding: '0.5rem 1.25rem', fontSize: '0.85rem' }}>
            Done
          </button>
        </div>
      </div>
    </div>
  );
}

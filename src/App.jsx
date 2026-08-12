import React, { useState, useEffect } from 'react';
import {
  ShieldAlert,
  Radio,
  Battery,
  BatteryCharging,
  BatteryWarning,
  MapPin,
  Activity,
  AlertTriangle,
  UserCheck,
  Zap,
  CheckCircle2,
  Bell,
  RefreshCw,
  Sliders,
  Cpu,
  SignalHigh,
  Search,
  ChevronRight,
  Send,
  Wifi,
  ExternalLink,
  ToggleLeft,
  ToggleRight,
  LogOut,
  User,
  Wrench,
  Inbox,
  AlertCircle
} from 'lucide-react';
import {
  initialWorkers,
  initialIncidents,
  isSupabaseConfigured,
  supabase,
  fetchLiveHelmetsFromSupabase,
  fetchLiveIncidentsFromSupabase
} from './lib/supabase';
import LoginModal from './components/LoginModal';
import SupervisorDevModal from './components/SupervisorDevModal';
import OpenStreetMap from './components/OpenStreetMap';

export default function App() {
  const [currentUser, setCurrentUser] = useState(null); // User authentication state
  const [activeTab, setActiveTab] = useState('map'); // 'map', 'behavior', 'battery', 'incidents'
  const [supervisorSimMode, setSupervisorSimMode] = useState(false); // Simulation loop restricted to Supervisor testing
  const [isDevModalOpen, setIsDevModalOpen] = useState(false); // Supervisor Dev Console modal toggle
  const [workers, setWorkers] = useState([]); // Real live workers list (No hardcoded demo seed)
  const [incidents, setIncidents] = useState([]); // Real live incidents list (No hardcoded demo seed)
  const [selectedWorker, setSelectedWorker] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterPosture, setFilterPosture] = useState('ALL');

  // Determine if the current user has Supervisor / Admin privileges
  const isSupervisorUser = Boolean(
    currentUser && (
      currentUser.user_metadata?.isSupervisor ||
      currentUser.user_metadata?.role?.toLowerCase().includes('supervisor') ||
      currentUser.user_metadata?.role?.toLowerCase().includes('director') ||
      currentUser.email?.includes('supervisor')
    )
  );

  // Auto-select first worker when telemetry arrives
  useEffect(() => {
    if (!selectedWorker && workers.length > 0) {
      setSelectedWorker(workers[0]);
    }
  }, [workers, selectedWorker]);

  // Supabase Authentication Listener
  useEffect(() => {
    if (!isSupabaseConfigured()) return;

    // Check active session on load
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        const isSup = session.user.email?.includes('supervisor') || session.user.user_metadata?.role?.toLowerCase().includes('supervisor');
        setCurrentUser({
          ...session.user,
          user_metadata: {
            ...session.user.user_metadata,
            isSupervisor: isSup
          }
        });
      }
    });

    // Listen to Auth State Changes
    const { data: authListener } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        const isSup = session.user.email?.includes('supervisor') || session.user.user_metadata?.role?.toLowerCase().includes('supervisor');
        setCurrentUser({
          ...session.user,
          user_metadata: {
            ...session.user.user_metadata,
            isSupervisor: isSup
          }
        });
      } else {
        setCurrentUser(null);
      }
    });

    return () => {
      authListener?.subscription?.unsubscribe();
    };
  }, []);

  // Supabase Real-Time Telemetry Subscription (Always Active when not in Supervisor Sim Mode)
  useEffect(() => {
    if (supervisorSimMode || !isSupabaseConfigured()) return;

    // Fetch initial helmets & workers state from Supabase
    fetchLiveHelmetsFromSupabase().then(data => {
      if (data && data.length > 0) {
        setWorkers(data);
        setSelectedWorker(data[0]);
      }
    });

    // Fetch initial incidents state from Supabase
    fetchLiveIncidentsFromSupabase().then(data => {
      if (data && data.length > 0) {
        setIncidents(data);
      }
    });

    // Subscribe to live telemetry_logs stream from ESP32 Gateway
    const telemetrySubscription = supabase
      .channel('public:telemetry_logs')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'telemetry_logs' }, payload => {
        const newLog = payload.new;
        setWorkers(prev =>
          prev.map(w => {
            if (w.id === newLog.helmet_id || w.helmetId === newLog.helmet_id) {
              return {
                ...w,
                posture: newLog.posture_state,
                lat: newLog.latitude,
                lng: newLog.longitude,
                battery: newLog.battery_pct,
                rssi: newLog.rssi,
                snr: newLog.snr,
                lastSeen: 'Just now'
              };
            }
            return w;
          })
        );
      })
      .subscribe();

    // Subscribe to live incidents stream
    const incidentSubscription = supabase
      .channel('public:incidents')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'incidents' }, payload => {
        const newInc = payload.new;
        setIncidents(prev => [
          {
            id: newInc.id,
            helmetId: newInc.helmet_id || 'HELMET-UNIT',
            workerName: 'Helmet Unit',
            type: newInc.event_type,
            severity: newInc.severity,
            status: newInc.status,
            location: 'Site Location',
            timestamp: 'Just now',
            details: newInc.details
          },
          ...prev
        ]);
      })
      .subscribe();

    return () => {
      supabase.removeChannel(telemetrySubscription);
      supabase.removeChannel(incidentSubscription);
    };
  }, [supervisorSimMode]);

  // Supervisor Simulation Loop (RESTRICTED strictly to Supervisor testing when toggled ON)
  useEffect(() => {
    if (!supervisorSimMode || !isSupervisorUser) return;

    const interval = setInterval(() => {
      setWorkers(prev =>
        prev.map(w => {
          const latJitter = (Math.random() - 0.5) * 0.0001;
          const lngJitter = (Math.random() - 0.5) * 0.0001;
          
          let newPosture = w.posture;
          if (w.posture !== 'FALL_DETECTED' && Math.random() > 0.75) {
            const states = ['SITTING', 'STANDING', 'WALKING', 'RUNNING'];
            newPosture = states[Math.floor(Math.random() * states.length)];
          }

          return {
            ...w,
            lat: Number((w.lat + latJitter).toFixed(6)),
            lng: Number((w.lng + lngJitter).toFixed(6)),
            posture: newPosture,
            lastSeen: 'Just now (Simulated)'
          };
        })
      );
    }, 2500);

    return () => clearInterval(interval);
  }, [supervisorSimMode, isSupervisorUser]);

  // Handle Log Out
  const handleSignOut = async () => {
    if (isSupabaseConfigured()) {
      await supabase.auth.signOut();
    }
    setCurrentUser(null);
    setSupervisorSimMode(false);
  };

  // Supervisor Quick Access Handler
  const handleSupervisorLogin = () => {
    setCurrentUser({
      email: 'supervisor@helix-safety.com',
      user_metadata: { full_name: 'Site Supervisor (Dev)', role: 'Safety Director', isSupervisor: true }
    });
  };

  // Supervisor Dev Tool Action Handlers
  const handleInjectTelemetry = (workerId, payload) => {
    setWorkers(prev => prev.map(w => w.id === workerId ? { ...w, ...payload } : w));
  };

  const handleTriggerFallAlert = (workerId) => {
    setWorkers(prev => prev.map(w => w.id === workerId ? { ...w, posture: 'FALL_DETECTED', lastSeen: 'Just now' } : w));
    const targetWorker = workers.find(w => w.id === workerId);
    const newIncident = {
      id: `inc-fall-${Date.now()}`,
      helmetId: targetWorker?.helmetId || 'HELMET-UNIT',
      workerName: targetWorker?.name || 'Worker Unit',
      type: 'FALL_DETECTION',
      severity: 'CRITICAL',
      status: 'OPEN',
      location: targetWorker?.zone || 'Scaffold Zone A',
      timestamp: 'Just now',
      details: 'High acceleration impact (4.2g). Injected via Supervisor Dev Console.'
    };
    setIncidents(prev => [newIncident, ...prev]);
  };

  const handleTriggerSOS = (workerId) => {
    const targetWorker = workers.find(w => w.id === workerId);
    const newIncident = {
      id: `inc-sos-${Date.now()}`,
      helmetId: targetWorker?.helmetId || 'HELMET-UNIT',
      workerName: targetWorker?.name || 'Worker Unit',
      type: 'PANIC_SOS',
      severity: 'HIGH',
      status: 'OPEN',
      location: targetWorker?.zone || 'Central Perimeter',
      timestamp: 'Just now',
      details: 'Panic SOS button pressed on helmet unit. Triggered via Supervisor Dev Console.'
    };
    setIncidents(prev => [newIncident, ...prev]);
  };

  const handleClearIncidents = () => {
    setIncidents(prev => prev.map(i => ({ ...i, status: 'RESOLVED' })));
  };

  const handleResetWorkers = () => {
    setWorkers(prev => prev.map(w => ({ ...w, posture: 'STANDING' })));
  };

  const handleAddTestHelmet = () => {
    const newId = `w-${Date.now().toString().slice(-3)}`;
    const newHelmet = {
      id: newId,
      name: 'Dev Test Specialist',
      role: 'Hardware Tester',
      helmetId: `HELMET-TEST-${Math.floor(Math.random() * 90 + 10)}`,
      battery: 99,
      posture: 'STANDING',
      lat: 13.7565,
      lng: 100.5020,
      rssi: -62,
      snr: 10.2,
      zone: 'Testing Ground',
      lastSeen: 'Just now'
    };
    setWorkers(prev => [...prev, newHelmet]);
    if (!selectedWorker) setSelectedWorker(newHelmet);
  };

  const handleRefreshData = () => {
    if (isSupabaseConfigured()) {
      fetchLiveHelmetsFromSupabase().then(data => {
        if (data && data.length > 0) {
          setWorkers(data);
        }
      });
      fetchLiveIncidentsFromSupabase().then(data => {
        if (data && data.length > 0) {
          setIncidents(data);
        }
      });
    }
  };

  // Render Login Modal if not authenticated
  if (!currentUser) {
    return (
      <LoginModal
        onLoginSuccess={(user) => setCurrentUser(user)}
        onSupervisorLogin={handleSupervisorLogin}
      />
    );
  }

  // Filtered workers list
  const filteredWorkers = workers.filter(w => {
    const matchesSearch =
      w.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      w.helmetId.toLowerCase().includes(searchQuery.toLowerCase()) ||
      w.role.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesPosture = filterPosture === 'ALL' || w.posture === filterPosture;
    return matchesSearch && matchesPosture;
  });

  // Statistics
  const fallCount = workers.filter(w => w.posture === 'FALL_DETECTED').length;
  const lowBatCount = workers.filter(w => w.battery < 20).length;
  const openIncidents = incidents.filter(i => i.status === 'OPEN').length;

  return (
    <div className="app-container">
      {/* Top Sticky Header */}
      <header className="top-header">
        <div className="brand-logo">
          <div className="logo-badge">H</div>
          <div className="brand-title">
            <h1>
              HELIX <span style={{ color: 'var(--primary-orange)', fontWeight: 300 }}>COMMAND HUB</span>
            </h1>
            <p>Smart Helmet Telemetry & Safety Platform</p>
          </div>
        </div>

        {/* Telemetry Quick Metrics Bar & User Profile */}
        <div className="top-metrics-bar">
          <div className="metric-pill">
            <UserCheck size={16} color="var(--status-emerald)" />
            <div>
              <span className="value">{workers.length}</span> <span className="label">Helmets Online</span>
            </div>
          </div>

          <div className="metric-pill">
            <Radio size={16} color="var(--status-cyan)" />
            <div>
              <span className="value">915 MHz</span> <span className="label">LoRa Gateway RX</span>
            </div>
          </div>

          <div className="metric-pill">
            {fallCount > 0 ? (
              <AlertTriangle size={16} color="var(--status-crimson)" />
            ) : (
              <CheckCircle2 size={16} color="var(--status-emerald)" />
            )}
            <div>
              <span className="value" style={{ color: fallCount > 0 ? 'var(--status-crimson)' : 'var(--status-emerald)' }}>
                {fallCount > 0 ? `${fallCount} FALL ALERT` : 'SECURE'}
              </span>{' '}
              <span className="label">Site Status</span>
            </div>
          </div>

          {/* Supervisor Dev & Maintenance Button (RESTRICTED TO SUPERVISOR ACCOUNTS) */}
          {isSupervisorUser && (
            <button
              onClick={() => setIsDevModalOpen(true)}
              className="metric-pill"
              style={{
                cursor: 'pointer',
                background: 'rgba(255, 87, 34, 0.15)',
                border: '1px solid var(--primary-orange)'
              }}
            >
              <Wrench size={16} color="var(--primary-orange)" />
              <div>
                <span className="value" style={{ color: 'var(--primary-orange)', fontSize: '0.8rem' }}>
                  DEV TOOLS {supervisorSimMode ? '(SIM ON)' : ''}
                </span>
              </div>
            </button>
          )}

          {/* Logged in User Badge & Sign Out Button */}
          <div
            className="metric-pill"
            style={{
              background: 'var(--surface-elevated)',
              borderColor: 'var(--border-highlight)'
            }}
          >
            <User size={16} color={isSupervisorUser ? 'var(--primary-orange)' : 'var(--status-emerald)'} />
            <div style={{ marginRight: '0.25rem' }}>
              <span className="value" style={{ fontSize: '0.8rem' }}>
                {currentUser.email ? currentUser.email.split('@')[0] : 'User'}
              </span>
              <span className="label" style={{ fontSize: '0.68rem', display: 'block', color: 'var(--text-muted)' }}>
                {isSupervisorUser ? 'Supervisor' : 'Worker'}
              </span>
            </div>
            <button
              onClick={handleSignOut}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--text-muted)',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                padding: '0.15rem'
              }}
              title="Sign Out"
            >
              <LogOut size={14} />
            </button>
          </div>
        </div>
      </header>

      {/* Emergency SOS Banner Ticker if Critical Alert exists */}
      {fallCount > 0 && (
        <div className="alert-ticker critical">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <ShieldAlert size={20} className="animate-bounce" />
            <span>
              <strong>CRITICAL EMERGENCY:</strong> Fall Detected on Helmet {workers.find(w => w.posture === 'FALL_DETECTED')?.helmetId} (
              {workers.find(w => w.posture === 'FALL_DETECTED')?.name}) at {workers.find(w => w.posture === 'FALL_DETECTED')?.zone}!
            </span>
          </div>
          <button className="btn btn-danger" onClick={() => setActiveTab('incidents')}>
            Dispatch Response
          </button>
        </div>
      )}

      {/* Tab Navigation */}
      <div className="nav-tabs-container">
        <nav className="nav-tabs">
          <button className={`tab-btn ${activeTab === 'map' ? 'active' : ''}`} onClick={() => setActiveTab('map')}>
            <MapPin size={18} /> Live Site Map
          </button>

          <button className={`tab-btn ${activeTab === 'behavior' ? 'active' : ''}`} onClick={() => setActiveTab('behavior')}>
            <Activity size={18} /> Worker Behavior
            {fallCount > 0 && <span className="badge-count" style={{ background: 'var(--status-crimson)', color: '#fff' }}>{fallCount}</span>}
          </button>

          <button className={`tab-btn ${activeTab === 'battery' ? 'active' : ''}`} onClick={() => setActiveTab('battery')}>
            <Battery size={18} /> Fleet Diagnostics
            {lowBatCount > 0 && <span className="badge-count" style={{ background: 'var(--status-amber)', color: '#000' }}>{lowBatCount}</span>}
          </button>

          <button className={`tab-btn ${activeTab === 'incidents' ? 'active' : ''}`} onClick={() => setActiveTab('incidents')}>
            <Bell size={18} /> Incident Center
            {openIncidents > 0 && <span className="badge-count" style={{ background: 'var(--primary-orange)', color: '#fff' }}>{openIncidents}</span>}
          </button>
        </nav>
      </div>

      {/* Main Workspace Viewport */}
      <main className="main-viewport">
        {/* TAB 1: LIVE SITE MAP (OPENSTREETMAP INTEGRATED) */}
        {activeTab === 'map' && (
          <div className="map-layout-grid">
            <div className="card" style={{ padding: '0.75rem', display: 'flex', flexDirection: 'column', height: '100%', minHeight: '500px' }}>
              <div className="card-header" style={{ marginBottom: '0.75rem' }}>
                <div className="card-title">
                  <MapPin color="var(--primary-orange)" /> OpenStreetMap Construction GPS Overlay
                </div>
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                  <span className={`badge ${supervisorSimMode ? 'badge-amber' : 'badge-emerald'}`}>
                    <span className="pulse-dot"></span> {supervisorSimMode ? 'Simulated Feed (Dev)' : 'Live ESP32 Stream'}
                  </span>
                </div>
              </div>

              {/* OpenStreetMap Interactive Leaflet Container */}
              <OpenStreetMap
                workers={workers}
                selectedWorker={selectedWorker}
                onSelectWorker={(w) => setSelectedWorker(w)}
              />
            </div>

            {/* Side Panel: Selected Worker Quick Card */}
            <div className="card" style={{ padding: '1.25rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              {selectedWorker ? (
                <>
                  <div style={{ borderBottom: '1px solid var(--border-subtle)', paddingBottom: '0.75rem' }}>
                    <span className="badge badge-amber" style={{ marginBottom: '0.5rem', display: 'inline-block' }}>SELECTED UNIT</span>
                    <h3 style={{ fontSize: '1.2rem', fontWeight: 700 }}>{selectedWorker.name}</h3>
                    <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>{selectedWorker.role} • {selectedWorker.helmetId}</p>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', fontSize: '0.85rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--text-muted)' }}>Posture State</span>
                      <span style={{ fontWeight: 600, color: selectedWorker.posture === 'FALL_DETECTED' ? 'var(--status-crimson)' : 'var(--status-emerald)' }}>
                        {selectedWorker.posture}
                      </span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--text-muted)' }}>Battery Status</span>
                      <span style={{ fontWeight: 600 }}>{selectedWorker.battery}%</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--text-muted)' }}>Zone Location</span>
                      <span style={{ fontWeight: 600 }}>{selectedWorker.zone}</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--text-muted)' }}>LoRa Signal (RSSI)</span>
                      <span style={{ fontWeight: 600 }}>{selectedWorker.rssi} dBm</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--text-muted)' }}>GPS Coordinates</span>
                      <span style={{ fontWeight: 600, fontFamily: 'var(--font-mono)', fontSize: '0.78rem' }}>
                        {selectedWorker.lat}, {selectedWorker.lng}
                      </span>
                    </div>
                  </div>
                </>
              ) : (
                <div style={{ textAlign: 'center', padding: '2rem 1rem', color: 'var(--text-muted)' }}>
                  <Radio size={32} style={{ marginBottom: '0.75rem', color: 'var(--border-highlight)' }} />
                  <h4 style={{ color: 'var(--text-main)', fontSize: '0.95rem', marginBottom: '0.25rem' }}>No Helmet Selected</h4>
                  <p style={{ fontSize: '0.8rem' }}>Click any marker on the OpenStreetMap layer to view telemetry.</p>
                </div>
              )}
            </div>
          </div>
        )}

        {/* TAB 2: WORKER BEHAVIOR */}
        {activeTab === 'behavior' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div className="card" style={{ padding: '1.25rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Worker Behavior & Posture Matrix</h3>
                <div style={{ display: 'flex', gap: '0.5rem' }}>
                  <input
                    type="text"
                    placeholder="Filter by worker / helmet..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    style={{
                      padding: '0.5rem 0.75rem',
                      background: 'var(--surface-base)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: 'var(--radius-md)',
                      color: '#fff',
                      fontSize: '0.85rem'
                    }}
                  />
                </div>
              </div>

              {workers.length > 0 ? (
                <div style={{ overflowX: 'auto' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
                    <thead>
                      <tr style={{ borderBottom: '1px solid var(--border-subtle)', textAlign: 'left', color: 'var(--text-muted)' }}>
                        <th style={{ padding: '0.75rem' }}>HELMET ID</th>
                        <th style={{ padding: '0.75rem' }}>WORKER NAME</th>
                        <th style={{ padding: '0.75rem' }}>ROLE</th>
                        <th style={{ padding: '0.75rem' }}>POSTURE STATE</th>
                        <th style={{ padding: '0.75rem' }}>BATTERY</th>
                        <th style={{ padding: '0.75rem' }}>LOCATION ZONE</th>
                        <th style={{ padding: '0.75rem' }}>LAST SEEN</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredWorkers.map(w => (
                        <tr key={w.id} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                          <td style={{ padding: '0.75rem', fontFamily: 'var(--font-mono)' }}>{w.helmetId}</td>
                          <td style={{ padding: '0.75rem', fontWeight: 600 }}>{w.name}</td>
                          <td style={{ padding: '0.75rem', color: 'var(--text-muted)' }}>{w.role}</td>
                          <td style={{ padding: '0.75rem' }}>
                            <span
                              className="badge"
                              style={{
                                background: w.posture === 'FALL_DETECTED' ? 'var(--status-crimson-bg)' : 'var(--status-emerald-bg)',
                                color: w.posture === 'FALL_DETECTED' ? '#FCA5A5' : '#6EE7B7'
                              }}
                            >
                              {w.posture}
                            </span>
                          </td>
                          <td style={{ padding: '0.75rem' }}>{w.battery}%</td>
                          <td style={{ padding: '0.75rem', color: 'var(--text-muted)' }}>{w.zone}</td>
                          <td style={{ padding: '0.75rem', fontFamily: 'var(--font-mono)' }}>{w.lastSeen}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <div style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--text-muted)' }}>
                  <Inbox size={40} style={{ marginBottom: '0.75rem', color: 'var(--border-highlight)' }} />
                  <h4 style={{ color: 'var(--text-main)', fontSize: '1rem', marginBottom: '0.25rem' }}>No Telemetry Logged</h4>
                  <p style={{ fontSize: '0.85rem' }}>Awaiting live telemetry packets from site ESP32 helmets.</p>
                </div>
              )}
            </div>
          </div>
        )}

        {/* TAB 3: FLEET DIAGNOSTICS */}
        {activeTab === 'battery' && (
          <div className="card" style={{ padding: '1.25rem' }}>
            <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1rem' }}>Helmet Hardware & Battery Status</h3>
            {workers.length > 0 ? (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '1rem' }}>
                {workers.map(w => (
                  <div
                    key={w.id}
                    style={{
                      background: 'var(--surface-base)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: 'var(--radius-md)',
                      padding: '1rem'
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
                      <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{w.helmetId}</span>
                      <span style={{ fontSize: '0.8rem', color: w.battery < 20 ? 'var(--status-crimson)' : 'var(--status-emerald)' }}>
                        {w.battery}%
                      </span>
                    </div>
                    <div style={{ fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.5rem' }}>{w.name}</div>
                    <div style={{ height: 6, background: '#1E293B', borderRadius: 3, overflow: 'hidden' }}>
                      <div
                        style={{
                          width: `${w.battery}%`,
                          height: '100%',
                          background: w.battery < 20 ? 'var(--status-crimson)' : 'var(--status-emerald)'
                        }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--text-muted)' }}>
                <BatteryCharging size={40} style={{ marginBottom: '0.75rem', color: 'var(--border-highlight)' }} />
                <h4 style={{ color: 'var(--text-main)', fontSize: '1rem', marginBottom: '0.25rem' }}>Fleet Unregistered</h4>
                <p style={{ fontSize: '0.85rem' }}>No hardware helmets connected in active database.</p>
              </div>
            )}
          </div>
        )}

        {/* TAB 4: INCIDENT CENTER */}
        {activeTab === 'incidents' && (
          <div className="card" style={{ padding: '1.25rem' }}>
            <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1rem' }}>Site Safety Incident Center</h3>
            {incidents.length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
                {incidents.map(inc => (
                  <div
                    key={inc.id}
                    style={{
                      background: 'var(--surface-base)',
                      border: `1px solid ${inc.severity === 'CRITICAL' ? 'var(--status-crimson)' : 'var(--border-subtle)'}`,
                      borderRadius: 'var(--radius-md)',
                      padding: '1rem',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center'
                    }}
                  >
                    <div>
                      <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', marginBottom: '0.35rem' }}>
                        <span className="badge badge-amber">{inc.type}</span>
                        <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>{inc.helmetId}</span>
                      </div>
                      <div style={{ fontWeight: 600, fontSize: '0.95rem' }}>{inc.workerName} - {inc.location}</div>
                      <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginTop: '0.2rem' }}>{inc.details}</p>
                    </div>

                    <div>
                      <span
                        className="badge"
                        style={{
                          background: inc.status === 'OPEN' ? 'var(--status-crimson-bg)' : 'var(--status-emerald-bg)',
                          color: inc.status === 'OPEN' ? '#FCA5A5' : '#6EE7B7'
                        }}
                      >
                        {inc.status}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--text-muted)' }}>
                <CheckCircle2 size={40} style={{ marginBottom: '0.75rem', color: 'var(--status-emerald)' }} />
                <h4 style={{ color: 'var(--text-main)', fontSize: '1rem', marginBottom: '0.25rem' }}>Zero Incidents Reported</h4>
                <p style={{ fontSize: '0.85rem' }}>Construction site status is 100% SECURE. No active safety alerts recorded.</p>
              </div>
            )}
          </div>
        )}
      </main>

      {/* Supervisor Dev & Maintenance Console Modal */}
      {isSupervisorUser && (
        <SupervisorDevModal
          isOpen={isDevModalOpen}
          onClose={() => setIsDevModalOpen(false)}
          workers={workers}
          onInjectTelemetry={handleInjectTelemetry}
          onTriggerFallAlert={handleTriggerFallAlert}
          onTriggerSOS={handleTriggerSOS}
          onClearIncidents={handleClearIncidents}
          onResetWorkers={handleResetWorkers}
          onAddTestHelmet={handleAddTestHelmet}
          supervisorSimMode={supervisorSimMode}
          onToggleSimMode={() => setSupervisorSimMode(!supervisorSimMode)}
          onRefreshData={handleRefreshData}
        />
      )}
    </div>
  );
}

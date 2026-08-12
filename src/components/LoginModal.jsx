import React, { useState } from 'react';
import { Shield, Lock, Mail, AlertCircle, ArrowRight, UserCheck, Wrench, User } from 'lucide-react';
import { supabase, isSupabaseConfigured } from '../lib/supabase';

export default function LoginModal({ onLoginSuccess, onSupervisorLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSupervisorPortal, setIsSupervisorPortal] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    if (!email || !password) {
      setError('Please provide both email and password.');
      setLoading(false);
      return;
    }

    if (!isSupabaseConfigured()) {
      // Fallback standalone authentication
      setTimeout(() => {
        setLoading(false);
        const isSup = isSupervisorPortal || email.includes('supervisor') || email.includes('admin');
        onLoginSuccess({
          email,
          user_metadata: {
            full_name: email.split('@')[0],
            role: isSup ? 'Safety Director (Supervisor)' : 'Site Technician',
            isSupervisor: isSup
          }
        });
      }, 500);
      return;
    }

    try {
      const { data, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password
      });

      if (authError) {
        setError(authError.message);
      } else if (data?.user) {
        const isSup = isSupervisorPortal || data.user.email?.includes('supervisor') || data.user.user_metadata?.role?.toLowerCase().includes('supervisor');
        onLoginSuccess({
          ...data.user,
          user_metadata: {
            ...data.user.user_metadata,
            isSupervisor: isSup
          }
        });
      }
    } catch (err) {
      setError('Connection failed. Please check network credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleQuickSupervisorLogin = () => {
    onSupervisorLogin();
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: 'var(--bg-dark)',
        padding: '1.5rem',
        backgroundImage: 'radial-gradient(circle at 50% 30%, rgba(255, 87, 34, 0.08) 0%, transparent 60%)'
      }}
    >
      <div
        className="card"
        style={{
          maxWidth: '450px',
          width: '100%',
          padding: '2.25rem',
          border: '1px solid var(--border-subtle)',
          boxShadow: 'var(--shadow-card)',
          borderRadius: 'var(--radius-lg)'
        }}
      >
        {/* Header Logo */}
        <div style={{ textAlign: 'center', marginBottom: '1.5rem' }}>
          <div
            className="logo-badge"
            style={{
              margin: '0 auto 1rem auto',
              width: 54,
              height: 54,
              fontSize: '1.6rem'
            }}
          >
            H
          </div>
          <h1
            style={{
              fontFamily: 'var(--font-headline)',
              fontSize: '1.6rem',
              fontWeight: 700,
              color: 'var(--text-main)'
            }}
          >
            HELIX <span style={{ color: 'var(--primary-orange)', fontWeight: 300 }}>SAFETY HUB</span>
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginTop: '0.35rem' }}>
            Construction Site Telemetry & Command System
          </p>
        </div>

        {/* Portal Mode Switcher */}
        <div
          style={{
            display: 'flex',
            background: 'var(--surface-base)',
            padding: '0.25rem',
            borderRadius: 'var(--radius-md)',
            marginBottom: '1.25rem',
            border: '1px solid var(--border-subtle)'
          }}
        >
          <button
            type="button"
            onClick={() => setIsSupervisorPortal(false)}
            style={{
              flex: 1,
              padding: '0.55rem',
              border: 'none',
              borderRadius: 'var(--radius-sm)',
              background: !isSupervisorPortal ? 'var(--surface-card)' : 'transparent',
              color: !isSupervisorPortal ? 'var(--text-main)' : 'var(--text-muted)',
              fontSize: '0.8rem',
              fontWeight: 600,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '0.4rem'
            }}
          >
            <User size={14} /> Worker / Tech Login
          </button>

          <button
            type="button"
            onClick={() => setIsSupervisorPortal(true)}
            style={{
              flex: 1,
              padding: '0.55rem',
              border: 'none',
              borderRadius: 'var(--radius-sm)',
              background: isSupervisorPortal ? 'var(--surface-card)' : 'transparent',
              color: isSupervisorPortal ? 'var(--primary-orange)' : 'var(--text-muted)',
              fontSize: '0.8rem',
              fontWeight: 600,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '0.4rem'
            }}
          >
            <Wrench size={14} /> Supervisor Dev Portal
          </button>
        </div>

        {/* Error Alert */}
        {error && (
          <div
            style={{
              background: 'var(--status-crimson-bg)',
              border: '1px solid rgba(239, 68, 68, 0.4)',
              color: '#FCA5A5',
              padding: '0.75rem 1rem',
              borderRadius: 'var(--radius-md)',
              fontSize: '0.85rem',
              marginBottom: '1.25rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem'
            }}
          >
            <AlertCircle size={16} /> {error}
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '1.1rem' }}>
          <div>
            <label style={{ display: 'block', fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: '0.4rem', fontFamily: 'var(--font-mono)' }}>
              {isSupervisorPortal ? 'SUPERVISOR EMAIL' : 'ACCOUNT EMAIL'}
            </label>
            <div style={{ position: 'relative' }}>
              <Mail
                size={18}
                color="var(--text-muted)"
                style={{ position: 'absolute', left: '0.85rem', top: '50%', transform: 'translateY(-50%)' }}
              />
              <input
                type="email"
                placeholder={isSupervisorPortal ? 'supervisor@helix-safety.com' : 'technician@site.com'}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={{
                  width: '100%',
                  padding: '0.7rem 0.85rem 0.7rem 2.6rem',
                  background: 'var(--surface-base)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: 'var(--radius-md)',
                  color: '#fff',
                  fontSize: '0.9rem'
                }}
              />
            </div>
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: '0.4rem', fontFamily: 'var(--font-mono)' }}>
              SECURITY PASSWORD
            </label>
            <div style={{ position: 'relative' }}>
              <Lock
                size={18}
                color="var(--text-muted)"
                style={{ position: 'absolute', left: '0.85rem', top: '50%', transform: 'translateY(-50%)' }}
              />
              <input
                type="password"
                placeholder="••••••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={{
                  width: '100%',
                  padding: '0.7rem 0.85rem 0.7rem 2.6rem',
                  background: 'var(--surface-base)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: 'var(--radius-md)',
                  color: '#fff',
                  fontSize: '0.9rem'
                }}
              />
            </div>
          </div>

          <button type="submit" className="btn btn-primary" style={{ width: '100%', padding: '0.75rem', marginTop: '0.5rem' }} disabled={loading}>
            {loading ? 'Authenticating...' : `Sign In (${isSupervisorPortal ? 'Supervisor Console' : 'Live Dashboard'})`} <ArrowRight size={16} />
          </button>
        </form>

        {/* Supervisor Direct Access for Dev/Test */}
        {isSupervisorPortal && (
          <>
            <div
              style={{
                margin: '1.5rem 0 1rem 0',
                textAlign: 'center',
                position: 'relative'
              }}
            >
              <hr style={{ borderColor: 'var(--border-subtle)', borderTop: '1px solid var(--border-subtle)', borderBottom: 'none' }} />
              <span
                style={{
                  position: 'absolute',
                  top: '50%',
                  left: '50%',
                  transform: 'translate(-50%, -50%)',
                  background: 'var(--surface-card)',
                  padding: '0 0.6rem',
                  color: 'var(--text-muted)',
                  fontSize: '0.72rem',
                  fontFamily: 'var(--font-mono)'
                }}
              >
                SUPERVISOR DEV QUICK ACCESS
              </span>
            </div>

            <button
              type="button"
              className="btn btn-secondary"
              onClick={handleQuickSupervisorLogin}
              style={{ width: '100%', padding: '0.65rem', fontSize: '0.85rem', borderColor: 'var(--primary-orange)', color: '#FF7043' }}
            >
              <Wrench size={16} color="var(--primary-orange)" /> Authenticate as Site Supervisor (Dev Tools)
            </button>
          </>
        )}

        <p style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.75rem', marginTop: '1.25rem' }}>
          Strict Live Mode enforced for standard accounts • Dev Tools reserved for Supervisors
        </p>
      </div>
    </div>
  );
}

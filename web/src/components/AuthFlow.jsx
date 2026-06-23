import React, { useState, useEffect } from 'react';
import { 
  Building2, User, KeyRound, Eye, EyeOff, ArrowLeft, 
  Check, X, ShieldAlert, Lock, Info, RefreshCw, LogOut, Laptop, Smartphone, Globe
} from 'lucide-react';

// Live strength calculator helper
const calculatePasswordStrength = (password) => {
  let score = 0;
  if (!password) return score;
  if (password.length >= 8) score += 1;
  if (/[A-Z]/.test(password)) score += 1;
  if (/[a-z]/.test(password)) score += 1;
  if (/[0-9]/.test(password)) score += 1;
  if (/[^A-Za-z0-9]/.test(password)) score += 1;
  return Math.min(score, 4); // Max 4 points
};

export default function AuthFlow({ onLoginSuccess, apiFetch, API_BASE }) {
  // Screen state: 'role-select' | 'owner-login' | 'tenant-login' | 'first-login'
  const [screen, setScreen] = useState('role-select');
  const [loginRole, setLoginRole] = useState(() => localStorage.getItem('last_selected_role') || 'owner');
  
  // Input fields
  const [loginInput, setLoginInput] = useState(''); // Email/Phone for owner
  const [tenantLoginId, setTenantLoginId] = useState(''); // TENANT-XXX for tenant
  const [password, setPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(true);
  const [showPassword, setShowPassword] = useState(false);
  
  // First login change password fields
  const [firstLoginData, setFirstLoginData] = useState({
    oldPassword: '',
    newPassword: '',
    confirmPassword: ''
  });
  const [showOldPassword, setShowOldPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  
  // UI states
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [showForgotModal, setShowForgotModal] = useState(false);
  const [tempUserPayload, setTempUserPayload] = useState(null); // Saved after login before password change

  // Automatically direct user to login screen if role is saved
  useEffect(() => {
    const saved = localStorage.getItem('last_selected_role');
    if (saved) {
      setLoginRole(saved);
    }
  }, []);

  const selectRole = (role) => {
    setLoginRole(role);
    localStorage.setItem('last_selected_role', role);
    setScreen(role === 'owner' ? 'owner-login' : 'tenant-login');
    setErrorMsg('');
    setPassword('');
  };

  const handleBack = () => {
    setScreen('role-select');
    setErrorMsg('');
    setPassword('');
    setLoginInput('');
    setTenantLoginId('');
  };

  // Perform Owner Login
  const handleOwnerLogin = async (e) => {
    e.preventDefault();
    if (!loginInput || !password) {
      setErrorMsg('Please enter your email/phone and password.');
      return;
    }
    setErrorMsg('');
    setLoading(true);

    try {
      const payload = {
        role: 'owner',
        password,
        rememberMe
      };
      if (loginInput.includes('@')) {
        payload.email = loginInput.trim();
      } else {
        payload.phone = loginInput.trim();
      }

      const res = await apiFetch(`${API_BASE}/auth/login`, {
        method: 'POST',
        body: payload
      });
      const data = await res.json();

      if (data.isFirstLogin) {
        setTempUserPayload(data);
        setScreen('first-login');
        setFirstLoginData({ oldPassword: password, newPassword: '', confirmPassword: '' });
      } else {
        onLoginSuccess(data.user, 'owner');
      }
    } catch (err) {
      setErrorMsg(err.message || 'Login failed. Please verify credentials.');
    } finally {
      setLoading(false);
    }
  };

  // Perform Tenant Login
  const handleTenantLogin = async (e) => {
    e.preventDefault();
    if (!tenantLoginId || !password) {
      setErrorMsg('Please enter your Tenant ID and password.');
      return;
    }
    setErrorMsg('');
    setLoading(true);

    try {
      const res = await apiFetch(`${API_BASE}/auth/tenant-login`, {
        method: 'POST',
        body: {
          tenantLoginId: tenantLoginId.trim(),
          password,
          rememberMe
        }
      });
      const data = await res.json();

      if (data.isFirstLogin) {
        setTempUserPayload(data);
        setScreen('first-login');
        setFirstLoginData({ oldPassword: password, newPassword: '', confirmPassword: '' });
      } else {
        onLoginSuccess(data.user, 'tenant');
      }
    } catch (err) {
      setErrorMsg(err.message || 'Login failed. Please verify credentials.');
    } finally {
      setLoading(false);
    }
  };

  // Perform Password Change (First login)
  const handleFirstLoginPasswordChange = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');

    const { oldPassword, newPassword, confirmPassword } = firstLoginData;

    if (!newPassword || newPassword.length < 8) {
      setErrorMsg('Password must be at least 8 characters long.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setErrorMsg('Passwords do not match.');
      return;
    }
    if (newPassword === oldPassword) {
      setErrorMsg('New password cannot be the same as your temporary password.');
      return;
    }

    // Double check constraints
    const hasUpper = /[A-Z]/.test(newPassword);
    const hasLower = /[a-z]/.test(newPassword);
    const hasNum = /[0-9]/.test(newPassword);
    const hasSpecial = /[^A-Za-z0-9]/.test(newPassword);
    if (!hasUpper || !hasLower || !hasNum || !hasSpecial) {
      setErrorMsg('Password does not meet all criteria.');
      return;
    }

    setLoading(true);
    try {
      const res = await apiFetch(`${API_BASE}/auth/change-password-first`, {
        method: 'POST',
        body: { oldPassword, newPassword }
      });
      await res.json();
      
      setSuccessMsg('Password updated successfully! Redirecting...');
      setTimeout(() => {
        if (tempUserPayload) {
          onLoginSuccess(tempUserPayload.user, tempUserPayload.user.role);
        }
      }, 1500);
    } catch (err) {
      setErrorMsg(err.message || 'Failed to update password.');
    } finally {
      setLoading(false);
    }
  };

  // Password rules validation
  const newPwd = firstLoginData.newPassword;
  const isLenValid = newPwd.length >= 8;
  const isUpperValid = /[A-Z]/.test(newPwd);
  const isLowerValid = /[a-z]/.test(newPwd);
  const isNumValid = /[0-9]/.test(newPwd);
  const isSpecialValid = /[^A-Za-z0-9]/.test(newPwd);
  const isMatchValid = newPwd && newPwd === firstLoginData.confirmPassword;
  const isNotSameValid = newPwd && newPwd !== firstLoginData.oldPassword;
  
  const strengthScore = calculatePasswordStrength(newPwd);

  return (
    <div className="auth-split">
      {/* Visual Brand Panel (Left Side on large screens) */}
      <div className="auth-brand-panel">
        <div className="auth-brand-content">
          <div className="brand-logo-container">
            <span className="brand-logo-icon">⚡</span>
            <span className="brand-logo-text">RentFlow</span>
          </div>
          <h2>Smart Property & Rent Management.</h2>
          <p>A complete platform designed for modern landlords and tenants. Manage leases, properties, bills, check-ins, and communication seamlessly.</p>
          <div className="brand-features">
            <div className="b-feature"><span className="bf-icon">✓</span> Beautiful Material 3 Interface</div>
            <div className="b-feature"><span className="bf-icon">✓</span> Advanced Session Monitoring</div>
            <div className="b-feature"><span className="bf-icon">✓</span> Encrypted Personal Vault</div>
            <div className="b-feature"><span className="bf-icon">✓</span> Double-channel Alerts & Chats</div>
          </div>
        </div>
        <div className="brand-footer-text">
          RentFlow Security Core v1.4.0 • Encrypted AES-256
        </div>
      </div>

      {/* Auth Interaction Panel (Right Side) */}
      <div className="auth-interaction-panel">
        {screen === 'role-select' && (
          <div className="auth-card role-select-screen animated fadeUp">
            <div className="auth-header">
              <h1>Welcome to RentFlow</h1>
              <p>Please select your login role to proceed</p>
            </div>
            
            <div className="role-cards-container">
              <button className="role-hero-card" onClick={() => selectRole('owner')}>
                <div className="rh-icon-box owner-gradient">
                  <Building2 size={32} />
                </div>
                <div className="rh-info">
                  <h3>Owner / Admin Portal</h3>
                  <p>Manage multiple properties, view financial charts, check-in tenants, generate monthly utility bills, and monitor active sessions.</p>
                </div>
                <span className="rh-arrow">→</span>
              </button>

              <button className="role-hero-card" onClick={() => selectRole('tenant')}>
                <div className="rh-icon-box tenant-gradient">
                  <User size={32} />
                </div>
                <div className="rh-info">
                  <h3>Tenant Dashboard</h3>
                  <p>View rent details, download billing invoices, submit maintenance requests, and chat directly with your landlord.</p>
                </div>
                <span className="rh-arrow">→</span>
              </button>
            </div>

            <div className="auth-footer-help">
              Trouble logging in? Contact RentFlow Support
            </div>
          </div>
        )}

        {screen === 'owner-login' && (
          <div className="auth-card login-screen animated fadeUp">
            <button className="back-btn" onClick={handleBack}>
              <ArrowLeft size={16} /> Back to roles
            </button>
            <div className="auth-header">
              <h2>Landlord Portal Login</h2>
              <p>Enter your email or phone number to manage your dashboard</p>
            </div>

            {errorMsg && (
              <div className="auth-error-alert">
                <ShieldAlert size={18} />
                <span>{errorMsg}</span>
              </div>
            )}

            <form onSubmit={handleOwnerLogin} className="auth-form">
              <div className="form-group">
                <label>Email Address or Phone Number</label>
                <div className="input-with-icon">
                  <span className="field-icon">✉</span>
                  <input
                    type="text"
                    placeholder="name@domain.com or phone number"
                    value={loginInput}
                    onChange={(e) => setLoginInput(e.target.value)}
                    required
                    disabled={loading}
                    autoFocus
                  />
                </div>
              </div>

              <div className="form-group">
                <div className="form-label-row">
                  <label>Account Password</label>
                  <button 
                    type="button" 
                    className="forgot-link" 
                    onClick={() => setShowForgotModal(true)}
                  >
                    Forgot Password?
                  </button>
                </div>
                <div className="input-with-icon">
                  <span className="field-icon">🔒</span>
                  <input
                    type={showPassword ? "text" : "password"}
                    placeholder="Enter your security password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    disabled={loading}
                  />
                  <button
                    type="button"
                    className="eye-toggle-btn"
                    onClick={() => setShowPassword(!showPassword)}
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              <div className="form-options">
                <label className="checkbox-container">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                    disabled={loading}
                  />
                  <span className="checkmark"></span>
                  Remember this device for 30 days
                </label>
              </div>

              <button type="submit" className="auth-action-btn owner-btn" disabled={loading}>
                {loading ? <span className="spinner"></span> : 'Secure Sign In'}
              </button>
            </form>
          </div>
        )}

        {screen === 'tenant-login' && (
          <div className="auth-card login-screen animated fadeUp">
            <button className="back-btn" onClick={handleBack}>
              <ArrowLeft size={16} /> Back to roles
            </button>
            <div className="auth-header">
              <h2>Tenant Portal Login</h2>
              <p>Log in with the User ID issued by your landlord</p>
            </div>

            {errorMsg && (
              <div className="auth-error-alert">
                <ShieldAlert size={18} />
                <span>{errorMsg}</span>
              </div>
            )}

            <form onSubmit={handleTenantLogin} className="auth-form">
              <div className="form-group">
                <label>Tenant User ID</label>
                <div className="input-with-icon">
                  <span className="field-icon">👤</span>
                  <input
                    type="text"
                    placeholder="e.g. TENANT-101"
                    value={tenantLoginId}
                    onChange={(e) => setTenantLoginId(e.target.value)}
                    required
                    disabled={loading}
                    autoFocus
                  />
                </div>
                <p className="field-hint">
                  <Info size={12} style={{ marginRight: '4px' }} />
                  Your User ID can be found in your check-in files or rental contract.
                </p>
              </div>

              <div className="form-group">
                <div className="form-label-row">
                  <label>Access Password</label>
                  <button 
                    type="button" 
                    className="forgot-link" 
                    onClick={() => setShowForgotModal(true)}
                  >
                    Forgot Password?
                  </button>
                </div>
                <div className="input-with-icon">
                  <span className="field-icon">🔒</span>
                  <input
                    type={showPassword ? "text" : "password"}
                    placeholder="Enter password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    disabled={loading}
                  />
                  <button
                    type="button"
                    className="eye-toggle-btn"
                    onClick={() => setShowPassword(!showPassword)}
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              <div className="form-options">
                <label className="checkbox-container">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                    disabled={loading}
                  />
                  <span className="checkmark"></span>
                  Remember login credentials
                </label>
              </div>

              <button type="submit" className="auth-action-btn tenant-btn" disabled={loading}>
                {loading ? <span className="spinner"></span> : 'Authenticate Dashboard'}
              </button>
            </form>
          </div>
        )}

        {screen === 'first-login' && (
          <div className="auth-card first-login-screen animated fadeUp">
            <div className="auth-header">
              <h2>Setup Security Password</h2>
              <p>For your account safety, you are required to change your temporary password before proceeding.</p>
            </div>

            {errorMsg && (
              <div className="auth-error-alert">
                <ShieldAlert size={18} />
                <span>{errorMsg}</span>
              </div>
            )}
            {successMsg && (
              <div className="auth-success-alert">
                <Check size={18} />
                <span>{successMsg}</span>
              </div>
            )}

            <form onSubmit={handleFirstLoginPasswordChange} className="auth-form">
              <div className="form-group">
                <label>Temporary Password</label>
                <div className="input-with-icon">
                  <span className="field-icon">🔑</span>
                  <input
                    type={showOldPassword ? "text" : "password"}
                    placeholder="Verify original temporary password"
                    value={firstLoginData.oldPassword}
                    onChange={(e) => setFirstLoginData({ ...firstLoginData, oldPassword: e.target.value })}
                    required
                    disabled={loading}
                  />
                  <button
                    type="button"
                    className="eye-toggle-btn"
                    onClick={() => setShowOldPassword(!showOldPassword)}
                  >
                    {showOldPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              <div className="form-group">
                <label>New Security Password</label>
                <div className="input-with-icon">
                  <span className="field-icon">🔒</span>
                  <input
                    type={showNewPassword ? "text" : "password"}
                    placeholder="Choose a strong password"
                    value={firstLoginData.newPassword}
                    onChange={(e) => setFirstLoginData({ ...firstLoginData, newPassword: e.target.value })}
                    required
                    disabled={loading}
                  />
                  <button
                    type="button"
                    className="eye-toggle-btn"
                    onClick={() => setShowNewPassword(!showNewPassword)}
                  >
                    {showNewPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>

                {/* Password Strength Indicator */}
                <div className="strength-meter-container">
                  <div className="strength-bar-segments">
                    <span className={`segment ${strengthScore >= 1 ? `score-${strengthScore}` : ''}`}></span>
                    <span className={`segment ${strengthScore >= 2 ? `score-${strengthScore}` : ''}`}></span>
                    <span className={`segment ${strengthScore >= 3 ? `score-${strengthScore}` : ''}`}></span>
                    <span className={`segment ${strengthScore >= 4 ? `score-${strengthScore}` : ''}`}></span>
                  </div>
                  <span className="strength-label">
                    {strengthScore === 0 && 'Very Weak'}
                    {strengthScore === 1 && 'Weak'}
                    {strengthScore === 2 && 'Fair'}
                    {strengthScore === 3 && 'Strong'}
                    {strengthScore === 4 && 'Excellent'}
                  </span>
                </div>
              </div>

              <div className="form-group">
                <label>Confirm New Password</label>
                <div className="input-with-icon">
                  <span className="field-icon">✓</span>
                  <input
                    type={showConfirmPassword ? "text" : "password"}
                    placeholder="Re-enter password"
                    value={firstLoginData.confirmPassword}
                    onChange={(e) => setFirstLoginData({ ...firstLoginData, confirmPassword: e.target.value })}
                    required
                    disabled={loading}
                  />
                  <button
                    type="button"
                    className="eye-toggle-btn"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                  >
                    {showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              {/* Requirement Checklist */}
              <div className="password-requirements">
                <h4>Security Guidelines:</h4>
                <ul>
                  <li className={isLenValid ? 'valid' : 'invalid'}>
                    {isLenValid ? <Check size={14} className="req-icon" /> : <X size={14} className="req-icon" />}
                    At least 8 characters
                  </li>
                  <li className={isUpperValid ? 'valid' : 'invalid'}>
                    {isUpperValid ? <Check size={14} className="req-icon" /> : <X size={14} className="req-icon" />}
                    Uppercase letter (A-Z)
                  </li>
                  <li className={isLowerValid ? 'valid' : 'invalid'}>
                    {isLowerValid ? <Check size={14} className="req-icon" /> : <X size={14} className="req-icon" />}
                    Lowercase letter (a-z)
                  </li>
                  <li className={isNumValid ? 'valid' : 'invalid'}>
                    {isNumValid ? <Check size={14} className="req-icon" /> : <X size={14} className="req-icon" />}
                    Number (0-9)
                  </li>
                  <li className={isSpecialValid ? 'valid' : 'invalid'}>
                    {isSpecialValid ? <Check size={14} className="req-icon" /> : <X size={14} className="req-icon" />}
                    Special symbol (@, #, $, %, etc.)
                  </li>
                  <li className={isMatchValid ? 'valid' : 'invalid'}>
                    {isMatchValid ? <Check size={14} className="req-icon" /> : <X size={14} className="req-icon" />}
                    Passwords match
                  </li>
                  <li className={isNotSameValid ? 'valid' : 'invalid'}>
                    {isNotSameValid ? <Check size={14} className="req-icon" /> : <X size={14} className="req-icon" />}
                    Not same as temporary password
                  </li>
                </ul>
              </div>

              <button 
                type="submit" 
                className="auth-action-btn setup-pwd-btn" 
                disabled={loading || strengthScore < 4 || !isMatchValid || !isNotSameValid}
              >
                {loading ? <span className="spinner"></span> : 'Activate Account & Enter'}
              </button>
            </form>
          </div>
        )}
      </div>

      {/* Forgot Password Information Modal */}
      {showForgotModal && (
        <div className="auth-modal-overlay">
          <div className="auth-modal animated scaleIn">
            <div className="modal-icon-box">
              <Lock size={28} />
            </div>
            <h3>Password Reset Request</h3>
            
            {loginRole === 'owner' ? (
              <p className="modal-description">
                For security reasons, landlord passwords can only be reset by the server system administrator. Please coordinate with the IT administrator to re-enable or generate a temporary password.
              </p>
            ) : (
              <p className="modal-description">
                Your login credentials and account access are controlled by your landlord. Please contact your property owner directly, and they can generate a new temporary password from their <strong>Tenant Portal Details</strong>.
              </p>
            )}

            <button 
              type="button" 
              className="modal-dismiss-btn"
              onClick={() => setShowForgotModal(false)}
            >
              Understand & Dismiss
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// Global active sessions panel for layout implementation
export function ActiveSessions({ apiFetch, API_BASE, triggerToast, currentUserId }) {
  const [sessionsList, setSessionsList] = useState([]);
  const [loading, setLoading] = useState(false);

  const loadSessions = async () => {
    setLoading(true);
    try {
      const res = await apiFetch(`${API_BASE}/auth/sessions`);
      const data = await res.json();
      setSessionsList(data);
    } catch (e) {
      console.error(e);
      triggerToast('⚠️ Failed to load active sessions.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSessions();
  }, []);

  const handleRevoke = async (sessionId) => {
    if (!confirm('Are you sure you want to log out this device?')) return;
    try {
      const res = await apiFetch(`${API_BASE}/auth/sessions/${sessionId}`, {
        method: 'DELETE'
      });
      await res.json();
      triggerToast('🔒 Session revoked successfully.');
      loadSessions();
    } catch (e) {
      triggerToast(e.message || '⚠️ Revoking session failed.');
    }
  };

  const handleRevokeAll = async () => {
    if (!confirm('Log out from all other devices? This will close all active sessions.')) return;
    try {
      const res = await apiFetch(`${API_BASE}/auth/logout-all`, {
        method: 'POST'
      });
      await res.json();
      triggerToast('🔒 Logged out from all devices.');
      // Reload page or force logout local
      window.location.reload();
    } catch (e) {
      triggerToast('⚠️ Failed to clear all sessions.');
    }
  };

  const getDeviceIcon = (os = '') => {
    const term = os.toLowerCase();
    if (term.includes('ios') || term.includes('android')) return <Smartphone size={20} />;
    if (term.includes('windows') || term.includes('mac') || term.includes('linux')) return <Laptop size={20} />;
    return <Globe size={20} />;
  };

  return (
    <div className="sessions-settings-view">
      <div className="section-header-row">
        <div>
          <h2 className="section-title">Device Sessions</h2>
          <p className="section-subtitle">Track and manage active devices logged into your RentFlow account.</p>
        </div>
        <button 
          className="revoke-all-btn"
          onClick={handleRevokeAll}
          disabled={loading || sessionsList.length <= 1}
        >
          <LogOut size={16} /> Log Out All Other Devices
        </button>
      </div>

      {loading ? (
        <div className="sessions-loader">
          <RefreshCw size={24} className="spin-icon" />
          <span>Refreshing session registry...</span>
        </div>
      ) : sessionsList.length === 0 ? (
        <div className="sessions-empty-state">
          <Info size={32} />
          <p>No active sessions registered.</p>
        </div>
      ) : (
        <div className="sessions-grid">
          {sessionsList.map((session) => {
            const isCurrent = session.tokenHash === null; // Local marker or compare
            return (
              <div key={session.id} className={`session-device-card ${isCurrent ? 'current-device' : ''}`}>
                <div className="s-card-left">
                  <div className="device-icon-wrapper">
                    {getDeviceIcon(session.os)}
                  </div>
                  <div className="device-details">
                    <div className="device-meta-row">
                      <h4>{session.deviceName}</h4>
                      {isCurrent && <span className="current-badge">Current Device</span>}
                    </div>
                    <p className="device-tech">{session.browser} • {session.os}</p>
                    <div className="device-ip-location">
                      <span className="d-ip">{session.ipAddress}</span>
                      <span className="d-divider">•</span>
                      <span className="d-loc">{session.location || 'Unknown Location'}</span>
                    </div>
                    <p className="device-time">Active: {new Date(session.lastActive).toLocaleString()}</p>
                  </div>
                </div>
                
                <div className="s-card-right">
                  {!isCurrent && (
                    <button 
                      className="revoke-session-btn"
                      onClick={() => handleRevoke(session.id)}
                      title="Log out device"
                    >
                      Disconnect
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

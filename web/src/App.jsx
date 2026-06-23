import React, { useState, useEffect } from 'react';
import { 
  LayoutDashboard, Building2, Users, Receipt, CreditCard, 
  MessageSquare, FileText, BarChart3, Settings, Bell, Sun, Moon, 
  Search, Plus, Trash2, UserMinus, Archive, Send, Paperclip, 
  ChevronRight, User, Check, RefreshCw, X, Smartphone, 
  AlertTriangle, HelpCircle, ArrowUpRight, ArrowDownRight, Sparkles, Download, MessageCircle
} from 'lucide-react';
import Logo from './components/Logo';
import AuthFlow, { ActiveSessions } from './components/AuthFlow';
import { ShieldCheck } from 'lucide-react';

// API Central URL
const API_BASE = 'http://localhost:5000/api';

export default function App() {
  // Theme state
  const [theme, setTheme] = useState(localStorage.getItem('theme') || 'light');
  
  // App views state
  const [activeView, setActiveView] = useState('dashboard');
  const [role, setRole] = useState('owner'); // 'owner' or 'tenant' (influences mobile sim and login)
  const [isLogged, setIsLogged] = useState(false);
  const [loginRole, setLoginRole] = useState('owner');
  const [loginInput, setLoginInput] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  
  // Data State
  const [properties, setProperties] = useState([]);
  const [tenants, setTenants] = useState([]);
  const [bills, setBills] = useState([]);
  const [comments, setComments] = useState([]);
  const [chats, setChats] = useState([]);
  const [notifications, setNotifications] = useState([]);
  
  // Unread badge calculations
  const [unreadNotificationsCount, setUnreadNotificationsCount] = useState(0);
  const [showNotificationsDrawer, setShowNotificationsDrawer] = useState(false);
  
  // Modal states
  const [showAddTenant, setShowAddTenant] = useState(false);
  const [showAddProperty, setShowAddProperty] = useState(false);
  const [showRecordPayment, setShowRecordPayment] = useState(false);
  const [showMoveOutModal, setShowMoveOutModal] = useState(false);
  const [showEditBillModal, setShowEditBillModal] = useState(false);
  const [selectedTenant, setSelectedTenant] = useState(null);
  const [selectedBill, setSelectedBill] = useState(null);

  // Detail panel tab
  const [detailTab, setDetailTab] = useState('info');

  // Search/Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [propertyFilter, setPropertyFilter] = useState('All');
  
  // Simulator View State
  const [showSimulator, setShowSimulator] = useState(false);
  const [simActiveTab, setSimActiveTab] = useState('home');
  const [simPhone, setSimPhone] = useState('9876543210'); // Default Ravi's phone
  const [simIsLogged, setSimIsLogged] = useState(false);
  const [simTenantData, setSimTenantData] = useState(null);
  const [simLatestBill, setSimLatestBill] = useState(null);
  const [simComments, setSimComments] = useState([]);
  const [simChatMessages, setSimChatMessages] = useState([]);
  const [simNewCommentTitle, setSimNewCommentTitle] = useState('');
  const [simNewCommentBody, setSimNewCommentBody] = useState('');
  const [simCommentCategory, setSimCommentCategory] = useState('Maintenance');
  const [simChatText, setSimChatText] = useState('');
  
  // Loading status
  const [loading, setLoading] = useState(true);
  
  // Notification Toast Message
  const [toast, setToast] = useState(null);

  // Form Fields - New Tenant
  const [newTenantForm, setNewTenantForm] = useState({
    name: '', fatherName: '', phone: '', altPhone: '', email: '', occupation: '',
    aadhaar: '', pan: '', permanentAddress: '', currentAddress: '',
    propertyId: '', roomNumber: '', roomType: 'Room', moveInDate: new Date().toISOString().split('T')[0],
    agreementDuration: '12', rentAmount: '', securityDeposit: '', electricityRate: '6', waterCharges: '150',
    tenantLoginId: 'TENANT-' + Math.floor(100 + Math.random() * 900),
    tempPassword: 'Temp@' + Math.floor(100000 + Math.random() * 900000),
    loginEnabled: true,
    editCredentials: false
  });
  const [tenantWizardStep, setTenantWizardStep] = useState(1);
  
  // Form Fields - New Property
  const [newPropertyForm, setNewPropertyForm] = useState({ name: '', type: 'Residential', totalRooms: '10' });
  
  // Form Fields - Record Payment
  const [paymentForm, setPaymentForm] = useState({ billId: '', amount: '', method: 'UPI', note: '' });

  // Form Fields - Settle/Move-out
  const [moveOutForm, setMoveOutForm] = useState({ clearDues: true, refundAmount: '', refundDeductionReason: '', settleDeposit: true });
  
  // Form Fields - Edit Bill
  const [editBillForm, setEditBillForm] = useState({
    rentAmount: '', electricityUnits: '', electricityRate: '6', waterCharges: '150', lateFee: '0', discount: '0', extraCharges: '0', extraChargesReason: ''
  });

  // Chat/Comment messages
  const [activeChatTenantId, setActiveChatTenantId] = useState(null);
  const [ownerChatText, setOwnerChatText] = useState('');
  const [activeCommentId, setActiveCommentId] = useState(null);
  const [ownerCommentText, setOwnerCommentText] = useState('');

  // Apply Theme
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);

  // Fetch initial data — only after authenticated
  useEffect(() => {
    if (!isLogged) return;
    fetchAllData();
    const interval = setInterval(fetchUpdatesOnly, 5000); // Poll updates
    return () => clearInterval(interval);
  }, [isLogged]);

  // Update simulator tenant data when tenants update or sim log state changes
  useEffect(() => {
    if (simIsLogged && tenants.length > 0) {
      const activeT = tenants.find(t => t.phone === simPhone);
      setSimTenantData(activeT || null);
    } else {
      setSimTenantData(null);
    }
  }, [tenants, simPhone, simIsLogged]);

  // Update simulator bills & comments
  useEffect(() => {
    if (simTenantData) {
      const tBills = bills.filter(b => b.tenantId === simTenantData.id);
      setSimLatestBill(tBills.length > 0 ? tBills[tBills.length - 1] : null);
      
      const tComments = comments.filter(c => c.tenantId === simTenantData.id);
      setSimComments(tComments);
      
      const tChat = chats.find(c => c.tenantId === simTenantData.id);
      setSimChatMessages(tChat ? tChat.messages : []);
    } else {
      setSimLatestBill(null);
      setSimComments([]);
      setSimChatMessages([]);
    }
  }, [bills, comments, chats, simTenantData]);

  // Helper Toast
  const triggerToast = (msg) => {
    setToast(msg);
    setTimeout(() => setToast(null), 4000);
  };

  
  // Secure fetch helper incorporating SameSite cookies & auto-stringify
  const apiFetch = async (endpoint, options = {}) => {
    const mergedOptions = {
      ...options,
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        ...(options.headers || {})
      }
    };
    if (options.body && typeof options.body === 'object' && !(options.body instanceof FormData)) {
      mergedOptions.body = JSON.stringify(options.body);
    }
    const response = await fetch(endpoint, mergedOptions);
    if (!response.ok) {
      if (response.status === 401 || response.status === 403) {
        setIsLogged(false);
      }
      const errRes = await response.json().catch(() => ({}));
      throw new Error(errRes.message || `API error: ${response.statusText}`);
    }
    return response;
  };

  const fetchAllData = async () => {
    try {
      setLoading(true);
      const [resProp, resTenant, resBill, resComment, resChat, resNotif] = await Promise.all([
        apiFetch(`${API_BASE}/properties`).then(r => r.json()),
        apiFetch(`${API_BASE}/tenants`).then(r => r.json()),
        apiFetch(`${API_BASE}/bills`).then(r => r.json()),
        apiFetch(`${API_BASE}/comments`).then(r => r.json()),
        apiFetch(`${API_BASE}/chats`).then(r => r.json()),
        apiFetch(`${API_BASE}/notifications`).then(r => r.json())
      ]);

      setProperties(resProp);
      setTenants(resTenant);
      setBills(resBill);
      setComments(resComment);
      setChats(resChat);
      setNotifications(resNotif);

      const unreadCount = resNotif.filter(n => !n.read && n.forRole === 'owner').length;
      setUnreadNotificationsCount(unreadCount);
    } catch (error) {
      console.error("Error fetching Rentify state:", error);
    } finally {
      setLoading(false);
    }
  };

  const fetchUpdatesOnly = async () => {
    try {
      const [resTenant, resBill, resComment, resChat, resNotif] = await Promise.all([
        apiFetch(`${API_BASE}/tenants`).then(r => r.json()),
        apiFetch(`${API_BASE}/bills`).then(r => r.json()),
        apiFetch(`${API_BASE}/comments`).then(r => r.json()),
        apiFetch(`${API_BASE}/chats`).then(r => r.json()),
        apiFetch(`${API_BASE}/notifications`).then(r => r.json())
      ]);

      // Check if new unread notification for owner to sound toast
      const oldUnread = notifications.filter(n => !n.read && n.forRole === 'owner');
      const newUnread = resNotif.filter(n => !n.read && n.forRole === 'owner');
      if (newUnread.length > oldUnread.length) {
        const latest = newUnread[newUnread.length - 1];
        triggerToast(`🔔 ${latest.title}: ${latest.message}`);
      }

      setTenants(resTenant);
      setBills(resBill);
      setComments(resComment);
      setChats(resChat);
      setNotifications(resNotif);
      setUnreadNotificationsCount(newUnread.length);
    } catch (e) {
      console.log("Background poll error: ", e);
    }
  };

  // Create Property
  const handleCreateProperty = async (e) => {
    e.preventDefault();
    if (!newPropertyForm.name) return;
    try {
      const response = await apiFetch(`${API_BASE}/properties`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newPropertyForm)
      });
      const data = await response.json();
      setProperties([...properties, data]);
      setShowAddProperty(false);
      setNewPropertyForm({ name: '', type: 'Residential', totalRooms: '10' });
      triggerToast(`🏢 Created property: ${data.name}`);
    } catch (error) {
      alert("Failed to add property");
    }
  };

  // Create Tenant
  const handleCreateTenant = async () => {
    try {
      const response = await apiFetch(`${API_BASE}/tenants`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: newTenantForm
      });
      const data = await response.json();

      // Configure tenant credentials & login toggle
      try {
        await apiFetch(`${API_BASE}/tenants/${data.id}/credentials`, {
          method: 'PATCH',
          body: {
            tenantLoginId: newTenantForm.tenantLoginId,
            tempPassword: newTenantForm.tempPassword
          }
        });

        await apiFetch(`${API_BASE}/tenants/${data.id}/toggle-login`, {
          method: 'PATCH',
          body: {
            enabled: newTenantForm.loginEnabled
          }
        });
      } catch (credErr) {
        console.error("Failed to setup credentials for created tenant:", credErr);
      }

      setTenants([...tenants, data]);
      setShowAddTenant(false);
      setTenantWizardStep(1);
      // Reset form
      setNewTenantForm({
        name: '', fatherName: '', phone: '', altPhone: '', email: '', occupation: '',
        aadhaar: '', pan: '', permanentAddress: '', currentAddress: '',
        propertyId: '', roomNumber: '', roomType: 'Room', moveInDate: new Date().toISOString().split('T')[0],
        agreementDuration: '12', rentAmount: '', securityDeposit: '', electricityRate: '6', waterCharges: '150',
        tenantLoginId: 'TENANT-' + Math.floor(100 + Math.random() * 900),
        tempPassword: 'Temp@' + Math.floor(100000 + Math.random() * 900000),
        loginEnabled: true,
        editCredentials: false
      });
      triggerToast(`👤 Checked-in new tenant: ${data.name}`);
      fetchAllData();
    } catch (error) {
      alert("Failed to create tenant: " + error.message);
    }
  };

  // Generate monthly bills
  const handleGenerateMonthlyBills = async () => {
    const month = prompt("Enter billing month and year (e.g. July 2026):", "July 2026");
    if (!month) return;
    try {
      const response = await apiFetch(`${API_BASE}/bills/generate-monthly`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ month })
      });
      const data = await response.json();
      triggerToast(`🧾 Generated bills: ${data.count} bills created.`);
      fetchAllData();
    } catch (e) {
      alert("Error generating bills");
    }
  };

  // Edit Bill
  const openEditBillModal = (bill) => {
    setSelectedBill(bill);
    setEditBillForm({
      rentAmount: bill.rentAmount,
      electricityUnits: bill.electricityUnits,
      electricityRate: bill.electricityRate,
      waterCharges: bill.waterCharges,
      lateFee: bill.lateFee,
      discount: bill.discount,
      extraCharges: bill.extraCharges,
      extraChargesReason: bill.extraChargesReason || ''
    });
    setShowEditBillModal(true);
  };

  const handleUpdateBill = async (e) => {
    e.preventDefault();
    try {
      const response = await apiFetch(`${API_BASE}/bills/${selectedBill.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(editBillForm)
      });
      const updated = await response.json();
      setBills(bills.map(b => b.id === updated.id ? updated : b));
      setShowEditBillModal(false);
      triggerToast(`📝 Updated bill for ${updated.tenantName}`);
    } catch (e) {
      alert("Failed to edit bill parameters");
    }
  };

  // Log Payment
  const handleRecordPayment = async (e) => {
    e.preventDefault();
    if (!paymentForm.billId || !paymentForm.amount) return;
    try {
      const response = await apiFetch(`${API_BASE}/payments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(paymentForm)
      });
      const result = await response.json();
      if (response.ok) {
        setBills(bills.map(b => b.id === result.bill.id ? result.bill : b));
        setShowRecordPayment(false);
        setPaymentForm({ billId: '', amount: '', method: 'UPI', note: '' });
        triggerToast(`💰 Recorded payment of ₹${paymentForm.amount}`);
        fetchAllData();
      } else {
        alert(result.message || "Failed to record payment");
      }
    } catch (error) {
      alert("Payment API error");
    }
  };

  // Settle & Archive Tenant (Move Out)
  const handleMoveOutConfirm = async (e) => {
    e.preventDefault();
    try {
      const response = await apiFetch(`${API_BASE}/tenants/${selectedTenant.id}/move-out`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          clearDues: moveOutForm.clearDues,
          refundAmount: parseFloat(moveOutForm.refundAmount) || 0,
          refundDeductionReason: moveOutForm.refundDeductionReason,
          settleDeposit: moveOutForm.settleDeposit
        })
      });
      const result = await response.json();
      if (result.success) {
        setShowMoveOutModal(false);
        setSelectedTenant(null);
        triggerToast(`📦 Tenant ${result.tenant.name} archived.`);
        fetchAllData();
      }
    } catch (e) {
      alert("Failed to move out tenant");
    }
  };

  // Permanent Delete Archived Tenant
  const handlePermanentDeleteTenant = async (tenantId) => {
    if (!confirm("Are you sure you want to permanently delete this tenant? This will delete all comment threads, bills, and chat logs forever.")) return;
    try {
      const response = await apiFetch(`${API_BASE}/tenants/${tenantId}`, { method: 'DELETE' });
      if (response.ok) {
        triggerToast(`🗑️ Tenant deleted permanently`);
        setSelectedTenant(null);
        fetchAllData();
      }
    } catch (e) {
      alert("Error deleting record");
    }
  };

  // Owner Chat Send message
  const handleSendOwnerMessage = async (e) => {
    e.preventDefault();
    if (!ownerChatText.trim() || !activeChatTenantId) return;
    try {
      const response = await apiFetch(`${API_BASE}/chats/message`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tenantId: activeChatTenantId,
          sender: 'owner',
          text: ownerChatText
        })
      });
      const chatObj = await response.json();
      setChats(chats.map(c => c.tenantId === activeChatTenantId ? chatObj : c));
      setOwnerChatText('');
    } catch (e) {
      console.log(e);
    }
  };

  // Owner Comment reply send
  const handleSendOwnerCommentReply = async (e) => {
    e.preventDefault();
    if (!ownerCommentText.trim() || !activeCommentId) return;
    try {
      const response = await apiFetch(`${API_BASE}/comments/${activeCommentId}/reply`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender: 'owner',
          message: ownerCommentText
        })
      });
      const ticket = await response.json();
      setComments(comments.map(c => c.id === activeCommentId ? ticket : c));
      setOwnerCommentText('');
    } catch (e) {
      console.log(e);
    }
  };

  // Notifications logic
  const handleMarkAllNotificationsRead = async () => {
    try {
      await apiFetch(`${API_BASE}/notifications/mark-all-read`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: 'owner' })
      });
      setNotifications(notifications.map(n => n.forRole === 'owner' ? { ...n, read: true } : n));
      setUnreadNotificationsCount(0);
    } catch (e) {
      console.log(e);
    }
  };

  // SIMULATOR ACTIONS

  // Sim Login
  
  const handleLoginSuccess = (user, loggedRole) => {
    setRole(loggedRole);
    setIsLogged(true);
    triggerToast("🔑 Logged in successfully!");
    fetchAllData();
  };

  const handleWebLogout = async () => {
    try {
      await apiFetch(`${API_BASE}/auth/logout`, { method: 'POST' });
    } catch (e) {}
    setIsLogged(false);
    triggerToast("👋 Logged out securely.");
  };

  const handleSimLogin = async (e) => {
    e.preventDefault();
    try {
      const response = await apiFetch(`${API_BASE}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: { phone: simPhone, password: 'password', role: 'tenant' }
      });
      const result = await response.json();
      if (result.success) {
        setSimIsLogged(true);
        setSimActiveTab('home');
      } else {
        alert(result.message);
      }
    } catch (e) {
      alert("Simulator login error");
    }
  };

  // Sim Pay
  const handleSimPayBill = async () => {
    if (!simLatestBill) return;
    try {
      const response = await apiFetch(`${API_BASE}/payments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          billId: simLatestBill.id,
          amount: simLatestBill.pendingAmount,
          method: 'UPI',
          note: 'Paid via simulator app'
        })
      });
      if (response.ok) {
        alert(`Success: Paid ₹${simLatestBill.pendingAmount} via UPI!`);
        fetchAllData();
      }
    } catch (e) {
      alert("Sim payment error");
    }
  };

  // Sim Submit Comment Ticket
  const handleSimSubmitComment = async (e) => {
    e.preventDefault();
    if (!simNewCommentTitle || !simNewCommentBody) return;
    try {
      const response = await apiFetch(`${API_BASE}/comments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tenantId: simTenantData.id,
          title: simNewCommentTitle,
          category: simCommentCategory,
          message: simNewCommentBody
        })
      });
      if (response.ok) {
        setSimNewCommentTitle('');
        setSimNewCommentBody('');
        alert("Maintenance request sent to Owner!");
        fetchAllData();
      }
    } catch (e) {
      console.log(e);
    }
  };

  // Sim Reply to Comment Thread
  const handleSimCommentReply = async (commentId, replyText) => {
    if (!replyText.trim()) return;
    try {
      const response = await apiFetch(`${API_BASE}/comments/${commentId}/reply`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender: 'tenant',
          name: simTenantData.name,
          message: replyText
        })
      });
      if (response.ok) {
        fetchAllData();
      }
    } catch (e) {
      console.log(e);
    }
  };

  // Sim Send Chat
  const handleSimSendChat = async (e) => {
    e.preventDefault();
    if (!simChatText.trim()) return;
    try {
      const response = await apiFetch(`${API_BASE}/chats/message`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tenantId: simTenantData.id,
          sender: 'tenant',
          text: simChatText
        })
      });
      if (response.ok) {
        setSimChatText('');
        fetchAllData();
      }
    } catch (e) {
      console.log(e);
    }
  };

  // Helper metrics
  const totalProperties = properties.length;
  const totalTenants = tenants.filter(t => t.status === 'Active' || t.status === 'Leaving').length;
  
  // Calculations
  const monthlyCollection = bills
    .filter(b => b.billingMonth === 'June 2026')
    .reduce((sum, b) => sum + b.paidAmount, 0);

  const pendingAmount = bills.reduce((sum, b) => sum + b.pendingAmount, 0);
  
  const securityDepositHeld = tenants
    .filter(t => t.status !== 'Left')
    .reduce((sum, t) => sum + t.securityDeposit, 0);

  const totalRoomsCount = properties.reduce((sum, p) => sum + p.totalRooms, 0);
  const occupiedRoomsCount = properties.reduce((sum, p) => sum + p.occupied, 0);
  const occupancyRate = totalRoomsCount > 0 ? Math.round((occupiedRoomsCount / totalRoomsCount) * 100) : 0;

  // Filter lists based on search and property selections
  const filteredTenants = tenants.filter(t => {
    const matchSearch = t.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
                        t.roomNumber.toLowerCase().includes(searchQuery.toLowerCase()) ||
                        t.phone.includes(searchQuery);
    const matchProp = propertyFilter === 'All' || t.propertyName === propertyFilter;
    return matchSearch && matchProp;
  });

  return (
    <div>
      {/* Toast Alert */}
      {toast && (
        <div style={{
          position: 'fixed', bottom: '24px', left: '24px', background: 'var(--color-primary)', 
          color: 'white', padding: '16px 24px', borderRadius: '16px', zIndex: 1200, 
          boxShadow: 'var(--shadow-premium)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px',
          animation: 'slideUp var(--transition-fast)'
        }}>
          <Sparkles size={18} />
          {toast}
        </div>
      )}

      {/* DEV TOOLBAR BAR */}
      <div className="dev-toolbar">
        <div className="dev-logo">
          <Logo size={24} />
          <span style={{ fontSize: '1rem', color: '#FFF', fontWeight: 800 }}>Rentify Studio</span>
        </div>
        <div className="dev-controls">
          <div style={{ display: 'flex', gap: '8px', background: 'rgba(255,255,255,0.05)', padding: '4px', borderRadius: '10px' }}>
            <button 
              className={`dev-btn ${role === 'owner' ? 'active' : ''}`}
              onClick={() => { setRole('owner'); setIsLogged(true); }}
            >
              Owner View
            </button>
            <button 
              className={`dev-btn ${role === 'tenant' ? 'active' : ''}`}
              onClick={() => { setRole('tenant'); setSimPhone('9876543210'); setSimIsLogged(true); }}
            >
              Tenant View
            </button>
          </div>

          <button className="dev-btn" onClick={() => setShowSimulator(!showSimulator)}>
            <Smartphone size={16} />
            {showSimulator ? "Hide Simulator" : "Show Simulator"}
          </button>

          <button className="dev-btn" onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
            {theme === 'light' ? <Moon size={16} /> : <Sun size={16} />}
            {theme === 'light' ? "Dark Mode" : "Light Mode"}
          </button>
        </div>
      </div>

      {/* SECURE LOGIN PAGE */}
      {!isLogged ? (
        <AuthFlow onLoginSuccess={handleLoginSuccess} apiFetch={apiFetch} API_BASE={API_BASE} />
      ) : (
        /* RENDER ROLE VIEW */
        role === 'owner' ? (
        // OWNER PORTAL
        <div className="web-layout">
          {/* Sidebar */}
          <div className="sidebar">
            <div className="sidebar-header">
              <Logo size={42} />
              <div className="sidebar-logo">Rentify</div>
            </div>
            
            <div className="sidebar-nav">
              <div className={`nav-item ${activeView === 'dashboard' ? 'active' : ''}`} onClick={() => { setActiveView('dashboard'); setSelectedTenant(null); }}>
                <LayoutDashboard size={18} />
                Dashboard
              </div>
              <div className={`nav-item ${activeView === 'properties' ? 'active' : ''}`} onClick={() => { setActiveView('properties'); setSelectedTenant(null); }}>
                <Building2 size={18} />
                Properties
              </div>
              <div className={`nav-item ${activeView === 'tenants' ? 'active' : ''}`} onClick={() => { setActiveView('tenants'); setSelectedTenant(null); }}>
                <Users size={18} />
                Tenants
              </div>
              <div className={`nav-item ${activeView === 'bills' ? 'active' : ''}`} onClick={() => { setActiveView('bills'); setSelectedTenant(null); }}>
                <Receipt size={18} />
                Bills & Utilities
              </div>
              <div className={`nav-item ${activeView === 'payments' ? 'active' : ''}`} onClick={() => { setActiveView('payments'); setSelectedTenant(null); }}>
                <CreditCard size={18} />
                Payments Ledger
              </div>
              <div className={`nav-item ${activeView === 'chat' ? 'active' : ''}`} onClick={() => { setActiveView('chat'); setSelectedTenant(null); }}>
                <MessageSquare size={18} />
                Chats & Queries
              </div>
              <div className={`nav-item ${activeView === 'documents' ? 'active' : ''}`} onClick={() => { setActiveView('documents'); setSelectedTenant(null); }}>
                <FileText size={18} />
                Documents
              </div>
              <div className={`nav-item ${activeView === 'reports' ? 'active' : ''}`} onClick={() => { setActiveView('reports'); setSelectedTenant(null); }}>
                <BarChart3 size={18} />
                Reports
              </div>
              <div className={`nav-item ${activeView === 'settings' ? 'active' : ''}`} onClick={() => { setActiveView('settings'); setSelectedTenant(null); }}>
                <Settings size={18} />
                Settings
              </div>
              <div className={`nav-item ${activeView === 'sessions' ? 'active' : ''}`} onClick={() => { setActiveView('sessions'); setSelectedTenant(null); }}>
                <ShieldCheck size={18} />
                Device Sessions
              </div>
            </div>

            <div className="sidebar-footer">
              <img src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100" alt="Avatar" className="user-avatar" />
              <div className="user-info" style={{ cursor: 'pointer' }} onClick={handleWebLogout}>
                <span className="user-name">Sandeep Kumar</span>
                <span className="user-role">Landlord (Logout)</span>
              </div>
            </div>
          </div>

          {/* Main Main Workspace */}
          <div className="main-content">
            {/* Topbar */}
            <div className="topbar">
              <div className="search-bar">
                <Search size={16} />
                <input 
                  type="text" 
                  placeholder="Search properties, rooms, tenants..." 
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>

              <div className="topbar-actions">
                <div className="icon-btn" onClick={() => setShowNotificationsDrawer(!showNotificationsDrawer)}>
                  <Bell size={18} />
                  {unreadNotificationsCount > 0 && <span className="notification-badge">{unreadNotificationsCount}</span>}
                </div>
                <button className="btn-primary" style={{ padding: '8px 16px', borderRadius: '20px', fontSize: '0.85rem' }} onClick={() => setShowAddTenant(true)}>
                  <Plus size={16} />
                  Add Tenant
                </button>
              </div>

              {/* Notification Drawer Popup */}
              {showNotificationsDrawer && (
                <div className="notifications-dropdown">
                  <div className="dropdown-header">
                    <h4>Notifications</h4>
                    <button className="clear-btn" onClick={handleMarkAllNotificationsRead}>Mark read</button>
                  </div>
                  <div className="notifications-list">
                    {notifications.filter(n => n.forRole === 'owner').length === 0 ? (
                      <div className="empty-state">
                        <Bell size={24} />
                        <h4>All caught up!</h4>
                      </div>
                    ) : (
                      notifications
                        .filter(n => n.forRole === 'owner')
                        .slice(0, 10)
                        .map(n => (
                          <div key={n.id} className={`notification-item ${!n.read ? 'unread' : ''}`}>
                            <span className="notif-title">{n.title}</span>
                            <span className="notif-msg">{n.message}</span>
                            <span className="notif-time">{new Date(n.time).toLocaleTimeString()}</span>
                          </div>
                        ))
                    )}
                  </div>
                </div>
              )}
            </div>

            {/* Content Switcher */}
            <div className="content-body">
              {loading && (
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center', color: 'var(--text-secondary)', marginBottom: '16px' }}>
                  <RefreshCw size={14} className="skeleton" /> Syncing database...
                </div>
              )}

              {/* VIEW: DASHBOARD */}
              {activeView === 'dashboard' && !selectedTenant && (
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                    <div>
                      <h1 style={{ fontSize: '2.2rem', marginBottom: '6px' }}>Dashboard Overview</h1>
                      <p style={{ color: 'var(--text-secondary)' }}>Live financials and occupancy statuses for your estates.</p>
                    </div>
                    <div style={{ display: 'flex', gap: '10px' }}>
                      <button className="dev-btn" onClick={fetchAllData}>
                        <RefreshCw size={14} /> Refresh
                      </button>
                    </div>
                  </div>

                  {/* Summary Cards */}
                  <div className="dashboard-grid">
                    <div className="dashboard-card">
                      <div className="card-icon-container info">
                        <Building2 size={24} />
                      </div>
                      <div className="card-data">
                        <span className="card-label">Total Properties</span>
                        <span className="card-value">{totalProperties}</span>
                      </div>
                    </div>
                    
                    <div className="dashboard-card">
                      <div className="card-icon-container primary">
                        <Users size={24} />
                      </div>
                      <div className="card-data">
                        <span className="card-label">Total Tenants</span>
                        <span className="card-value">{totalTenants}</span>
                      </div>
                    </div>

                    <div className="dashboard-card">
                      <div className="card-icon-container success">
                        <CreditCard size={24} />
                      </div>
                      <div className="card-data">
                        <span className="card-label">Monthly Collections</span>
                        <span className="card-value">₹{monthlyCollection}</span>
                      </div>
                    </div>

                    <div className="dashboard-card">
                      <div className="card-icon-container danger">
                        <AlertTriangle size={24} />
                      </div>
                      <div className="card-data">
                        <span className="card-label">Pending Dues</span>
                        <span className="card-value">₹{pendingAmount}</span>
                      </div>
                    </div>

                    <div className="dashboard-card">
                      <div className="card-icon-container warning">
                        <Sparkles size={24} />
                      </div>
                      <div className="card-data">
                        <span className="card-label">Deposits Held</span>
                        <span className="card-value">₹{securityDepositHeld}</span>
                      </div>
                    </div>

                    <div className="dashboard-card">
                      <div className="card-icon-container primary">
                        <BarChart3 size={24} />
                      </div>
                      <div className="card-data">
                        <span className="card-label">Occupancy Rate</span>
                        <span className="card-value">{occupancyRate}%</span>
                      </div>
                    </div>
                  </div>

                  {/* Layout Row (SVG Charts and Quick Actions) */}
                  <div className="layout-row">
                    {/* Charts Card */}
                    <div className="card">
                      <div className="card-header">
                        <h3 className="card-title">Financial & Utility Trends</h3>
                        <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Updated dynamically</span>
                      </div>
                      
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '30px' }}>
                        <div>
                          <h4 style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', marginBottom: '12px' }}>Monthly Collections (June 2026)</h4>
                          <div className="chart-container">
                            <div className="chart-bar-wrapper">
                              <div className="chart-bar" style={{ height: '70px' }}>
                                <span className="chart-tooltip">₹14k</span>
                              </div>
                              <span className="chart-label">House A</span>
                            </div>
                            <div className="chart-bar-wrapper">
                              <div className="chart-bar" style={{ height: '110px' }}>
                                <span className="chart-tooltip">₹24k</span>
                              </div>
                              <span className="chart-label">House B</span>
                            </div>
                            <div className="chart-bar-wrapper">
                              <div className="chart-bar" style={{ height: '150px' }}>
                                <span className="chart-tooltip">₹38k</span>
                              </div>
                              <span className="chart-label">Shops</span>
                            </div>
                          </div>
                        </div>

                        <div>
                          <h4 style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', marginBottom: '12px' }}>Pending Amount Overview</h4>
                          <div className="chart-container" style={{ alignItems: 'center', justifyContent: 'center' }}>
                            {/* Radial SVG Gauge representation */}
                            <svg width="120" height="120" viewBox="0 0 36 36" style={{ transform: 'rotate(-90deg)' }}>
                              <path fill="none" stroke="var(--border-color)" strokeWidth="3" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                              <path fill="none" stroke="var(--color-primary)" strokeWidth="3" strokeDasharray={`${(monthlyCollection / (monthlyCollection + pendingAmount)) * 100}, 100`} d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                            </svg>
                            <div style={{ position: 'absolute', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                              <span style={{ fontSize: '1rem', fontWeight: 800 }}>{Math.round((monthlyCollection / (monthlyCollection + pendingAmount)) * 100) || 0}%</span>
                              <span style={{ fontSize: '0.65rem', color: 'var(--text-muted)' }}>Received</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Quick Actions Card */}
                    <div className="card">
                      <h3 className="card-title" style={{ marginBottom: '20px' }}>Quick Actions</h3>
                      <div className="quick-actions-grid">
                        <button className="action-btn" onClick={() => setShowAddTenant(true)}>
                          <Users size={18} style={{ color: 'var(--color-primary)' }} />
                          Add Tenant
                          <span>Register new occupier</span>
                        </button>
                        <button className="action-btn" onClick={() => setShowAddProperty(true)}>
                          <Building2 size={18} style={{ color: 'var(--color-accent)' }} />
                          Add Property
                          <span>Register House/Shop</span>
                        </button>
                        <button className="action-btn" onClick={handleGenerateMonthlyBills}>
                          <Receipt size={18} style={{ color: 'var(--color-success)' }} />
                          Generate Bills
                          <span>Automate utility invoicing</span>
                        </button>
                        <button className="action-btn" onClick={() => setShowRecordPayment(true)}>
                          <CreditCard size={18} style={{ color: 'var(--color-warning)' }} />
                          Record Payment
                          <span>Record cash/UPI receipt</span>
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Below Layout (Pending List) */}
                  <div className="card">
                    <div className="card-header">
                      <h3 className="card-title">Pending Rent Collections</h3>
                      <span className="badge danger">Dues Attention</span>
                    </div>

                    <div className="pending-payments-list">
                      {bills.filter(b => b.status !== 'Paid').map(b => (
                        <div key={b.id} className="pending-payment-item">
                          <div className="tenant-meta">
                            <div className="card-icon-container danger" style={{ width: '40px', height: '40px', fontSize: '1.1rem' }}>
                              {b.tenantName.charAt(0)}
                            </div>
                            <div className="tenant-meta-info">
                              <h5>{b.tenantName}</h5>
                              <span>{b.propertyName} • Room {b.roomNumber} ({b.billingMonth})</span>
                            </div>
                          </div>

                          <div className="pending-amounts">
                            <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                              <div className="amount-details">
                                <span className="amount-total">₹{b.pendingAmount} Due</span>
                                <span>Total Bill: ₹{b.totalAmount}</span>
                              </div>
                              <span className={`badge ${b.status === 'Partial Paid' ? 'warning' : 'danger'}`}>{b.status}</span>
                            </div>

                            <button className="btn-primary" style={{ padding: '6px 12px', fontSize: '0.8rem', borderRadius: '8px' }} onClick={() => { setSelectedBill(b); setPaymentForm({ billId: b.id, amount: b.pendingAmount, method: 'UPI', note: '' }); setShowRecordPayment(true); }}>
                              Settle Dues
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {/* VIEW: PROPERTIES */}
              {activeView === 'properties' && (
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                    <div>
                      <h1 style={{ fontSize: '2.2rem', marginBottom: '6px' }}>Property Management</h1>
                      <p style={{ color: 'var(--text-secondary)' }}>Overview of buildings, complexes, available rooms, and rental spaces.</p>
                    </div>
                    <button className="btn-primary" onClick={() => setShowAddProperty(true)}>
                      <Plus size={16} /> Add Property
                    </button>
                  </div>

                  <div className="properties-grid">
                    {properties.map(p => (
                      <div key={p.id} className="property-card">
                        <div className="property-header">
                          <div>
                            <span className="property-type">{p.type} Complex</span>
                            <h3>{p.name}</h3>
                          </div>
                          <Building2 size={24} style={{ color: 'var(--text-muted)' }} />
                        </div>

                        <div className="occupancy-meter">
                          <div className="occupancy-label">
                            <span>Occupancy Ratio</span>
                            <span>{p.totalRooms > 0 ? Math.round((p.occupied / p.totalRooms) * 100) : 0}%</span>
                          </div>
                          <div className="progress-bar-container">
                            <div className="progress-bar-fill" style={{ width: `${(p.occupied / p.totalRooms) * 100}%` }} />
                          </div>
                        </div>

                        <div className="property-stats">
                          <div className="property-stat-item">
                            <label>Rooms Occupied</label>
                            <span>{p.occupied} Rooms</span>
                          </div>
                          <div className="property-stat-item">
                            <label>Rooms Vacant</label>
                            <span style={{ color: p.vacant > 0 ? 'var(--color-success)' : 'inherit' }}>{p.vacant} Available</span>
                          </div>
                        </div>

                        <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Monthly Target</span>
                          <span style={{ fontWeight: 800, color: 'var(--color-primary)', fontSize: '1.1rem' }}>₹{p.monthlyRevenue || 0}/mo</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* VIEW: TENANTS */}
              {activeView === 'tenants' && !selectedTenant && (
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                    <div>
                      <h1 style={{ fontSize: '2.2rem', marginBottom: '6px' }}>Tenant Management</h1>
                      <p style={{ color: 'var(--text-secondary)' }}>Manage profiles, verify Aadhaar/PAN upload statuses, and log move outs.</p>
                    </div>
                    <button className="btn-primary" onClick={() => setShowAddTenant(true)}>
                      <Plus size={16} /> Add Tenant
                    </button>
                  </div>

                  {/* List Controls */}
                  <div className="list-controls">
                    <div style={{ display: 'flex', gap: '10px' }}>
                      <button className={`dev-btn ${propertyFilter === 'All' ? 'active' : ''}`} onClick={() => setPropertyFilter('All')}>All Estates</button>
                      {properties.map(p => (
                        <button key={p.id} className={`dev-btn ${propertyFilter === p.name ? 'active' : ''}`} onClick={() => setPropertyFilter(p.name)}>{p.name}</button>
                      ))}
                    </div>
                  </div>

                  {/* Tenants Cards Grid */}
                  <div className="tenants-grid">
                    {filteredTenants.map(t => {
                      const tBill = bills.filter(b => b.tenantId === t.id);
                      const activeBill = tBill[tBill.length - 1];
                      return (
                        <div key={t.id} className="tenant-card" onClick={() => { setSelectedTenant(t); setDetailTab('info'); }}>
                          <div className="tenant-card-header">
                            <img src={t.photo} alt={t.name} className="tenant-photo" />
                            <div className="tenant-header-info">
                              <h4>{t.name}</h4>
                              <span>Room {t.roomNumber} • {t.propertyName}</span>
                            </div>
                            <span 
                              className={`badge`} 
                              style={{ 
                                position: 'absolute', top: '24px', right: '24px', 
                                background: t.status === 'Active' ? 'var(--color-success-light)' : t.status === 'Leaving' ? 'var(--color-warning-light)' : 'var(--border-color)',
                                color: t.status === 'Active' ? 'var(--color-success)' : t.status === 'Leaving' ? 'var(--color-warning)' : 'var(--text-secondary)'
                              }}
                            >
                              {t.status}
                            </span>
                          </div>

                          <div className="tenant-card-details">
                            <div className="detail-item">
                              <label>Phone</label>
                              <span>{t.phone}</span>
                            </div>
                            <div className="detail-item">
                              <label>Monthly Rent</label>
                              <span>₹{t.rentAmount}</span>
                            </div>
                            <div className="detail-item">
                              <label>Identity</label>
                              <span>Aadhaar: Verified</span>
                            </div>
                            <div className="detail-item">
                              <label>Electricity Unit Rate</label>
                              <span>₹{t.electricityRate}/unit</span>
                            </div>
                          </div>

                          <div className="tenant-card-footer">
                            <div style={{ display: 'flex', flexDirection: 'column' }}>
                              <span className="pending-label">Current Month Status</span>
                              <span className="pending-val" style={{ color: activeBill ? (activeBill.status === 'Paid' ? 'var(--color-success)' : activeBill.status === 'Partial Paid' ? 'var(--color-warning)' : 'var(--color-danger)') : 'inherit' }}>
                                {activeBill ? activeBill.status : "No Bills generated"}
                              </span>
                            </div>
                            {activeBill && activeBill.pendingAmount > 0 && (
                              <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                                ₹{activeBill.pendingAmount} Pending
                              </span>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* VIEW: TENANT DETAILS VIEW SCREEN */}
              {selectedTenant && (
                <div>
                  <button className="dev-btn" style={{ marginBottom: '20px' }} onClick={() => setSelectedTenant(null)}>
                    ← Back to Tenants list
                  </button>

                  <div className="details-header">
                    <img src={selectedTenant.photo} alt={selectedTenant.name} className="details-photo" />
                    <div className="details-meta-info">
                      <h2>{selectedTenant.name}</h2>
                      <div className="details-meta-row">
                        <span>Room {selectedTenant.roomNumber} ({selectedTenant.roomType})</span>
                        <span>•</span>
                        <span>{selectedTenant.propertyName}</span>
                        <span>•</span>
                        <span>Moved In: {selectedTenant.moveInDate}</span>
                        <span>•</span>
                        <span className={`badge ${selectedTenant.status === 'Active' ? 'success' : selectedTenant.status === 'Leaving' ? 'warning' : 'muted'}`}>
                          {selectedTenant.status}
                        </span>
                      </div>
                    </div>

                    <div style={{ display: 'flex', gap: '10px' }}>
                      {selectedTenant.status !== 'Left' ? (
                        <button className="btn-primary" style={{ background: 'var(--color-danger)' }} onClick={() => setShowMoveOutModal(true)}>
                          <UserMinus size={16} /> Move Out Tenant
                        </button>
                      ) : (
                        <button className="btn-primary" style={{ background: 'var(--color-danger)' }} onClick={() => handlePermanentDeleteTenant(selectedTenant.id)}>
                          <Trash2 size={16} /> Delete Permanently
                        </button>
                      )}
                    </div>
                  </div>

                  {/* Tabs Section */}
                  <div className="tabs-nav">
                    <button className={`tab-btn ${detailTab === 'info' ? 'active' : ''}`} onClick={() => setDetailTab('info')}>Info Details</button>
                    <button className={`tab-btn ${detailTab === 'bills' ? 'active' : ''}`} onClick={() => setDetailTab('bills')}>Bills & Invoices</button>
                    <button className={`tab-btn ${detailTab === 'payments' ? 'active' : ''}`} onClick={() => setDetailTab('payments')}>Payments History</button>
                    <button className={`tab-btn ${detailTab === 'documents' ? 'active' : ''}`} onClick={() => setDetailTab('documents')}>Documents</button>
                    <button className={`tab-btn ${detailTab === 'comments' ? 'active' : ''}`} onClick={() => setDetailTab('comments')}>Comments/Tickets</button>
                    <button className={`tab-btn ${detailTab === 'chat' ? 'active' : ''}`} onClick={() => setDetailTab('chat')}>Seen/Chat History</button>
                  </div>

                  <div className="tab-content">
                    {/* TAB: INFO */}
                    {detailTab === 'info' && (
                      <div className="card">
                        <div className="info-grid">
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>Phone Number</h4>
                            <span style={{ fontWeight: 600 }}>{selectedTenant.phone} (Alt: {selectedTenant.altPhone || 'None'})</span>
                          </div>
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>Father's Name</h4>
                            <span style={{ fontWeight: 600 }}>{selectedTenant.fatherName}</span>
                          </div>
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>Email Address</h4>
                            <span style={{ fontWeight: 600 }}>{selectedTenant.email}</span>
                          </div>
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>Occupation</h4>
                            <span style={{ fontWeight: 600 }}>{selectedTenant.occupation}</span>
                          </div>
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>Aadhaar Number</h4>
                            <span style={{ fontWeight: 600 }}>{selectedTenant.aadhaar}</span>
                          </div>
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>PAN Number</h4>
                            <span style={{ fontWeight: 600 }}>{selectedTenant.pan}</span>
                          </div>
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>Agreement Term</h4>
                            <span style={{ fontWeight: 600 }}>{selectedTenant.agreementDuration} Months</span>
                          </div>
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>Security Deposit Refundable</h4>
                            <span style={{ fontWeight: 600 }}>₹{selectedTenant.securityDeposit}</span>
                          </div>
                          <div>
                            <h4 style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '6px' }}>Permanent Address</h4>
                            <span style={{ fontWeight: 600 }}>{selectedTenant.permanentAddress}</span>
                          </div>
                        </div>

                        {/* Account & Security Credentials Panel */}
                        <hr style={{ border: 'none', borderBottom: '1px solid var(--border-color)', margin: '24px 0' }} />
                        <h3 style={{ fontSize: '1.2rem', marginBottom: '16px' }}>Account & Security Credentials</h3>
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '24px', alignItems: 'center', justifyContent: 'space-between', background: 'var(--bg-app)', padding: '20px', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                              <span style={{ fontWeight: 700, fontSize: '0.9rem' }}>User ID:</span>
                              <span className="badge muted" style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                                {selectedTenant.tenantLoginId || 'NOT ASSIGNED'}
                              </span>
                            </div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <span style={{ fontWeight: 700, fontSize: '0.9rem' }}>Login Access:</span>
                              <span className={`badge ${selectedTenant.loginEnabled ? 'success' : 'danger'}`} style={{ fontSize: '0.8rem' }}>
                                {selectedTenant.loginEnabled ? 'Enabled' : 'Disabled'}
                              </span>
                            </div>
                          </div>

                          <div style={{ display: 'flex', gap: '12px' }}>
                            <button 
                              className="dev-btn"
                              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem' }}
                              onClick={async () => {
                                const newId = prompt("Enter new Tenant User ID:", selectedTenant.tenantLoginId || "");
                                if (!newId) return;
                                try {
                                  const res = await apiFetch(`${API_BASE}/tenants/${selectedTenant.id}/credentials`, {
                                    method: 'PATCH',
                                    body: { tenantLoginId: newId }
                                  });
                                  const data = await res.json();
                                  triggerToast("🔑 Tenant User ID updated!");
                                  setTenants(tenants.map(t => t.id === selectedTenant.id ? { ...t, tenantLoginId: data.tenantLoginId } : t));
                                  setSelectedTenant({ ...selectedTenant, tenantLoginId: data.tenantLoginId });
                                } catch (e) {
                                  alert(e.message);
                                }
                              }}
                            >
                              Edit User ID
                            </button>

                            <button 
                              className="dev-btn"
                              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem' }}
                              onClick={async () => {
                                if (!confirm("Reset tenant's password? This will generate a temporary password and log out all active sessions.")) return;
                                try {
                                  const res = await apiFetch(`${API_BASE}/tenants/${selectedTenant.id}/reset-password`, {
                                    method: 'POST'
                                  });
                                  const data = await res.json();
                                  alert(`🔑 Password Reset Successful!\n\nTemporary Password: ${data.tempPassword}\n\nPlease share this password with the tenant. They will be forced to change it on their next login.`);
                                  triggerToast("🔑 Password reset successful!");
                                } catch (e) {
                                  alert(e.message);
                                }
                              }}
                            >
                              Reset Password
                            </button>

                            <button 
                              className="dev-btn"
                              style={{ 
                                display: 'flex', 
                                alignItems: 'center', 
                                gap: '6px', 
                                fontSize: '0.85rem',
                                color: 'white', 
                                backgroundColor: selectedTenant.loginEnabled ? 'var(--color-danger)' : 'var(--color-success)',
                                borderColor: selectedTenant.loginEnabled ? 'var(--color-danger)' : 'var(--color-success)'
                              }}
                              onClick={async () => {
                                const targetState = !selectedTenant.loginEnabled;
                                if (!confirm(`Are you sure you want to ${targetState ? 'enable' : 'disable'} login for this tenant?`)) return;
                                try {
                                  const res = await apiFetch(`${API_BASE}/tenants/${selectedTenant.id}/toggle-login`, {
                                    method: 'PATCH',
                                    body: { enabled: targetState }
                                  });
                                  const data = await res.json();
                                  triggerToast(`🔑 Login ${data.loginEnabled ? 'enabled' : 'disabled'}!`);
                                  setTenants(tenants.map(t => t.id === selectedTenant.id ? { ...t, loginEnabled: data.loginEnabled } : t));
                                  setSelectedTenant({ ...selectedTenant, loginEnabled: data.loginEnabled });
                                } catch (e) {
                                  alert(e.message);
                                }
                              }}
                            >
                              {selectedTenant.loginEnabled ? 'Disable Account' : 'Enable Account'}
                            </button>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* TAB: BILLS */}
                    {detailTab === 'bills' && (
                      <div className="card">
                        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                          <thead>
                            <tr style={{ borderBottom: '2px solid var(--border-color)', paddingBottom: '12px' }}>
                              <th style={{ padding: '12px' }}>Month</th>
                              <th style={{ padding: '12px' }}>Rent</th>
                              <th style={{ padding: '12px' }}>Electricity (Units)</th>
                              <th style={{ padding: '12px' }}>Water</th>
                              <th style={{ padding: '12px' }}>Total Amount</th>
                              <th style={{ padding: '12px' }}>Paid</th>
                              <th style={{ padding: '12px' }}>Pending</th>
                              <th style={{ padding: '12px' }}>Status</th>
                              <th style={{ padding: '12px' }}>Actions</th>
                            </tr>
                          </thead>
                          <tbody>
                            {bills.filter(b => b.tenantId === selectedTenant.id).map(b => (
                              <tr key={b.id} style={{ borderBottom: '1px solid var(--border-color)' }}>
                                <td style={{ padding: '12px', fontWeight: 600 }}>{b.billingMonth}</td>
                                <td style={{ padding: '12px' }}>₹{b.rentAmount}</td>
                                <td style={{ padding: '12px' }}>₹{b.electricityAmount} ({b.electricityUnits} units)</td>
                                <td style={{ padding: '12px' }}>₹{b.waterCharges}</td>
                                <td style={{ padding: '12px', fontWeight: 700 }}>₹{b.totalAmount}</td>
                                <td style={{ padding: '12px', color: 'var(--color-primary)', fontWeight: 600 }}>₹{b.paidAmount}</td>
                                <td style={{ padding: '12px', color: b.pendingAmount > 0 ? 'var(--color-danger)' : 'inherit', fontWeight: 600 }}>₹{b.pendingAmount}</td>
                                <td style={{ padding: '12px' }}>
                                  <span className={`badge ${b.status === 'Paid' ? 'success' : b.status === 'Partial Paid' ? 'warning' : 'danger'}`}>{b.status}</span>
                                </td>
                                <td style={{ padding: '12px' }}>
                                  <button className="dev-btn" style={{ padding: '4px 8px', fontSize: '0.75rem' }} onClick={() => openEditBillModal(b)}>
                                    Edit Bill
                                  </button>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}

                    {/* TAB: PAYMENTS */}
                    {detailTab === 'payments' && (
                      <div className="card">
                        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                          <thead>
                            <tr style={{ borderBottom: '2px solid var(--border-color)' }}>
                              <th style={{ padding: '12px' }}>Date</th>
                              <th style={{ padding: '12px' }}>Month Linked</th>
                              <th style={{ padding: '12px' }}>Payment Mode</th>
                              <th style={{ padding: '12px' }}>Notes</th>
                              <th style={{ padding: '12px' }}>Amount Settle</th>
                            </tr>
                          </thead>
                          <tbody>
                            {bills.filter(b => b.tenantId === selectedTenant.id).flatMap(b => b.payments.map((p, idx) => (
                              <tr key={`${b.id}-${idx}`} style={{ borderBottom: '1px solid var(--border-color)' }}>
                                <td style={{ padding: '12px' }}>{p.date}</td>
                                <td style={{ padding: '12px', fontWeight: 600 }}>{b.billingMonth}</td>
                                <td style={{ padding: '12px' }}><span className="badge muted">{p.method}</span></td>
                                <td style={{ padding: '12px', color: 'var(--text-secondary)' }}>{p.note || '-'}</td>
                                <td style={{ padding: '12px', fontWeight: 700, color: 'var(--color-success)' }}>₹{p.amount}</td>
                              </tr>
                            )))}
                          </tbody>
                        </table>
                      </div>
                    )}

                    {/* TAB: DOCUMENTS */}
                    {detailTab === 'documents' && (
                      <div className="card">
                        <div className="document-grid">
                          <div className="document-item" onClick={() => alert("Simulating download profilePhoto.jpg")}>
                            <User size={32} />
                            <span className="doc-name">Profile Photo</span>
                            <span className="badge success">Verified</span>
                          </div>
                          <div className="document-item" onClick={() => alert("Simulating Aadhaar Card PDF preview")}>
                            <FileText size={32} />
                            <span className="doc-name">Aadhaar Card (Front/Back)</span>
                            <span className="badge success">Verified</span>
                          </div>
                          <div className="document-item" onClick={() => alert("Simulating PAN Card JPG preview")}>
                            <FileText size={32} />
                            <span className="doc-name">PAN Card</span>
                            <span className="badge success">Verified</span>
                          </div>
                          <div className="document-item" onClick={() => alert("Opening Rental Agreement document copy")}>
                            <FileText size={32} />
                            <span className="doc-name">Rental Agreement</span>
                            <span className="badge success">Signed</span>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* TAB: COMMENTS (Maintenance queries) */}
                    {detailTab === 'comments' && (
                      <div>
                        {comments.filter(c => c.tenantId === selectedTenant.id).map(thread => (
                          <div key={thread.id} className="comment-thread-card">
                            <div className="comment-thread-header">
                              <div>
                                <h4 style={{ fontSize: '1.1rem', marginBottom: '4px' }}>{thread.title}</h4>
                                <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Category: {thread.category} • Reported: {new Date(thread.createdAt).toLocaleDateString()}</span>
                              </div>
                              <span className={`badge ${thread.status === 'Open' ? 'danger' : thread.status === 'In Progress' ? 'warning' : 'success'}`}>{thread.status}</span>
                            </div>

                            <div className="thread-replies-list">
                              {thread.replies.map(rep => (
                                <div key={rep.id} className="thread-reply-item">
                                  <div className="reply-meta">
                                    <span>{rep.name} ({rep.sender})</span>
                                    <span>{new Date(rep.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                                  </div>
                                  <p className="reply-body">{rep.message}</p>
                                </div>
                              ))}
                            </div>

                            {/* Reply Input Form */}
                            <form className="reply-input-wrapper" onSubmit={(e) => { setActiveCommentId(thread.id); handleSendOwnerCommentReply(e); }}>
                              <input 
                                type="text" 
                                placeholder="Write a reply..." 
                                className="input-field" 
                                value={activeCommentId === thread.id ? ownerCommentText : ''}
                                onChange={(e) => { setActiveCommentId(thread.id); setOwnerCommentText(e.target.value); }}
                              />
                              <button type="submit" className="btn-primary" style={{ padding: '8px 16px' }}><Send size={14} /></button>
                            </form>
                          </div>
                        ))}
                      </div>
                    )}

                    {/* TAB: CHAT (WhatsApp style) */}
                    {detailTab === 'chat' && (
                      <div className="chat-window">
                        <div className="chat-sidebar">
                          <div className="chat-search">
                            <span style={{ fontSize: '0.9rem', fontWeight: 700 }}>Conversation</span>
                          </div>
                          <div className="chats-list-wrapper">
                            <div className="chat-list-item active">
                              <img src={selectedTenant.photo} className="user-avatar" />
                              <div className="chat-item-meta">
                                <span className="chat-item-name">{selectedTenant.name}</span>
                                <span className="chat-item-preview">Direct conversation thread</span>
                              </div>
                            </div>
                          </div>
                        </div>

                        <div className="chat-main">
                          <div className="chat-main-header">
                            <div className="chat-header-user">
                              <img src={selectedTenant.photo} className="user-avatar" />
                              <div>
                                <h4>{selectedTenant.name}</h4>
                                <span>Online</span>
                              </div>
                            </div>
                          </div>

                          <div className="chat-messages-container">
                            {chats.find(c => c.tenantId === selectedTenant.id)?.messages.map((m, idx) => (
                              <div key={m.id || idx} className={`chat-message-bubble ${m.sender === 'owner' ? 'sent' : 'received'}`}>
                                {m.attachment && (
                                  <div className="attachment-box" style={{ background: 'rgba(0,0,0,0.1)', padding: '6px', borderRadius: '6px', marginBottom: '6px', fontSize: '0.8rem' }}>
                                    📎 {m.attachment}
                                  </div>
                                )}
                                <p>{m.text}</p>
                                <span className="message-time">{new Date(m.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                              </div>
                            ))}
                          </div>

                          <form className="chat-input-bar" onSubmit={(e) => { setActiveChatTenantId(selectedTenant.id); handleSendOwnerMessage(e); }}>
                            <input 
                              type="text" 
                              placeholder="Type a message to tenant..." 
                              value={activeChatTenantId === selectedTenant.id ? ownerChatText : ''}
                              onChange={(e) => { setActiveChatTenantId(selectedTenant.id); setOwnerChatText(e.target.value); }}
                            />
                            <button type="submit" className="btn-primary" style={{ padding: '10px 16px', borderRadius: '20px' }}>
                              <Send size={14} />
                            </button>
                          </form>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* VIEW: BILLS & UTILITIES (GLOBAL LIST) */}
              {activeView === 'bills' && !selectedTenant && (
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                    <div>
                      <h1 style={{ fontSize: '2.2rem', marginBottom: '6px' }}>Rent & Utility Bills</h1>
                      <p style={{ color: 'var(--text-secondary)' }}>Automate invoicing and override water/electricity unit rates manually.</p>
                    </div>
                    <div style={{ display: 'flex', gap: '10px' }}>
                      <button className="dev-btn" onClick={handleGenerateMonthlyBills}>
                        <Receipt size={16} /> Auto-Generate Monthly Bills
                      </button>
                    </div>
                  </div>

                  <div className="card" style={{ padding: '24px', overflowX: 'auto' }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                      <thead>
                        <tr style={{ borderBottom: '2.5px solid var(--border-color)' }}>
                          <th style={{ padding: '14px' }}>Tenant Name</th>
                          <th style={{ padding: '14px' }}>Estate Room</th>
                          <th style={{ padding: '14px' }}>Month</th>
                          <th style={{ padding: '14px' }}>Rent Base</th>
                          <th style={{ padding: '14px' }}>Electricity (units)</th>
                          <th style={{ padding: '14px' }}>Water Charges</th>
                          <th style={{ padding: '14px' }}>Discounts / Fees</th>
                          <th style={{ padding: '14px' }}>Total Amount</th>
                          <th style={{ padding: '14px' }}>Paid / Pending</th>
                          <th style={{ padding: '14px' }}>Status</th>
                          <th style={{ padding: '14px' }}>Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {bills.map(b => (
                          <tr key={b.id} style={{ borderBottom: '1px solid var(--border-color)' }}>
                            <td style={{ padding: '14px', fontWeight: 700 }}>{b.tenantName}</td>
                            <td style={{ padding: '14px' }}>{b.propertyName} • Room {b.roomNumber}</td>
                            <td style={{ padding: '14px', fontWeight: 600 }}>{b.billingMonth}</td>
                            <td style={{ padding: '14px' }}>₹{b.rentAmount}</td>
                            <td style={{ padding: '14px' }}>₹{b.electricityAmount} ({b.electricityUnits} u @ ₹{b.electricityRate})</td>
                            <td style={{ padding: '14px' }}>₹{b.waterCharges}</td>
                            <td style={{ padding: '14px' }}>
                              {b.discount > 0 && <span style={{ color: 'var(--color-success)' }}>-₹{b.discount} </span>}
                              {b.lateFee > 0 && <span style={{ color: 'var(--color-danger)' }}>+₹{b.lateFee} </span>}
                            </td>
                            <td style={{ padding: '14px', fontWeight: 800 }}>₹{b.totalAmount}</td>
                            <td style={{ padding: '14px' }}>
                              <span style={{ color: 'var(--color-success)' }}>₹{b.paidAmount}</span> / <span style={{ color: 'var(--color-danger)' }}>₹{b.pendingAmount}</span>
                            </td>
                            <td style={{ padding: '14px' }}>
                              <span className={`badge ${b.status === 'Paid' ? 'success' : b.status === 'Partial Paid' ? 'warning' : 'danger'}`}>{b.status}</span>
                            </td>
                            <td style={{ padding: '14px' }}>
                              <button className="dev-btn" style={{ padding: '6px 10px', fontSize: '0.8rem' }} onClick={() => openEditBillModal(b)}>
                                Override/Edit
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* VIEW: PAYMENTS LEDGER (GLOBAL LIST) */}
              {activeView === 'payments' && !selectedTenant && (
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                    <div>
                      <h1 style={{ fontSize: '2.2rem', marginBottom: '6px' }}>Payments Ledger</h1>
                      <p style={{ color: 'var(--text-secondary)' }}>Full transactional listing of recorded UPI, Cash, and Bank Transfer receipts.</p>
                    </div>
                    <button className="btn-primary" onClick={() => setShowRecordPayment(true)}>
                      <Plus size={16} /> Record Payment
                    </button>
                  </div>

                  <div className="card" style={{ padding: '24px' }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                      <thead>
                        <tr style={{ borderBottom: '2.5px solid var(--border-color)' }}>
                          <th style={{ padding: '14px' }}>Transaction Date</th>
                          <th style={{ padding: '14px' }}>Tenant</th>
                          <th style={{ padding: '14px' }}>Billing Cycle</th>
                          <th style={{ padding: '14px' }}>Method</th>
                          <th style={{ padding: '14px' }}>Notes/Reference</th>
                          <th style={{ padding: '14px' }}>Amount Settle</th>
                        </tr>
                      </thead>
                      <tbody>
                        {bills.flatMap(b => b.payments.map((p, idx) => (
                          <tr key={`${b.id}-${idx}`} style={{ borderBottom: '1px solid var(--border-color)' }}>
                            <td style={{ padding: '14px' }}>{p.date}</td>
                            <td style={{ padding: '14px', fontWeight: 700 }}>{b.tenantName}</td>
                            <td style={{ padding: '14px' }}>{b.propertyName} (Room {b.roomNumber}) • {b.billingMonth}</td>
                            <td style={{ padding: '14px' }}><span className="badge muted">{p.method}</span></td>
                            <td style={{ padding: '14px', color: 'var(--text-secondary)' }}>{p.note || '-'}</td>
                            <td style={{ padding: '14px', fontWeight: 800, color: 'var(--color-success)', fontSize: '1rem' }}>₹{p.amount}</td>
                          </tr>
                        )))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* VIEW: CHAT & COMMENTS (GLOBAL BOARD) */}
              {activeView === 'chat' && !selectedTenant && (
                <div>
                  <h1 style={{ fontSize: '2.2rem', marginBottom: '6px' }}>Communication Board</h1>
                  <p style={{ color: 'var(--text-secondary)', marginBottom: '32px' }}>Interact with tenants via WhatsApp-style Chat, or respond to Maintenance tickets.</p>
                  
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '30px' }}>
                    {/* Left chat panel list */}
                    <div className="card">
                      <h3 style={{ marginBottom: '16px' }}>Active Chat Inboxes</h3>
                      <div className="pending-payments-list">
                        {tenants.map(t => (
                          <div key={t.id} className="pending-payment-item" style={{ cursor: 'pointer' }} onClick={() => { setSelectedTenant(t); setDetailTab('chat'); }}>
                            <div className="tenant-meta">
                              <img src={t.photo} className="user-avatar" />
                              <div className="tenant-meta-info">
                                <h5>{t.name}</h5>
                                <span>Room {t.roomNumber}</span>
                              </div>
                            </div>
                            <ChevronRight size={18} />
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* Right maintenance list panel */}
                    <div className="card">
                      <h3 style={{ marginBottom: '16px' }}>Active Maintenance Tickets</h3>
                      <div className="pending-payments-list">
                        {comments.map(c => (
                          <div key={c.id} className="pending-payment-item" style={{ cursor: 'pointer' }} onClick={() => { const ten = tenants.find(t => t.id === c.tenantId); if(ten) { setSelectedTenant(ten); setDetailTab('comments'); } }}>
                            <div className="tenant-meta">
                              <div className="tenant-meta-info">
                                <h5>{c.title}</h5>
                                <span style={{ color: 'var(--color-primary)', fontWeight: 600 }}>{c.tenantName} ({c.roomNumber})</span>
                              </div>
                            </div>
                            <span className={`badge ${c.status === 'Open' ? 'danger' : 'warning'}`}>{c.status}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* VIEW: DOCUMENTS (GLOBAL FILE LIST) */}
              {activeView === 'documents' && !selectedTenant && (
                <div>
                  <h1 style={{ fontSize: '2.2rem', marginBottom: '6px' }}>Central Document Vault</h1>
                  <p style={{ color: 'var(--text-secondary)', marginBottom: '32px' }}>Verify agreements, Aadhaar cards, and PAN cards for checked-in tenants.</p>

                  <div className="card">
                    <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                      <thead>
                        <tr style={{ borderBottom: '2.5px solid var(--border-color)' }}>
                          <th style={{ padding: '14px' }}>Tenant Name</th>
                          <th style={{ padding: '14px' }}>Rental Space</th>
                          <th style={{ padding: '14px' }}>Aadhaar Copy</th>
                          <th style={{ padding: '14px' }}>PAN Card</th>
                          <th style={{ padding: '14px' }}>Signed Agreement</th>
                          <th style={{ padding: '14px' }}>Other Docs</th>
                        </tr>
                      </thead>
                      <tbody>
                        {tenants.map(t => (
                          <tr key={t.id} style={{ borderBottom: '1px solid var(--border-color)' }}>
                            <td style={{ padding: '14px', fontWeight: 700 }}>{t.name}</td>
                            <td style={{ padding: '14px' }}>Room {t.roomNumber}</td>
                            <td style={{ padding: '14px' }}>
                              <button className="dev-btn" style={{ fontSize: '0.75rem', padding: '4px 8px' }} onClick={() => alert("Downloading Aadhaar for " + t.name)}>
                                <Download size={12} /> Aadhaar.pdf
                              </button>
                            </td>
                            <td style={{ padding: '14px' }}>
                              <button className="dev-btn" style={{ fontSize: '0.75rem', padding: '4px 8px' }} onClick={() => alert("Downloading PAN Card for " + t.name)}>
                                <Download size={12} /> PAN_Card.png
                              </button>
                            </td>
                            <td style={{ padding: '14px' }}>
                              <button className="dev-btn" style={{ fontSize: '0.75rem', padding: '4px 8px' }} onClick={() => alert("Downloading agreement.pdf for " + t.name)}>
                                <Download size={12} /> Agreement_Signed.pdf
                              </button>
                            </td>
                            <td style={{ padding: '14px', color: 'var(--text-muted)' }}>-</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* VIEW: REPORTS & STATS */}
              {activeView === 'reports' && (
                <div className="card" style={{ textAlign: 'center', padding: '60px 20px' }}>
                  <BarChart3 size={48} style={{ color: 'var(--color-primary)', marginBottom: '16px' }} />
                  <h2>Estates Utility & Electricity Trend Analysis</h2>
                  <p style={{ color: 'var(--text-secondary)', maxWidth: '480px', margin: '12px auto' }}>Check electricity unit usages, monthly collection averages, and water expenses per estate.</p>
                  
                  <div style={{ display: 'flex', justifyContent: 'center', gap: '20px', marginTop: '24px' }}>
                    <div style={{ border: '1px solid var(--border-color)', padding: '16px', borderRadius: '16px', minWidth: '150px' }}>
                      <h4 style={{ color: 'var(--text-muted)' }}>Total Collection</h4>
                      <span style={{ fontSize: '1.5rem', fontWeight: 800 }}>₹{monthlyCollection + 7250}</span>
                    </div>
                    <div style={{ border: '1px solid var(--border-color)', padding: '16px', borderRadius: '16px', minWidth: '150px' }}>
                      <h4 style={{ color: 'var(--text-muted)' }}>Average Dues</h4>
                      <span style={{ fontSize: '1.5rem', fontWeight: 800 }}>₹{pendingAmount / 3 || 0}</span>
                    </div>
                  </div>
                </div>
              )}

              {/* VIEW: SETTINGS */}
              {activeView === 'settings' && (
                <div className="card">
                  <h3>Admin Configuration</h3>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginTop: '24px', maxWidth: '360px' }}>
                    <div className="form-group">
                      <label>Estate Manager Name</label>
                      <input type="text" className="input-field" defaultValue="Sandeep Kumar" />
                    </div>
                    <div className="form-group">
                      <label>Registered Mobile number</label>
                      <input type="text" className="input-field" defaultValue="9999999999" />
                    </div>
                    <button className="btn-primary">Save Settings</button>
                  </div>
                </div>
              )}

              {/* VIEW: ACTIVE SESSIONS */}
              {activeView === 'sessions' && (
                <div className="card" style={{ padding: '0px' }}>
                  <ActiveSessions apiFetch={apiFetch} API_BASE={API_BASE} triggerToast={triggerToast} />
                </div>
              )}

            </div>
          </div>
        </div>
      ) : (
        // TENANT VIEW FULL PREVIEW (IF SIMULATOR DEACTIVATED, USER CAN BROWSE MOBILE RENDER FULL SCREEN)
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '40px', background: 'var(--bg-app)', minHeight: 'calc(100vh - 53px)' }}>
          <div style={{ border: '1px solid var(--border-color)', width: '375px', height: '700px', background: 'var(--bg-card)', borderRadius: '30px', boxShadow: 'var(--shadow-premium)', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            <div style={{ background: 'var(--bg-app)', padding: '20px 24px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontWeight: 800 }}>Rentify Mobile App</span>
              <span className="badge success">Demo Active</span>
            </div>
            
            {/* Embedded Mobile rendering */}
            <div style={{ flexGrow: 1, overflowY: 'auto', padding: '20px' }}>
              <h3>Welcome, Ravi!</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Room 101, House A</p>
            </div>
          </div>
        </div>
      ))}

      {/* ============================================================== */}
      {/* SMARTPHONE DEVICE SIMULATOR SIDE DRAWERS / OVERLAY FRAME */}
      {/* ============================================================== */}
      {showSimulator && (
        <div className="phone-simulator-overlay">
          {/* Top Speaker/Notch */}
          <div className="phone-header-notch">
            <div className="phone-notch-dot"></div>
          </div>

          <button className="simulator-toggle-btn" onClick={() => setShowSimulator(false)} style={{ top: '10px', right: '15px' }}>
            <X size={18} />
          </button>

          {/* Simulator Screen */}
          <div className="phone-screen">
            {/* Status bar */}
            <div className="phone-status-bar">
              <span>9:41 AM</span>
              <div className="phone-status-icons">
                <span>📶</span>
                <span>🔋</span>
              </div>
            </div>

            {/* Sim Login vs App view */}
            {!simIsLogged ? (
              <div style={{ padding: '32px 24px', display: 'flex', flexDirection: 'column', gap: '20px', justifyContent: 'center', height: '100%' }}>
                <div style={{ textAlign: 'center' }}>
                  <Logo size={48} />
                  <h3 style={{ fontSize: '1.5rem', marginTop: '10px' }}>Rentify Mobile</h3>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '0.8rem' }}>Tenant App Portal</p>
                </div>
                
                <form onSubmit={handleSimLogin} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <div className="form-group">
                    <label>Tenant Mobile / Email</label>
                    <input 
                      type="text" 
                      className="input-field" 
                      placeholder="e.g. 9876543210 (Ravi)" 
                      value={simPhone}
                      onChange={(e) => setSimPhone(e.target.value)}
                    />
                  </div>
                  <div className="form-group">
                    <label>Tenant Password</label>
                    <input 
                      type="password" 
                      className="input-field" 
                      placeholder="••••••••" 
                      defaultValue="password"
                      readOnly
                    />
                  </div>
                  <button type="submit" className="btn-primary" style={{ padding: '12px' }}>
                    Secure Mobile Log In
                  </button>
                </form>

                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textAlign: 'center' }}>
                  Demo Accounts: Ravi (9876543210), Priya (9812345678)
                </div>
              </div>
            ) : (
              // SIM ACTIVE NAV RENDER
              <div style={{ display: 'flex', flexDirection: 'column', height: '100%', paddingBottom: '65px' }}>
                
                {/* Sim Header Banner */}
                <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-color)', display: 'flex', justify: 'space-between', background: 'var(--bg-card)' }}>
                  <div>
                    <h4 style={{ fontSize: '0.9rem' }}>{simTenantData?.name || 'Loading Tenant...'}</h4>
                    <span style={{ fontSize: '0.7rem', color: 'var(--text-secondary)' }}>Room {simTenantData?.roomNumber} • {simTenantData?.propertyName}</span>
                  </div>
                  <button className="dev-btn" style={{ fontSize: '0.65rem', padding: '4px 6px' }} onClick={() => setSimIsLogged(false)}>Log Out</button>
                </div>

                {/* Tab body */}
                <div style={{ flexGrow: 1, overflowY: 'auto', padding: '16px' }}>
                  
                  {/* TAB 1: HOME (Dashboard) */}
                  {simActiveTab === 'home' && (
                    <div>
                      {/* Current Due summary */}
                      {simLatestBill ? (
                        <div style={{ background: '#1E293B', color: 'white', padding: '20px', borderRadius: '16px', display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '16px' }}>
                          <span style={{ fontSize: '0.75rem', color: '#94A3B8' }}>Pending Amount ({simLatestBill.billingMonth})</span>
                          <span style={{ fontSize: '1.8rem', fontWeight: 800 }}>₹{simLatestBill.pendingAmount}</span>
                          
                          {/* Progress */}
                          <div style={{ height: '6px', background: '#334155', borderRadius: '3px', overflow: 'hidden' }}>
                            <div style={{ height: '100%', background: '#6366F1', width: `${(simLatestBill.paidAmount / simLatestBill.totalAmount) * 100}%` }}></div>
                          </div>
                          <span style={{ fontSize: '0.65rem', color: '#94A3B8' }}>{Math.round((simLatestBill.paidAmount / simLatestBill.totalAmount) * 100)}% Paid</span>

                          <span style={{ fontSize: '0.7rem' }}>Due Date: {simLatestBill.dueDate}</span>
                          
                          {simLatestBill.pendingAmount > 0 && (
                            <button className="btn-primary" style={{ padding: '10px', fontSize: '0.85rem' }} onClick={handleSimPayBill}>
                              Pay Bill (UPI Sim)
                            </button>
                          )}
                        </div>
                      ) : (
                        <div style={{ background: '#1E293B', padding: '16px', borderRadius: '16px', color: 'white', marginBottom: '16px' }}>
                          No pending bills for this month.
                        </div>
                      )}

                      {/* Comment ticket builder */}
                      <form className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '10px' }} onSubmit={handleSimSubmitComment}>
                        <h4 style={{ fontSize: '0.85rem' }}>Report Maintenance Concern</h4>
                        <select className="input-field" style={{ padding: '6px' }} value={simCommentCategory} onChange={(e) => setSimCommentCategory(e.target.value)}>
                          <option value="Maintenance">General Maintenance</option>
                          <option value="Plumbing">Plumbing leakage</option>
                          <option value="Electrical">Electric/Fan not working</option>
                        </select>
                        <input 
                          type="text" 
                          placeholder="Issue Title" 
                          className="input-field" 
                          style={{ padding: '6px' }} 
                          value={simNewCommentTitle}
                          onChange={(e) => setSimNewCommentTitle(e.target.value)}
                        />
                        <textarea 
                          placeholder="Description..." 
                          className="input-field" 
                          style={{ padding: '6px', height: '60px' }}
                          value={simNewCommentBody}
                          onChange={(e) => setSimNewCommentBody(e.target.value)}
                        />
                        <button type="submit" className="btn-primary" style={{ padding: '8px', fontSize: '0.8rem' }}>Log Ticket</button>
                      </form>
                    </div>
                  )}

                  {/* TAB 2: BILLS */}
                  {simActiveTab === 'bills' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      {bills.filter(b => b.tenantId === simTenantData.id).map(b => (
                        <div key={b.id} style={{ border: '1px solid var(--border-color)', background: 'var(--bg-card)', padding: '14px', borderRadius: '16px' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                            <span style={{ fontWeight: 700, fontSize: '0.85rem' }}>{b.billingMonth}</span>
                            <span className={`badge ${b.status === 'Paid' ? 'success' : 'warning'}`} style={{ fontSize: '0.65rem' }}>{b.status}</span>
                          </div>
                          
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                            <span>Rent Base: ₹{b.rentAmount}</span>
                            <span>Electricity Usage: ₹{b.electricityAmount} ({b.electricityUnits} units)</span>
                            <span>Water fix charges: ₹{b.waterCharges}</span>
                            <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>Total Settle Bill: ₹{b.totalAmount}</span>
                          </div>

                          {b.paidAmount > 0 && (
                            <button className="dev-btn" style={{ fontSize: '0.7rem', padding: '4px 6px', marginTop: '10px' }} onClick={() => alert("Downloaded PDF Receipt for " + b.billingMonth)}>
                              Download Receipt
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                  )}

                  {/* TAB 3: CHAT */}
                  {simActiveTab === 'chat' && (
                    <div style={{ display: 'flex', flexDirection: 'column', height: '520px' }}>
                      <div style={{ flexGrow: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '10px', padding: '8px' }}>
                        {simChatMessages.map(m => (
                          <div key={m.id} style={{
                            alignSelf: m.sender === 'tenant' ? 'flex-end' : 'flex-start',
                            background: m.sender === 'tenant' ? 'var(--color-primary)' : 'var(--bg-card)',
                            color: m.sender === 'tenant' ? 'white' : 'var(--text-primary)',
                            padding: '8px 12px',
                            borderRadius: '12px',
                            maxWidth: '80%',
                            fontSize: '0.8rem',
                            border: m.sender !== 'tenant' ? '1px solid var(--border-color)' : 'none'
                          }}>
                            {m.attachment && <div style={{ fontSize: '0.7rem', opacity: 0.8 }}>📎 {m.attachment}</div>}
                            <p>{m.text}</p>
                          </div>
                        ))}
                      </div>
                      
                      <form onSubmit={handleSimSendChat} style={{ display: 'flex', gap: '6px', padding: '8px 0' }}>
                        <input 
                          type="text" 
                          placeholder="Reply to owner..." 
                          className="input-field" 
                          style={{ padding: '6px', borderRadius: '20px', flexGrow: 1 }}
                          value={simChatText}
                          onChange={(e) => setSimChatText(e.target.value)}
                        />
                        <button type="submit" className="btn-primary" style={{ padding: '8px 12px', borderRadius: '50%' }}>
                          <Send size={12} />
                        </button>
                      </form>
                    </div>
                  )}

                  {/* TAB 4: PROFILE */}
                  {simActiveTab === 'profile' && simTenantData && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px', marginBottom: '10px' }}>
                        <img src={simTenantData.photo} className="user-avatar" style={{ width: '60px', height: '60px' }} />
                        <h4 style={{ fontSize: '1rem' }}>{simTenantData.name}</h4>
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>{simTenantData.occupation}</span>
                      </div>

                      <div className="card" style={{ padding: '12px', fontSize: '0.75rem', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                        <span>Aadhaar: {simTenantData.aadhaar} (Verified)</span>
                        <span>PAN: {simTenantData.pan} (Verified)</span>
                        <span>Security Deposit Settle: ₹{simTenantData.securityDeposit}</span>
                        <span>Rent Cycle Amount: ₹{simTenantData.rentAmount}</span>
                        <span>Agreement Duration: {simTenantData.agreementDuration} months</span>
                      </div>
                    </div>
                  )}
                </div>

                {/* Smartphone Bottom Tab navigation Bar */}
                <div className="phone-nav-bar">
                  <div className={`phone-nav-item ${simActiveTab === 'home' ? 'active' : ''}`} onClick={() => setSimActiveTab('home')}>
                    <span>🏠</span>
                    <span style={{ fontSize: '9px' }}>Home</span>
                  </div>
                  <div className={`phone-nav-item ${simActiveTab === 'bills' ? 'active' : ''}`} onClick={() => setSimActiveTab('bills')}>
                    <span>🧾</span>
                    <span style={{ fontSize: '9px' }}>Bills</span>
                  </div>
                  <div className={`phone-nav-item ${simActiveTab === 'chat' ? 'active' : ''}`} onClick={() => setSimActiveTab('chat')}>
                    <span>💬</span>
                    <span style={{ fontSize: '9px' }}>Chat</span>
                  </div>
                  <div className={`phone-nav-item ${simActiveTab === 'profile' ? 'active' : ''}`} onClick={() => setSimActiveTab('profile')}>
                    <span>👤</span>
                    <span style={{ fontSize: '9px' }}>Profile</span>
                  </div>
                </div>

              </div>
            )}

            {/* Sim Home Indicator Bar */}
            <div style={{ height: '5px', width: '130px', background: 'var(--text-primary)', borderRadius: '3px', position: 'absolute', bottom: '8px', left: '50%', transform: 'translateX(-50%)' }}></div>
          </div>
        </div>
      )}

      {/* ============================================================== */}
      {/* MODAL POPUPS (OWNER CONTROL WIZARDS) */}
      {/* ============================================================== */}

      {/* MODAL: ADD TENANT (WIZARD STEPS) */}
      {showAddTenant && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h2>Add New Tenant Checked-in</h2>
              <button className="close-btn" onClick={() => setShowAddTenant(false)}><X size={20} /></button>
            </div>

            {/* Steps indicator */}
            <div className="wizard-steps">
              <div className={`wizard-step ${tenantWizardStep === 1 ? 'active' : tenantWizardStep > 1 ? 'completed' : ''}`}>1</div>
              <div className={`wizard-step ${tenantWizardStep === 2 ? 'active' : tenantWizardStep > 2 ? 'completed' : ''}`}>2</div>
              <div className={`wizard-step ${tenantWizardStep === 3 ? 'active' : tenantWizardStep > 3 ? 'completed' : ''}`}>3</div>
              <div className={`wizard-step ${tenantWizardStep === 4 ? 'active' : tenantWizardStep > 4 ? 'completed' : ''}`}>4</div>
            </div>

            {/* STEP 1: Personal Details */}
            {tenantWizardStep === 1 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <h3>Section 1: Personal Details</h3>
                <div className="form-group">
                  <label>Full Name</label>
                  <input type="text" className="input-field" placeholder="Tenant Full Name" value={newTenantForm.name} onChange={(e) => setNewTenantForm({ ...newTenantForm, name: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Father's Name</label>
                  <input type="text" className="input-field" placeholder="Father's Name" value={newTenantForm.fatherName} onChange={(e) => setNewTenantForm({ ...newTenantForm, fatherName: e.target.value })} />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label>Phone Number</label>
                    <input type="text" className="input-field" placeholder="10-digit number" value={newTenantForm.phone} onChange={(e) => setNewTenantForm({ ...newTenantForm, phone: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Alternative Contact</label>
                    <input type="text" className="input-field" placeholder="Alt phone" value={newTenantForm.altPhone} onChange={(e) => setNewTenantForm({ ...newTenantForm, altPhone: e.target.value })} />
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label>Email Address</label>
                    <input type="email" className="input-field" placeholder="email@gmail.com" value={newTenantForm.email} onChange={(e) => setNewTenantForm({ ...newTenantForm, email: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Occupation</label>
                    <input type="text" className="input-field" placeholder="e.g. Student, Engineer" value={newTenantForm.occupation} onChange={(e) => setNewTenantForm({ ...newTenantForm, occupation: e.target.value })} />
                  </div>
                </div>
              </div>
            )}

            {/* STEP 2: Identity details */}
            {tenantWizardStep === 2 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <h3>Section 2: Identity Details</h3>
                <div className="form-group">
                  <label>Aadhaar Number (12 Digit)</label>
                  <input type="text" className="input-field" placeholder="0000 0000 0000" value={newTenantForm.aadhaar} onChange={(e) => setNewTenantForm({ ...newTenantForm, aadhaar: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>PAN Number (10 character alphanumeric)</label>
                  <input type="text" className="input-field" placeholder="ABCDE1234F" value={newTenantForm.pan} onChange={(e) => setNewTenantForm({ ...newTenantForm, pan: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Permanent Address</label>
                  <textarea className="input-field" placeholder="Address from Aadhaar card" value={newTenantForm.permanentAddress} onChange={(e) => setNewTenantForm({ ...newTenantForm, permanentAddress: e.target.value })} />
                </div>
              </div>
            )}

            {/* STEP 3: Property Details */}
            {tenantWizardStep === 3 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <h3>Section 3: Property Details Allocation</h3>
                <div className="form-group">
                  <label>Select Property</label>
                  <select className="input-field" value={newTenantForm.propertyId} onChange={(e) => setNewTenantForm({ ...newTenantForm, propertyId: e.target.value })}>
                    <option value="">-- Choose building --</option>
                    {properties.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                  </select>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label>Allocated Room/Shop Number</label>
                    <input type="text" className="input-field" placeholder="e.g. 101, Shop 3" value={newTenantForm.roomNumber} onChange={(e) => setNewTenantForm({ ...newTenantForm, roomNumber: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Room/Space Type</label>
                    <select className="input-field" value={newTenantForm.roomType} onChange={(e) => setNewTenantForm({ ...newTenantForm, roomType: e.target.value })}>
                      <option value="Room">Room (Residential)</option>
                      <option value="Shop">Shop (Commercial)</option>
                      <option value="Flat">Full Apartment/Flat</option>
                    </select>
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label>Move In Date</label>
                    <input type="date" className="input-field" value={newTenantForm.moveInDate} onChange={(e) => setNewTenantForm({ ...newTenantForm, moveInDate: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Agreement Duration (months)</label>
                    <input type="number" className="input-field" placeholder="11" value={newTenantForm.agreementDuration} onChange={(e) => setNewTenantForm({ ...newTenantForm, agreementDuration: e.target.value })} />
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label>Monthly Rent Amount (₹)</label>
                    <input type="number" className="input-field" placeholder="2500" value={newTenantForm.rentAmount} onChange={(e) => setNewTenantForm({ ...newTenantForm, rentAmount: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Refundable Security Deposit (₹)</label>
                    <input type="number" className="input-field" placeholder="5000" value={newTenantForm.securityDeposit} onChange={(e) => setNewTenantForm({ ...newTenantForm, securityDeposit: e.target.value })} />
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label>Electricity Rate per unit (₹)</label>
                    <input type="number" className="input-field" placeholder="6" value={newTenantForm.electricityRate} onChange={(e) => setNewTenantForm({ ...newTenantForm, electricityRate: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Fixed Water Cost (₹)</label>
                    <input type="number" className="input-field" placeholder="150" value={newTenantForm.waterCharges} onChange={(e) => setNewTenantForm({ ...newTenantForm, waterCharges: e.target.value })} />
                  </div>
                </div>

                <hr style={{ border: 'none', borderBottom: '1px solid var(--border-color)', margin: '8px 0' }} />
                <h3>Login Credentials configuration</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', background: 'var(--bg-app)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                  
                  <div className="form-group" style={{ display: 'flex', flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
                    <label style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.85rem', fontWeight: 'bold' }}>
                      <input 
                        type="checkbox" 
                        checked={newTenantForm.loginEnabled} 
                        onChange={(e) => setNewTenantForm({ ...newTenantForm, loginEnabled: e.target.checked })} 
                      />
                      Enable Tenant Login
                    </label>

                    <label style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.85rem', fontWeight: 'bold' }}>
                      <input 
                        type="checkbox" 
                        checked={newTenantForm.editCredentials} 
                        onChange={(e) => setNewTenantForm({ ...newTenantForm, editCredentials: e.target.checked })} 
                      />
                      Customise Credentials
                    </label>
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                    <div className="form-group">
                      <label>Tenant User ID</label>
                      <input 
                        type="text" 
                        className="input-field" 
                        value={newTenantForm.tenantLoginId} 
                        onChange={(e) => setNewTenantForm({ ...newTenantForm, tenantLoginId: e.target.value.toUpperCase() })} 
                        disabled={!newTenantForm.editCredentials || !newTenantForm.loginEnabled}
                        placeholder="TENANT-101"
                      />
                    </div>
                    <div className="form-group">
                      <label>Temporary Password</label>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <input 
                          type="text" 
                          className="input-field" 
                          value={newTenantForm.tempPassword} 
                          onChange={(e) => setNewTenantForm({ ...newTenantForm, tempPassword: e.target.value })} 
                          disabled={!newTenantForm.editCredentials || !newTenantForm.loginEnabled}
                          placeholder="Password"
                        />
                        <button 
                          type="button" 
                          className="dev-btn" 
                          style={{ padding: '8px' }}
                          disabled={!newTenantForm.loginEnabled}
                          onClick={() => setNewTenantForm({ 
                            ...newTenantForm, 
                            tempPassword: 'Temp@' + Math.floor(100000 + Math.random() * 900000) 
                          })}
                        >
                          Generate
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* STEP 4: Document uploads */}
            {tenantWizardStep === 4 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <h3>Section 4: Upload Verification Documents</h3>
                <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>Simulating upload system. These documents are verified by the landlord instantly.</p>
                <div className="form-group" style={{ border: '2px dashed var(--border-color)', padding: '16px', borderRadius: '12px', textAlign: 'center' }}>
                  <span>📂 Drag & Drop Aadhaar Card front & back images</span>
                  <input type="file" style={{ marginTop: '8px' }} />
                </div>
                <div className="form-group" style={{ border: '2px dashed var(--border-color)', padding: '16px', borderRadius: '12px', textAlign: 'center' }}>
                  <span>📂 Drag & Drop PAN Card image copy</span>
                  <input type="file" style={{ marginTop: '8px' }} />
                </div>
                <div className="form-group" style={{ border: '2px dashed var(--border-color)', padding: '16px', borderRadius: '12px', textAlign: 'center' }}>
                  <span>📂 Drag & Drop Rental Agreement PDF document</span>
                  <input type="file" style={{ marginTop: '8px' }} />
                </div>
              </div>
            )}

            <div className="wizard-actions">
              {tenantWizardStep > 1 ? (
                <button className="dev-btn" onClick={() => setTenantWizardStep(tenantWizardStep - 1)}>Back Step</button>
              ) : <div />}
              
              {tenantWizardStep < 4 ? (
                <button className="btn-primary" onClick={() => setTenantWizardStep(tenantWizardStep + 1)}>Next Step</button>
              ) : (
                <button className="btn-primary" onClick={handleCreateTenant}>Save Tenant Checked-In</button>
              )}
            </div>

          </div>
        </div>
      )}

      {/* MODAL: ADD PROPERTY */}
      {showAddProperty && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '400px' }}>
            <div className="modal-header">
              <h2>Add New Estate</h2>
              <button className="close-btn" onClick={() => setShowAddProperty(false)}><X size={20} /></button>
            </div>
            
            <form onSubmit={handleCreateProperty} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Property Name</label>
                <input type="text" className="input-field" placeholder="House C or Commercial Mall" value={newPropertyForm.name} onChange={(e) => setNewPropertyForm({ ...newPropertyForm, name: e.target.value })} required />
              </div>
              <div className="form-group">
                <label>Estate Type</label>
                <select className="input-field" value={newPropertyForm.type} onChange={(e) => setNewPropertyForm({ ...newPropertyForm, type: e.target.value })}>
                  <option value="Residential">Residential (Rooms/Flats)</option>
                  <option value="Commercial">Commercial (Shops/Complexes)</option>
                </select>
              </div>
              <div className="form-group">
                <label>Total Rooms/Units</label>
                <input type="number" className="input-field" placeholder="10" value={newPropertyForm.totalRooms} onChange={(e) => setNewPropertyForm({ ...newPropertyForm, totalRooms: e.target.value })} required />
              </div>
              <button type="submit" className="btn-primary">Add Estate</button>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: RECORD PAYMENT */}
      {showRecordPayment && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '450px' }}>
            <div className="modal-header">
              <h2>Log Ledger Receipt</h2>
              <button className="close-btn" onClick={() => setShowRecordPayment(false)}><X size={20} /></button>
            </div>
            
            <form onSubmit={handleRecordPayment} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Select Unpaid Bill Reference</label>
                <select 
                  className="input-field" 
                  value={paymentForm.billId} 
                  onChange={(e) => {
                    const bill = bills.find(b => b.id === e.target.value);
                    setPaymentForm({
                      ...paymentForm,
                      billId: e.target.value,
                      amount: bill ? bill.pendingAmount.toString() : ''
                    });
                  }}
                  required
                >
                  <option value="">-- Choose outstanding bill --</option>
                  {bills.filter(b => b.status !== 'Paid').map(b => (
                    <option key={b.id} value={b.id}>{b.tenantName} - {b.propertyName} Room {b.roomNumber} ({b.billingMonth} - Due ₹{b.pendingAmount})</option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label>Payment Amount Received (₹)</label>
                <input type="number" className="input-field" placeholder="3000" value={paymentForm.amount} onChange={(e) => setPaymentForm({ ...paymentForm, amount: e.target.value })} required />
              </div>

              <div className="form-group">
                <label>Payment Method</label>
                <select className="input-field" value={paymentForm.method} onChange={(e) => setPaymentForm({ ...paymentForm, method: e.target.value })}>
                  <option value="UPI">UPI (GPay/PhonePe/QR)</option>
                  <option value="Cash">Cash Handover</option>
                  <option value="Bank Transfer">Direct Bank IMPS/NEFT</option>
                  <option value="Card">Credit/Debit Card POS</option>
                </select>
              </div>

              <div className="form-group">
                <label>Receipt Note/Ref</label>
                <input type="text" className="input-field" placeholder="e.g. June partial rent cash" value={paymentForm.note} onChange={(e) => setPaymentForm({ ...paymentForm, note: e.target.value })} />
              </div>

              <button type="submit" className="btn-primary">Record Transaction</button>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: EDIT BILL OVERRIDE */}
      {showEditBillModal && selectedBill && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h2>Override Utility/Rent charges</h2>
              <button className="close-btn" onClick={() => setShowEditBillModal(false)}><X size={20} /></button>
            </div>
            
            <form onSubmit={handleUpdateBill} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                <div className="form-group">
                  <label>Base Rent (₹)</label>
                  <input type="number" className="input-field" value={editBillForm.rentAmount} onChange={(e) => setEditBillForm({ ...editBillForm, rentAmount: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Electricity Units Used</label>
                  <input type="number" className="input-field" value={editBillForm.electricityUnits} onChange={(e) => setEditBillForm({ ...editBillForm, electricityUnits: e.target.value })} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                <div className="form-group">
                  <label>Electric Rate per Unit (₹)</label>
                  <input type="number" className="input-field" value={editBillForm.electricityRate} onChange={(e) => setEditBillForm({ ...editBillForm, electricityRate: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Fixed Water Charges (₹)</label>
                  <input type="number" className="input-field" value={editBillForm.waterCharges} onChange={(e) => setEditBillForm({ ...editBillForm, waterCharges: e.target.value })} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                <div className="form-group">
                  <label>Late Fee Charged (₹)</label>
                  <input type="number" className="input-field" value={editBillForm.lateFee} onChange={(e) => setEditBillForm({ ...editBillForm, lateFee: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Discount/Concession (₹)</label>
                  <input type="number" className="input-field" value={editBillForm.discount} onChange={(e) => setEditBillForm({ ...editBillForm, discount: e.target.value })} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '14px' }}>
                <div className="form-group">
                  <label>Extra charges (₹)</label>
                  <input type="number" className="input-field" value={editBillForm.extraCharges} onChange={(e) => setEditBillForm({ ...editBillForm, extraCharges: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Extra Charge Reason</label>
                  <input type="text" className="input-field" value={editBillForm.extraChargesReason} onChange={(e) => setEditBillForm({ ...editBillForm, extraChargesReason: e.target.value })} />
                </div>
              </div>

              <button type="submit" className="btn-primary">Apply Invoice Edits</button>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: MOVE OUT SETTLEMENT POPUP */}
      {showMoveOutModal && selectedTenant && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '450px' }}>
            <div className="modal-header">
              <h2>Tenant Checked-Out Exit Settle</h2>
              <button className="close-btn" onClick={() => setShowMoveOutModal(false)}><X size={20} /></button>
            </div>
            
            <form onSubmit={handleMoveOutConfirm} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ background: 'var(--color-danger-light)', color: 'var(--color-danger)', padding: '12px', borderRadius: '12px', fontSize: '0.85rem', fontWeight: 600 }}>
                ⚠️ Settle accounts and archive tenant {selectedTenant.name}.
              </div>

              <div className="remember-me">
                <input 
                  type="checkbox" 
                  id="clear-dues-chk"
                  checked={moveOutForm.clearDues} 
                  onChange={(e) => setMoveOutForm({ ...moveOutForm, clearDues: e.target.checked })} 
                />
                <label htmlFor="clear-dues-chk">Clear all remaining outstanding dues (UPI/Cash)?</label>
              </div>

              <div className="remember-me">
                <input 
                  type="checkbox" 
                  id="refund-deposit-chk"
                  checked={moveOutForm.settleDeposit} 
                  onChange={(e) => setMoveOutForm({ ...moveOutForm, settleDeposit: e.target.checked })} 
                />
                <label htmlFor="refund-deposit-chk">Settle Refundable Security Deposit? (Held: ₹{selectedTenant.securityDeposit})</label>
              </div>

              {moveOutForm.settleDeposit && (
                <>
                  <div className="form-group">
                    <label>Refund amount to pay back (₹)</label>
                    <input 
                      type="number" 
                      className="input-field" 
                      placeholder="4000" 
                      value={moveOutForm.refundAmount}
                      onChange={(e) => setMoveOutForm({ ...moveOutForm, refundAmount: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label>Reason for deposit deduction (if any)</label>
                    <input 
                      type="text" 
                      className="input-field" 
                      placeholder="e.g. Wall painting damage repair" 
                      value={moveOutForm.refundDeductionReason}
                      onChange={(e) => setMoveOutForm({ ...moveOutForm, refundDeductionReason: e.target.value })}
                    />
                  </div>
                </>
              )}

              <button type="submit" className="btn-primary" style={{ background: 'var(--color-danger)' }}>
                Move Tenant to Archive
              </button>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}

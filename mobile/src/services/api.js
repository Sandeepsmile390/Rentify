import axios from 'axios';
import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';

// Secure storage helpers that automatically fall back to AsyncStorage on Web
export const getSecureItem = async (key) => {
  if (Platform.OS === 'web') {
    return AsyncStorage.getItem(key);
  }
  try {
    return await SecureStore.getItemAsync(key);
  } catch (e) {
    return AsyncStorage.getItem(key);
  }
};

export const setSecureItem = async (key, value) => {
  if (Platform.OS === 'web') {
    return AsyncStorage.setItem(key, value);
  }
  try {
    await SecureStore.setItemAsync(key, value);
  } catch (e) {
    await AsyncStorage.setItem(key, value);
  }
};

export const deleteSecureItem = async (key) => {
  if (Platform.OS === 'web') {
    return AsyncStorage.removeItem(key);
  }
  try {
    await SecureStore.deleteItemAsync(key);
  } catch (e) {
    await AsyncStorage.removeItem(key);
  }
};

// API base URL — reads from mobile/.env (EXPO_PUBLIC_API_URL) with fallback for local dev.
// For physical device testing: change the IP in .env to your machine's LAN IP (e.g. 192.168.1.x)
const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:5000/api';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor to inject stored tokens into headers
api.interceptors.request.use(
  async (config) => {
    try {
      const accessToken = await getSecureItem('accessToken');
      const refreshToken = await getSecureItem('refreshToken');
      
      if (accessToken) {
        config.headers.Authorization = `Bearer ${accessToken}`;
      }
      if (refreshToken) {
        config.headers['x-refresh-token'] = refreshToken;
      }
    } catch (e) {
      console.warn('Failed to retrieve security tokens:', e);
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Interceptor to store tokens returned in auth responses
api.interceptors.response.use(
  async (response) => {
    // If the API call succeeded and returned tokens (e.g. on login or refresh), save them
    if (response.data && response.data.success) {
      // NOTE: Axios calls don't return set-cookie headers to SecureStore automatically,
      // but in React Native the login response contains tokens or we can parse them.
      // If server returns access/refresh token in the body for mobile clients:
      if (response.data.accessToken) {
        await setSecureItem('accessToken', response.data.accessToken);
      }
      if (response.data.refreshToken) {
        await setSecureItem('refreshToken', response.data.refreshToken);
      }
    }
    return response;
  },
  async (error) => {
    // Handle token expiration / session invalidation
    if (error.response && (error.response.status === 401 || error.response.status === 403)) {
      // Clear token store
      await deleteSecureItem('accessToken');
      await deleteSecureItem('refreshToken');
    }
    return Promise.reject(error);
  }
);

export const authService = {
  // Owner login (email/phone + password)
  login: async (credentials) => {
    // credentials: { email, phone, password, role: 'owner' }
    const response = await api.post('/auth/login', credentials);
    const data = response.data;
    if (data.success && data.user) {
      // If headers cookies aren't set in React Native, we extract tokens from body
      // We make sure server returns tokens in body, which server.js does on success
    }
    return data;
  },

  // Tenant login (tenantLoginId + password)
  tenantLogin: async (tenantLoginId, password, rememberMe) => {
    const response = await api.post('/auth/tenant-login', { tenantLoginId, password, rememberMe });
    return response.data;
  },

  // Forced password change on first login
  changePasswordFirst: async (oldPassword, newPassword) => {
    const response = await api.post('/auth/change-password-first', { oldPassword, newPassword });
    return response.data;
  },

  // Change password for logged in session
  changePassword: async (oldPassword, newPassword) => {
    const response = await api.post('/auth/change-password', { oldPassword, newPassword });
    return response.data;
  },

  // Revoke session list
  getSessions: async () => {
    const response = await api.get('/auth/sessions');
    return response.data;
  },

  // Log out a specific session by ID
  logoutSession: async (sessionId) => {
    const response = await api.delete(`/auth/sessions/${sessionId}`);
    return response.data;
  },

  // Logout from all devices
  logoutAllSessions: async () => {
    const response = await api.post('/auth/logout-all');
    // Clear local storage
    await deleteSecureItem('accessToken');
    await deleteSecureItem('refreshToken');
    return response.data;
  },

  // Logout current session
  logout: async () => {
    const response = await api.post('/auth/logout');
    await deleteSecureItem('accessToken');
    await deleteSecureItem('refreshToken');
    return response.data;
  },

  // Get current user profile
  getProfile: async () => {
    const response = await api.get('/auth/me');
    return response.data;
  }
};

export const billService = {
  getBills: async () => {
    const response = await api.get('/bills');
    return response.data;
  },
  payBill: async (billId, amount, method, note) => {
    const response = await api.post('/payments', { billId, amount, method, note });
    return response.data;
  },
  generateMonthlyBills: async (billingMonth) => {
    const response = await api.post('/bills/generate-monthly', { billingMonth });
    return response.data;
  }
};

export const propertyService = {
  getProperties: async () => {
    const response = await api.get('/properties');
    return response.data;
  },
  createProperty: async (propertyData) => {
    const response = await api.post('/properties', propertyData);
    return response.data;
  },
  createRoom: async (propertyId, roomData) => {
    const response = await api.post(`/properties/${propertyId}/rooms`, roomData);
    return response.data;
  },
  updateProperty: async (propertyId, propertyData) => {
    const response = await api.patch(`/properties/${propertyId}`, propertyData);
    return response.data;
  }
};

export const tenantService = {
  getTenants: async () => {
    const response = await api.get('/tenants');
    return response.data;
  },
  createTenant: async (tenantData) => {
    const response = await api.post('/tenants', tenantData);
    return response.data;
  },
  uploadDocument: async (tenantId, docKey, fileUri, fileName = 'upload.jpg', fileType = 'image/jpeg') => {
    const formData = new FormData();
    formData.append('document', {
      uri: fileUri,
      name: fileName,
      type: fileType
    });
    formData.append('docKey', docKey);
    const response = await api.post(`/documents/upload?tenantId=${tenantId}`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    });
    return response.data;
  },
  updateTenant: async (tenantId, tenantData) => {
    const response = await api.patch(`/tenants/${tenantId}`, tenantData);
    return response.data;
  }
};


export const chatService = {
  getChats: async () => {
    const response = await api.get('/chats');
    return response.data;
  },
  sendMessage: async (tenantId, sender, text, attachment, attachmentType) => {
    const response = await api.post('/chats/message', { tenantId, sender, text, attachment, attachmentType });
    return response.data;
  },
  markSeen: async (tenantId, sender) => {
    const response = await api.post(`/chats/${tenantId}/seen`, { sender });
    return response.data;
  }
};

export const commentService = {
  getComments: async () => {
    const response = await api.get('/comments');
    return response.data;
  },
  createTicket: async (tenantId, title, category, message) => {
    const response = await api.post('/comments', { tenantId, title, category, message });
    return response.data;
  },
  replyToTicket: async (ticketId, sender, message, name) => {
    const response = await api.post(`/comments/${ticketId}/reply`, { sender, message, name });
    return response.data;
  }
};

export const notificationService = {
  getNotifications: async () => {
    const response = await api.get('/notifications');
    return response.data;
  },
  markAllRead: async () => {
    const response = await api.post('/notifications/mark-all-read');
    return response.data;
  }
};

export default api;

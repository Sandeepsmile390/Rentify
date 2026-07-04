import React, { useState, useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { getSecureItem, deleteSecureItem } from './src/services/api';

// Tenant Screens
import TenantHomeScreen from './src/screens/tenant/HomeScreen';
import TenantBillsScreen from './src/screens/tenant/BillsScreen';
import TenantChatScreen from './src/screens/tenant/ChatScreen';
import TenantProfileScreen from './src/screens/tenant/ProfileScreen';
import DocumentUploadScreen from './src/screens/tenant/DocumentUploadScreen';

// Owner Screens
import OwnerDashboardScreen from './src/screens/owner/DashboardScreen';
import OwnerPropertiesScreen from './src/screens/owner/PropertiesScreen';
import OwnerTenantsScreen from './src/screens/owner/TenantsScreen';
import OwnerTenantDetailScreen from './src/screens/owner/TenantDetailScreen';
import OwnerChatsScreen from './src/screens/owner/ChatsScreen';
import OwnerChatConversationScreen from './src/screens/owner/ChatConversationScreen';
import OwnerProfileScreen from './src/screens/owner/ProfileScreen';

// Auth & Security Screens
import RoleSelectScreen from './src/screens/auth/RoleSelectScreen';
import OwnerLoginScreen from './src/screens/auth/OwnerLoginScreen';
import TenantLoginScreen from './src/screens/auth/TenantLoginScreen';
import FirstLoginScreen from './src/screens/auth/FirstLoginScreen';
import BiometricScreen from './src/screens/auth/BiometricScreen';
import AppLockScreen from './src/screens/auth/AppLockScreen';
import ActiveSessionsScreen from './src/screens/ActiveSessionsScreen';
import AppLockSettingsScreen from './src/screens/AppLockSettingsScreen';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

// Tenant Tab Layout
function TenantTabs({ route }) {
  const { onLogout } = route.params || {};

  return (
    <Tab.Navigator
      screenOptions={{
        tabBarActiveTintColor: '#4F46E5',
        tabBarInactiveTintColor: '#94A3B8',
        tabBarStyle: {
          backgroundColor: '#FFFFFF',
          borderTopWidth: 1,
          borderTopColor: '#E2E8F0',
          height: 60,
          paddingBottom: 8,
          paddingTop: 8,
        },
        headerStyle: {
          backgroundColor: '#FFFFFF',
          shadowColor: '#000',
          shadowOffset: { width: 0, height: 2 },
          shadowOpacity: 0.05,
          shadowRadius: 10,
          elevation: 2,
        },
        headerTitleStyle: {
          fontWeight: 'bold',
          color: '#0F172A',
        },
      }}
    >
      <Tab.Screen 
        name="HomeTab" 
        component={TenantHomeScreen} 
        options={{ title: 'Rentify Portal' }}
      />
      <Tab.Screen 
        name="BillsTab" 
        component={TenantBillsScreen} 
        options={{ title: 'My Bills' }}
      />
      <Tab.Screen 
        name="ChatTab" 
        component={TenantChatScreen} 
        options={{ title: 'Owner Chat' }}
      />
      <Tab.Screen 
        name="ProfileTab" 
        component={TenantProfileScreen} 
        options={{ title: 'My Profile' }}
        initialParams={{ onLogout }}
      />
    </Tab.Navigator>
  );
}

// Owner Tab Layout
function OwnerTabs({ route }) {
  const { onLogout } = route.params || {};

  return (
    <Tab.Navigator
      screenOptions={{
        tabBarActiveTintColor: '#4F46E5',
        tabBarInactiveTintColor: '#94A3B8',
        tabBarStyle: {
          backgroundColor: '#FFFFFF',
          borderTopWidth: 1,
          borderTopColor: '#E2E8F0',
          height: 60,
          paddingBottom: 8,
          paddingTop: 8,
        },
        headerStyle: {
          backgroundColor: '#FFFFFF',
          shadowColor: '#000',
          shadowOffset: { width: 0, height: 2 },
          shadowOpacity: 0.05,
          shadowRadius: 10,
          elevation: 2,
        },
        headerTitleStyle: {
          fontWeight: 'bold',
          color: '#0F172A',
        },
      }}
    >
      <Tab.Screen 
        name="DashboardTab" 
        component={OwnerDashboardScreen} 
        options={{ title: 'Rentify Owner' }}
      />
      <Tab.Screen 
        name="Properties" 
        component={OwnerPropertiesScreen} 
        options={{ title: 'Properties' }}
      />
      <Tab.Screen 
        name="Tenants" 
        component={OwnerTenantsScreen} 
        options={{ title: 'Tenants' }}
      />
      <Tab.Screen 
        name="Chats" 
        component={OwnerChatsScreen} 
        options={{ title: 'Messages' }}
      />
      <Tab.Screen 
        name="ProfileTab" 
        component={OwnerProfileScreen} 
        options={{ title: 'Profile' }}
        initialParams={{ onLogout }}
      />
    </Tab.Navigator>
  );
}

export default function App() {
  const [appReady, setAppReady] = useState(false);
  const [isLogged, setIsLogged] = useState(false);
  const [isLocked, setIsLocked] = useState(false);
  const [role, setRole] = useState('tenant');

  useEffect(() => {
    bootstrapApp();
  }, []);

  const bootstrapApp = async () => {
    try {
      // Check auth token
      const token = await getSecureItem('accessToken');
      const savedRole = await AsyncStorage.getItem('last_selected_role');
      
      if (token) {
        setIsLogged(true);
        if (savedRole) setRole(savedRole);

        // Check if PIN passcode lock is enabled
        const pinEnabled = await AsyncStorage.getItem('app_lock_pin_enabled');
        if (pinEnabled === 'true') {
          setIsLocked(true);
        }
      }
    } catch (e) {
      console.warn('Failed to bootstrap app security state:', e);
    } finally {
      setAppReady(true);
    }
  };

  const handleLoginSuccess = async (userRole) => {
    setRole(userRole);
    setIsLogged(true);
    // If PIN is enabled, lock app immediately on login
    const pinEnabled = await AsyncStorage.getItem('app_lock_pin_enabled');
    setIsLocked(pinEnabled === 'true');
  };

  const handleUnlockSuccess = () => {
    setIsLocked(false);
  };

  const handleLogout = async () => {
    await deleteSecureItem('accessToken');
    await deleteSecureItem('refreshToken');
    setIsLogged(false);
    setIsLocked(false);
  };

  if (!appReady) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#4F46E5" />
        <Text style={styles.loadingText}>Initializing Rentify Core...</Text>
      </View>
    );
  }

  return (
    <NavigationContainer>
      <StatusBar style="auto" />
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {/* State 1: Logged Out (Auth Stack) */}
        {!isLogged && (
          <>
            <Stack.Screen name="RoleSelect">
              {(props) => (
                <RoleSelectScreen 
                  {...props} 
                  onLoginSuccess={handleLoginSuccess} 
                />
              )}
            </Stack.Screen>
            <Stack.Screen name="OwnerLogin">
              {(props) => (
                <OwnerLoginScreen 
                  {...props} 
                  onLoginSuccess={handleLoginSuccess} 
                />
              )}
            </Stack.Screen>
            <Stack.Screen name="TenantLogin">
              {(props) => (
                <TenantLoginScreen 
                  {...props} 
                  onLoginSuccess={handleLoginSuccess} 
                />
              )}
            </Stack.Screen>
            <Stack.Screen name="FirstLogin" component={FirstLoginScreen} />
          </>
        )}

        {/* State 2: Logged In & App Lock is Active (Lock Stack) */}
        {isLogged && isLocked && (
          <>
            <Stack.Screen name="Biometric">
              {(props) => (
                <BiometricScreen 
                  {...props} 
                  onUnlockSuccess={handleUnlockSuccess}
                  onLogout={handleLogout}
                />
              )}
            </Stack.Screen>
            <Stack.Screen name="AppLock">
              {(props) => (
                <AppLockScreen 
                  {...props} 
                  onUnlockSuccess={handleUnlockSuccess}
                />
              )}
            </Stack.Screen>
          </>
        )}

        {/* State 3: Logged In & Unlocked (Main Stack & Tab Subviews) */}
        {isLogged && !isLocked && (
          <>
            {role === 'owner' ? (
              <Stack.Screen 
                name="MainTabs" 
                component={OwnerTabs} 
                initialParams={{ onLogout: handleLogout }}
              />
            ) : (
              <Stack.Screen 
                name="MainTabs" 
                component={TenantTabs} 
                initialParams={{ onLogout: handleLogout }}
              />
            )}
            
            {/* Common sub-screens */}
            <Stack.Screen 
              name="ActiveSessions" 
              component={ActiveSessionsScreen} 
              options={{ headerShown: true, title: 'Device Sessions' }}
            />
            <Stack.Screen 
              name="AppLockSettings" 
              component={AppLockSettingsScreen} 
              options={{ headerShown: true, title: 'Security Settings' }}
            />

            {/* Tenant specific sub-screens */}
            <Stack.Screen 
              name="DocumentUpload" 
              component={DocumentUploadScreen} 
              options={{ headerShown: false }}
            />

            {/* Landlord specific sub-screens */}
            <Stack.Screen 
              name="TenantDetail" 
              component={OwnerTenantDetailScreen} 
              options={{ headerShown: false }}
            />
            <Stack.Screen 
              name="ChatConversation" 
              component={OwnerChatConversationScreen} 
              options={{ headerShown: false }}
            />
          </>
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F8FAFC',
    gap: 16,
  },
  loadingText: {
    color: '#64748B',
    fontSize: 14,
    fontWeight: '600',
  }
});

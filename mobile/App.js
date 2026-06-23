import React, { useState, useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import * as SecureStore from 'expo-secure-store';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Screens
import HomeScreen from './src/screens/HomeScreen';
import BillsScreen from './src/screens/BillsScreen';
import ChatScreen from './src/screens/ChatScreen';
import ProfileScreen from './src/screens/ProfileScreen';

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

// Bottom Tab Navigation for logged-in & unlocked app
function MainTabs({ navigation, route }) {
  const { onLogout } = route.params || {};

  return (
    <Tab.Navigator
      screenOptions={{
        tabBarActiveTintColor: '#4F46E5', // Indigo accent
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
        component={HomeScreen} 
        options={{ title: 'RentFlow Portal' }}
      />
      <Tab.Screen 
        name="BillsTab" 
        component={BillsScreen} 
        options={{ title: 'My Bills' }}
      />
      <Tab.Screen 
        name="ChatTab" 
        component={ChatScreen} 
        options={{ title: 'Owner Chat' }}
      />
      <Tab.Screen 
        name="ProfileTab" 
        component={ProfileScreen} 
        options={{ title: 'My Profile' }}
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
      const token = await SecureStore.getItemAsync('accessToken');
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
    await SecureStore.deleteItemAsync('accessToken');
    await SecureStore.deleteItemAsync('refreshToken');
    setIsLogged(false);
    setIsLocked(false);
  };

  if (!appReady) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#4F46E5" />
        <Text style={styles.loadingText}>Initializing RentFlow Core...</Text>
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
            <Stack.Screen 
              name="MainTabs" 
              component={MainTabs} 
              initialParams={{ onLogout: handleLogout }}
            />
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

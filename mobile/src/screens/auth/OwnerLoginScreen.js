import React, { useState, useEffect } from 'react';
import { 
  StyleSheet, Text, View, TextInput, TouchableOpacity, 
  ActivityIndicator, Alert, SafeAreaView, KeyboardAvoidingView, 
  Platform, ScrollView
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as LocalAuthentication from 'expo-local-authentication';
import { authService } from '../../services/api';

export default function OwnerLoginScreen({ navigation, route }) {
  const [loginInput, setLoginInput] = useState('');
  const [password, setPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(true);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [hasBiometrics, setHasBiometrics] = useState(false);

  useEffect(() => {
    checkBiometricHardware();
  }, []);

  const checkBiometricHardware = async () => {
    try {
      const compatible = await LocalAuthentication.hasHardwareAsync();
      const enrolled = await LocalAuthentication.isEnrolledAsync();
      const biometricEnabled = await AsyncStorage.getItem('biometrics_owner_enabled');
      
      if (compatible && enrolled && biometricEnabled === 'true') {
        setHasBiometrics(true);
        // Automatically trigger biometric unlock
        triggerBiometricAuth();
      }
    } catch (e) {
      console.warn(e);
    }
  };

  const triggerBiometricAuth = async () => {
    try {
      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Unlock RentFlow Landlord Dashboard',
        cancelLabel: 'Use Password',
        disableDeviceFallback: false,
      });

      if (result.success) {
        // Log in automatically if tokens exist, or navigate. 
        // For security demonstration, we read saved credentials or session token.
        const storedToken = await AsyncStorage.getItem('accessToken');
        if (storedToken) {
          // Verify profile or simply log in
          Alert.alert('Unlocked', 'Welcome back to RentFlow!', [
            { text: 'Enter Dashboard', onPress: () => route.params?.onLoginSuccess('owner') }
          ]);
        } else {
          Alert.alert('Authentication Failed', 'Please input your password once to renew session.');
        }
      }
    } catch (e) {
      console.warn(e);
    }
  };

  const handleLogin = async () => {
    if (!loginInput.trim() || !password) {
      Alert.alert('Missing Fields', 'Please enter both credentials.');
      return;
    }

    setLoading(true);
    try {
      const credentials = {
        role: 'owner',
        password,
        rememberMe,
      };

      if (loginInput.includes('@')) {
        credentials.email = loginInput.trim();
      } else {
        credentials.phone = loginInput.trim();
      }

      const res = await authService.login(credentials);
      
      if (res.success) {
        // If Remember Me is checked, we can offer to enable biometric unlock for next time
        const bioSetup = await AsyncStorage.getItem('biometrics_owner_setup_prompt');
        if (!bioSetup && !hasBiometrics) {
          Alert.alert(
            'Enable Biometrics',
            'Would you like to unlock your Landlord Dashboard with Touch ID/Face ID next time?',
            [
              { 
                text: 'Yes, Enable', 
                onPress: async () => {
                  await AsyncStorage.setItem('biometrics_owner_enabled', 'true');
                  await AsyncStorage.setItem('biometrics_owner_setup_prompt', 'true');
                  route.params?.onLoginSuccess('owner');
                } 
              },
              { 
                text: 'Maybe Later', 
                onPress: async () => {
                  await AsyncStorage.setItem('biometrics_owner_setup_prompt', 'true');
                  route.params?.onLoginSuccess('owner');
                }
              }
            ]
          );
        } else {
          route.params?.onLoginSuccess('owner');
        }
      } else {
        Alert.alert('Authentication Failed', 'Invalid email/phone or password.');
      }
    } catch (e) {
      Alert.alert('Login Error', e.response?.data?.message || 'Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={{ flex: 1 }}
      >
        <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
          
          <TouchableOpacity style={styles.backButton} onPress={() => navigation.goBack()}>
            <Text style={styles.backButtonText}>← BACK</Text>
          </TouchableOpacity>

          <View style={styles.header}>
            <Text style={styles.title}>Landlord Portal</Text>
            <Text style={styles.subtitle}>Log in to manage properties & tenants</Text>
          </View>

          <View style={styles.form}>
            <Text style={styles.label}>Email Address or Phone Number</Text>
            <TextInput
              style={styles.input}
              placeholder="e.g. admin@rentify.com"
              placeholderTextColor="#94A3B8"
              value={loginInput}
              onChangeText={setLoginInput}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
              editable={!loading}
            />

            <Text style={styles.label}>Security Password</Text>
            <View style={styles.passwordWrapper}>
              <TextInput
                style={styles.passwordInput}
                placeholder="Enter password"
                placeholderTextColor="#94A3B8"
                value={password}
                onChangeText={setPassword}
                secureTextEntry={!showPassword}
                autoCapitalize="none"
                autoCorrect={false}
                editable={!loading}
              />
              <TouchableOpacity 
                style={styles.eyeBtn} 
                onPress={() => setShowPassword(!showPassword)}
              >
                <Text style={styles.eyeText}>{showPassword ? 'HIDE' : 'SHOW'}</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.row}>
              <TouchableOpacity 
                style={styles.checkboxRow}
                onPress={() => setRememberMe(!rememberMe)}
              >
                <View style={[styles.checkbox, rememberMe && styles.checkboxChecked]}>
                  {rememberMe && <Text style={styles.checkMark}>✓</Text>}
                </View>
                <Text style={styles.checkboxLabel}>Remember Me</Text>
              </TouchableOpacity>

              <TouchableOpacity 
                onPress={() => Alert.alert('Password Reset', 'Landlord accounts can only be reset by coordinating with the server administrator.')}
              >
                <Text style={styles.forgotText}>Forgot Password?</Text>
              </TouchableOpacity>
            </View>

            <TouchableOpacity 
              style={[styles.loginBtn, loading && styles.loginBtnDisabled]}
              onPress={handleLogin}
              disabled={loading}
            >
              {loading ? (
                <ActivityIndicator color="#FFFFFF" />
              ) : (
                <Text style={styles.loginBtnText}>Secure Sign In</Text>
              )}
            </TouchableOpacity>

            {hasBiometrics && (
              <TouchableOpacity style={styles.biometricBtn} onPress={triggerBiometricAuth}>
                <Text style={styles.biometricBtnIcon}>👆</Text>
                <Text style={styles.biometricBtnText}>Authenticate with Biometrics</Text>
              </TouchableOpacity>
            )}
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  scrollContainer: {
    flexGrow: 1,
    paddingHorizontal: 24,
    paddingBottom: 40,
    justifyContent: 'center',
  },
  backButton: {
    alignSelf: 'flex-start',
    paddingVertical: 12,
    marginBottom: 20,
  },
  backButtonText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#64748B',
    letterSpacing: 0.5,
  },
  header: {
    marginBottom: 32,
  },
  title: {
    fontSize: 28,
    fontWeight: '800',
    color: '#0F172A',
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 14,
    color: '#64748B',
  },
  form: {
    width: '100%',
  },
  label: {
    fontSize: 13,
    fontWeight: '600',
    color: '#475569',
    marginBottom: 8,
  },
  input: {
    height: 52,
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 12,
    paddingHorizontal: 16,
    fontSize: 15,
    color: '#0F172A',
    backgroundColor: '#FFFFFF',
    marginBottom: 20,
  },
  passwordWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 52,
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
    marginBottom: 20,
  },
  passwordInput: {
    flex: 1,
    height: '100%',
    paddingHorizontal: 16,
    fontSize: 15,
    color: '#0F172A',
  },
  eyeBtn: {
    paddingHorizontal: 16,
    height: '100%',
    justifyContent: 'center',
  },
  eyeText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#4F46E5',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 28,
  },
  checkboxRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    width: 20,
    height: 20,
    borderWidth: 1.5,
    borderColor: '#CBD5E1',
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
    backgroundColor: '#FFFFFF',
  },
  checkboxChecked: {
    backgroundColor: '#4F46E5',
    borderColor: '#4F46E5',
  },
  checkMark: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: 'bold',
  },
  checkboxLabel: {
    fontSize: 13,
    color: '#475569',
    fontWeight: '500',
  },
  forgotText: {
    fontSize: 13,
    color: '#4F46E5',
    fontWeight: '600',
  },
  loginBtn: {
    height: 54,
    backgroundColor: '#4F46E5',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#4F46E5',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 3,
    marginBottom: 16,
  },
  loginBtnDisabled: {
    opacity: 0.75,
  },
  loginBtnText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '700',
  },
  biometricBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 54,
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
    gap: 8,
  },
  biometricBtnIcon: {
    fontSize: 20,
  },
  biometricBtnText: {
    fontSize: 14,
    color: '#475569',
    fontWeight: '600',
  }
});

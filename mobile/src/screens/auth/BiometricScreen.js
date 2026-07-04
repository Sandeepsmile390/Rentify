import React, { useEffect, useRef } from 'react';
import { StyleSheet, Text, View, Image, TouchableOpacity, Animated, Alert } from 'react-native';
import * as LocalAuthentication from 'expo-local-authentication';
import AsyncStorage from '@react-native-async-storage/async-storage';

export default function BiometricScreen({ navigation, route }) {
  const { onUnlockSuccess } = route.params;
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    // Run biometric prompt automatically
    triggerBiometrics();

    // Pulse animation for fingerprint icon
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.15,
          duration: 1000,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 1000,
          useNativeDriver: true,
        })
      ])
    ).start();
  }, []);

  const triggerBiometrics = async () => {
    try {
      const compatible = await LocalAuthentication.hasHardwareAsync();
      const enrolled = await LocalAuthentication.isEnrolledAsync();

      if (!compatible || !enrolled) {
        Alert.alert('Unsupported', 'Biometric hardware is not configured on this device. Redirecting to passcode.', [
          { text: 'OK', onPress: () => navigation.navigate('AppLock') }
        ]);
        return;
      }

      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Unlock Rentify Portal',
        fallbackLabel: 'Use PIN passcode',
        disableDeviceFallback: false
      });

      if (result.success) {
        onUnlockSuccess();
      }
    } catch (e) {
      console.warn(e);
    }
  };

  const handleUsePasscode = () => {
    navigation.navigate('AppLock');
  };

  const handleSwitchAccount = async () => {
    // Revoke login
    await AsyncStorage.removeItem('accessToken');
    await AsyncStorage.removeItem('refreshToken');
    route.params?.onLogout();
  };

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.welcomeText}>Welcome Back</Text>
        
        <View style={styles.avatarContainer}>
          <Image 
            source={{ uri: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150' }}
            style={styles.avatar}
          />
          <View style={styles.onlineDot} />
        </View>

        <Text style={styles.userName}>Resident</Text>
        <Text style={styles.userRole}>Verified User</Text>

        <Animated.View style={[styles.fingerprintWrapper, { transform: [{ scale: pulseAnim }] }]}>
          <TouchableOpacity style={styles.fingerprintBtn} onPress={triggerBiometrics}>
            <Text style={styles.fingerprintIcon}>👆</Text>
          </TouchableOpacity>
        </Animated.View>

        <Text style={styles.hintText}>Tap sensor to unlock Rentify</Text>
      </View>

      <View style={styles.footer}>
        <TouchableOpacity style={styles.secondaryBtn} onPress={handleUsePasscode}>
          <Text style={styles.secondaryBtnText}>Use App PIN Lock</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.switchBtn} onPress={handleSwitchAccount}>
          <Text style={styles.switchBtnText}>Switch Account / Log Out</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0F172A', // Premium dark mode background
    justifyContent: 'space-between',
    paddingHorizontal: 24,
    paddingVertical: 50,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  welcomeText: {
    fontSize: 16,
    color: '#94A3B8',
    fontWeight: '600',
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginBottom: 28,
  },
  avatarContainer: {
    position: 'relative',
    marginBottom: 16,
  },
  avatar: {
    width: 90,
    height: 90,
    borderRadius: 45,
    borderWidth: 3,
    borderColor: '#38BDF8',
  },
  onlineDot: {
    position: 'absolute',
    bottom: 4,
    right: 4,
    width: 16,
    height: 16,
    borderRadius: 8,
    backgroundColor: '#10B981',
    borderWidth: 3,
    borderColor: '#0F172A',
  },
  userName: {
    fontSize: 22,
    fontWeight: '800',
    color: '#F8FAFC',
    marginBottom: 4,
  },
  userRole: {
    fontSize: 13,
    color: '#38BDF8',
    fontWeight: '600',
    marginBottom: 60,
  },
  fingerprintWrapper: {
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 20,
  },
  fingerprintBtn: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: 'rgba(56, 189, 248, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#38BDF8',
  },
  fingerprintIcon: {
    fontSize: 36,
  },
  hintText: {
    fontSize: 14,
    color: '#64748B',
    fontWeight: '500',
  },
  footer: {
    gap: 16,
    alignItems: 'center',
  },
  secondaryBtn: {
    width: '100%',
    height: 52,
    borderWidth: 1.5,
    borderColor: '#334155',
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  secondaryBtnText: {
    color: '#F8FAFC',
    fontSize: 15,
    fontWeight: '700',
  },
  switchBtn: {
    paddingVertical: 8,
  },
  switchBtnText: {
    color: '#EF4444',
    fontSize: 13,
    fontWeight: '700',
  }
});

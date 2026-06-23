import React, { useState, useEffect, useRef } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, Animated, Alert } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as LocalAuthentication from 'expo-local-authentication';

export default function AppLockScreen({ navigation, route }) {
  const { onUnlockSuccess } = route.params;
  const [pin, setPin] = useState('');
  const [hasBiometrics, setHasBiometrics] = useState(false);
  const shakeAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    checkBiometrics();
  }, []);

  const checkBiometrics = async () => {
    try {
      const compatible = await LocalAuthentication.hasHardwareAsync();
      const enrolled = await LocalAuthentication.isEnrolledAsync();
      const enabled = await AsyncStorage.getItem('biometrics_owner_enabled');
      if (compatible && enrolled && enabled === 'true') {
        setHasBiometrics(true);
      }
    } catch (e) {
      console.warn(e);
    }
  };

  const triggerBiometricUnlock = async () => {
    try {
      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Unlock RentFlow',
        cancelLabel: 'Use PIN',
      });
      if (result.success) {
        onUnlockSuccess();
      }
    } catch (e) {
      console.warn(e);
    }
  };

  const handleKeyPress = (num) => {
    if (pin.length >= 4) return;
    const newPin = pin + num;
    setPin(newPin);

    if (newPin.length === 4) {
      verifyPin(newPin);
    }
  };

  const handleBackspace = () => {
    if (pin.length === 0) return;
    setPin(pin.slice(0, -1));
  };

  const verifyPin = async (enteredPin) => {
    try {
      const savedPin = await AsyncStorage.getItem('app_lock_pin');
      const fallbackDefaultPin = '1234'; // Default demo PIN
      
      const targetPin = savedPin || fallbackDefaultPin;

      if (enteredPin === targetPin) {
        onUnlockSuccess();
      } else {
        // Trigger shake animation
        shake();
        setPin('');
      }
    } catch (e) {
      console.warn(e);
    }
  };

  const shake = () => {
    Animated.sequence([
      Animated.timing(shakeAnim, { toValue: 10, duration: 80, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -10, duration: 80, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 10, duration: 80, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 0, duration: 80, useNativeDriver: true })
    ]).start();
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Enter App PIN</Text>
        <Text style={styles.subtitle}>Enter your 4-digit passcode to unlock RentFlow</Text>
      </View>

      {/* Dots representation */}
      <Animated.View style={[styles.dotsRow, { transform: [{ translateX: shakeAnim }] }]}>
        <View style={[styles.dot, pin.length >= 1 && styles.dotFilled]} />
        <View style={[styles.dot, pin.length >= 2 && styles.dotFilled]} />
        <View style={[styles.dot, pin.length >= 3 && styles.dotFilled]} />
        <View style={[styles.dot, pin.length >= 4 && styles.dotFilled]} />
      </Animated.View>

      {/* Numerical Keypad */}
      <View style={styles.keypad}>
        <View style={styles.keypadRow}>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('1')}>
            <Text style={styles.keyText}>1</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('2')}>
            <Text style={styles.keyText}>2</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('3')}>
            <Text style={styles.keyText}>3</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.keypadRow}>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('4')}>
            <Text style={styles.keyText}>4</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('5')}>
            <Text style={styles.keyText}>5</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('6')}>
            <Text style={styles.keyText}>6</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.keypadRow}>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('7')}>
            <Text style={styles.keyText}>7</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('8')}>
            <Text style={styles.keyText}>8</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('9')}>
            <Text style={styles.keyText}>9</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.keypadRow}>
          {hasBiometrics ? (
            <TouchableOpacity style={styles.keyBtn} onPress={triggerBiometricUnlock}>
              <Text style={styles.fingerprintIcon}>👆</Text>
            </TouchableOpacity>
          ) : (
            <View style={styles.keyBtnEmpty} />
          )}

          <TouchableOpacity style={styles.keyBtn} onPress={() => handleKeyPress('0')}>
            <Text style={styles.keyText}>0</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.keyBtn} onPress={handleBackspace}>
            <Text style={styles.backspaceText}>⌫</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
    justifyContent: 'space-between',
    paddingHorizontal: 32,
    paddingVertical: 60,
  },
  header: {
    alignItems: 'center',
    marginTop: 40,
  },
  title: {
    fontSize: 24,
    fontWeight: '800',
    color: '#0F172A',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 13,
    color: '#64748B',
    textAlign: 'center',
  },
  dotsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 20,
    marginVertical: 40,
  },
  dot: {
    width: 16,
    height: 16,
    borderRadius: 8,
    borderWidth: 1.5,
    borderColor: '#CBD5E1',
    backgroundColor: 'transparent',
  },
  dotFilled: {
    backgroundColor: '#4F46E5',
    borderColor: '#4F46E5',
  },
  keypad: {
    width: '100%',
    gap: 16,
    marginBottom: 20,
  },
  keypadRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  keyBtn: {
    width: 76,
    height: 76,
    borderRadius: 38,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#0F172A',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.03,
    shadowRadius: 6,
    elevation: 1,
  },
  keyBtnEmpty: {
    width: 76,
    height: 76,
  },
  keyText: {
    fontSize: 26,
    fontWeight: '600',
    color: '#0F172A',
  },
  fingerprintIcon: {
    fontSize: 28,
  },
  backspaceText: {
    fontSize: 22,
    color: '#475569',
  }
});

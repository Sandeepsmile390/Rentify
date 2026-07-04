import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, Switch, TouchableOpacity, Alert, SafeAreaView, ScrollView, Modal, TextInput } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as LocalAuthentication from 'expo-local-authentication';

export default function AppLockSettingsScreen({ navigation }) {
  const [pinEnabled, setPinEnabled] = useState(false);
  const [biometricEnabled, setBiometricEnabled] = useState(false);
  const [hasBiometricHardware, setHasBiometricHardware] = useState(false);
  const [autoLockTime, setAutoLockTime] = useState('immediately'); // 'immediately' | '30s' | '1m' | '5m'
  const [showTimePicker, setShowTimePicker] = useState(false);

  // Platform-safe Modal state for PIN setup/deactivation
  const [modalVisible, setModalVisible] = useState(false);
  const [modalMode, setModalMode] = useState('set'); // 'set' | 'disable'
  const [pinInput, setPinInput] = useState('');

  useEffect(() => {
    loadSettings();
    checkBiometricHardware();
  }, []);

  const loadSettings = async () => {
    try {
      const pinActive = await AsyncStorage.getItem('app_lock_pin_enabled');
      const bioActive = await AsyncStorage.getItem('biometrics_owner_enabled');
      const lockTime = await AsyncStorage.getItem('app_lock_auto_time');

      setPinEnabled(pinActive === 'true');
      setBiometricEnabled(bioActive === 'true');
      if (lockTime) setAutoLockTime(lockTime);
    } catch (e) {
      console.warn(e);
    }
  };

  const checkBiometricHardware = async () => {
    try {
      const compatible = await LocalAuthentication.hasHardwareAsync();
      const enrolled = await LocalAuthentication.isEnrolledAsync();
      setHasBiometricHardware(compatible && enrolled);
    } catch (e) {
      console.warn(e);
    }
  };

  const handleTogglePin = async (value) => {
    if (value) {
      setModalMode('set');
      setPinInput('');
      setModalVisible(true);
    } else {
      setModalMode('disable');
      setPinInput('');
      setModalVisible(true);
    }
  };

  const handleModalSubmit = async () => {
    if (!pinInput || pinInput.length !== 4 || isNaN(pinInput)) {
      Alert.alert('Invalid PIN', 'Passcode must be exactly 4 numeric digits.');
      if (modalMode === 'set') {
        setPinEnabled(false);
      }
      setModalVisible(false);
      return;
    }

    if (modalMode === 'set') {
      try {
        await AsyncStorage.setItem('app_lock_pin', pinInput);
        await AsyncStorage.setItem('app_lock_pin_enabled', 'true');
        setPinEnabled(true);
        setModalVisible(false);
        Alert.alert('PIN Configured', 'App lock passcode configured successfully.');
      } catch (e) {
        Alert.alert('Error', 'Failed to configure PIN.');
        setPinEnabled(false);
        setModalVisible(false);
      }
    } else {
      const savedPin = await AsyncStorage.getItem('app_lock_pin');
      if (pinInput === savedPin) {
        try {
          await AsyncStorage.setItem('app_lock_pin_enabled', 'false');
          await AsyncStorage.removeItem('app_lock_pin');
          setPinEnabled(false);
          // Also disable biometrics if PIN is disabled
          await AsyncStorage.setItem('biometrics_owner_enabled', 'false');
          setBiometricEnabled(false);
          setModalVisible(false);
          Alert.alert('Passcode Disabled', 'App lock protection deactivated.');
        } catch (e) {
          console.warn(e);
          setModalVisible(false);
        }
      } else {
        setModalVisible(false);
        Alert.alert('Error', 'Incorrect PIN code. Protection stays active.');
        setPinEnabled(true);
      }
    }
  };

  const handleToggleBiometric = async (value) => {
    if (!pinEnabled) {
      Alert.alert('PIN Code Required', 'Please configure an App PIN lock passcode first before enabling Touch ID/Face ID.');
      setBiometricEnabled(false);
      return;
    }

    if (value) {
      // Prompt user to verify identity before enabling biometrics
      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Confirm identity to enable Biometric Unlock',
      });

      if (result.success) {
        try {
          await AsyncStorage.setItem('biometrics_owner_enabled', 'true');
          setBiometricEnabled(true);
        } catch (e) {
          console.warn(e);
        }
      } else {
        setBiometricEnabled(false);
      }
    } else {
      try {
        await AsyncStorage.setItem('biometrics_owner_enabled', 'false');
        setBiometricEnabled(false);
      } catch (e) {
        console.warn(e);
      }
    }
  };

  const handleSelectTime = async (time) => {
    try {
      await AsyncStorage.setItem('app_lock_auto_time', time);
      setAutoLockTime(time);
      setShowTimePicker(false);
    } catch (e) {
      console.warn(e);
    }
  };

  const timeOptions = [
    { label: 'Immediately', value: 'immediately' },
    { label: 'After 30 seconds', value: '30s' },
    { label: 'After 1 minute', value: '1m' },
    { label: 'After 5 minutes', value: '5m' },
    { label: 'After 10 minutes', value: '10m' }
  ];

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>App Lock Protection</Text>
          <Text style={styles.sectionSubtitle}>Add a security passcode and unlock shortcuts to protect details.</Text>

          <View style={styles.settingCard}>
            <View style={styles.settingInfo}>
              <Text style={styles.settingLabel}>Enable Passcode PIN Lock</Text>
              <Text style={styles.settingDesc}>Require a 4-digit code to open the Rentify application</Text>
            </View>
            <Switch
              value={pinEnabled}
              onValueChange={handleTogglePin}
              trackColor={{ false: '#E2E8F0', true: '#4F46E5' }}
              thumbColor={pinEnabled ? '#FFFFFF' : '#F1F5F9'}
            />
          </View>

          {hasBiometricHardware && (
            <View style={styles.settingCard}>
              <View style={styles.settingInfo}>
                <Text style={styles.settingLabel}>Biometric Unlock</Text>
                <Text style={styles.settingDesc}>Use Face ID / Touch ID / Fingerprint sensor to unlock</Text>
              </View>
              <Switch
                value={biometricEnabled}
                onValueChange={handleToggleBiometric}
                trackColor={{ false: '#E2E8F0', true: '#4F46E5' }}
                thumbColor={biometricEnabled ? '#FFFFFF' : '#F1F5F9'}
                disabled={!pinEnabled}
              />
            </View>
          )}
        </View>

        {pinEnabled && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Autolock Settings</Text>
            
            <TouchableOpacity 
              style={styles.dropdownCard}
              onPress={() => setShowTimePicker(!showTimePicker)}
            >
              <View>
                <Text style={styles.settingLabel}>Auto-Lock Timeout</Text>
                <Text style={styles.settingDesc}>Lock the application when idle or minimized</Text>
              </View>
              <Text style={styles.dropdownValue}>
                {timeOptions.find(o => o.value === autoLockTime)?.label} ▾
              </Text>
            </TouchableOpacity>

            {showTimePicker && (
              <View style={styles.optionsList}>
                {timeOptions.map((opt) => (
                  <TouchableOpacity 
                    key={opt.value} 
                    style={[styles.optionItem, autoLockTime === opt.value && styles.optionItemSelected]}
                    onPress={() => handleSelectTime(opt.value)}
                  >
                    <Text style={[styles.optionText, autoLockTime === opt.value && styles.optionTextSelected]}>
                      {opt.label}
                    </Text>
                    {autoLockTime === opt.value && <Text style={styles.optionCheck}>✓</Text>}
                  </TouchableOpacity>
                ))}
              </View>
            )}
          </View>
        )}

      </ScrollView>

      {/* Custom Modal for platform-safe PIN input */}
      <Modal
        animationType="fade"
        transparent={true}
        visible={modalVisible}
        onRequestClose={() => {
          setModalVisible(false);
          if (modalMode === 'set') setPinEnabled(false);
        }}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>
              {modalMode === 'set' ? 'Set App PIN Passcode' : 'Enter App PIN Passcode'}
            </Text>
            <Text style={styles.modalSubtitle}>
              {modalMode === 'set' 
                ? 'Enter a 4-digit code to protect your Rentify application:' 
                : 'Enter your current 4-digit code to disable PIN lock:'}
            </Text>
            
            <TextInput
              style={styles.modalInput}
              keyboardType="number-pad"
              maxLength={4}
              secureTextEntry={true}
              autoFocus={true}
              value={pinInput}
              onChangeText={setPinInput}
              placeholder="••••"
              placeholderTextColor="#94A3B8"
            />

            <View style={styles.modalActions}>
              <TouchableOpacity
                style={[styles.modalBtn, styles.modalCancelBtn]}
                onPress={() => {
                  setModalVisible(false);
                  if (modalMode === 'set') setPinEnabled(false);
                }}
              >
                <Text style={styles.modalCancelBtnText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.modalBtn, styles.modalSubmitBtn]}
                onPress={handleModalSubmit}
              >
                <Text style={styles.modalSubmitBtnText}>Submit</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  scrollContainer: {
    padding: 16,
  },
  section: {
    marginBottom: 28,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '800',
    color: '#64748B',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 6,
    paddingLeft: 4,
  },
  sectionSubtitle: {
    fontSize: 12,
    color: '#94A3B8',
    marginBottom: 16,
    paddingLeft: 4,
  },
  settingCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#FFFFFF',
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 16,
    padding: 20,
    marginBottom: 12,
    shadowColor: '#0F172A',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.02,
    shadowRadius: 8,
    elevation: 1,
  },
  settingInfo: {
    flex: 1,
    paddingRight: 16,
  },
  settingLabel: {
    fontSize: 15,
    fontWeight: '700',
    color: '#0F172A',
    marginBottom: 4,
  },
  settingDesc: {
    fontSize: 12,
    color: '#64748B',
    lineHeight: 16,
  },
  dropdownCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#FFFFFF',
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 16,
    padding: 20,
    shadowColor: '#0F172A',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.02,
    shadowRadius: 8,
    elevation: 1,
  },
  dropdownValue: {
    fontSize: 14,
    fontWeight: '700',
    color: '#4F46E5',
  },
  optionsList: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 16,
    marginTop: 8,
    overflow: 'hidden',
  },
  optionItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#F1F5F9',
  },
  optionItemSelected: {
    backgroundColor: '#EEF2FF',
  },
  optionText: {
    fontSize: 14,
    color: '#475569',
    fontWeight: '500',
  },
  optionTextSelected: {
    color: '#4F46E5',
    fontWeight: '700',
  },
  optionCheck: {
    color: '#4F46E5',
    fontSize: 14,
    fontWeight: 'bold',
  },
  /* Modal Styles */
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.4)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  modalContent: {
    width: '100%',
    maxWidth: 320,
    backgroundColor: '#FFFFFF',
    borderRadius: 24,
    padding: 24,
    alignItems: 'center',
    shadowColor: '#0F172A',
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.15,
    shadowRadius: 24,
    elevation: 8,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: '#0F172A',
    marginBottom: 8,
    textAlign: 'center',
  },
  modalSubtitle: {
    fontSize: 13,
    color: '#64748B',
    textAlign: 'center',
    lineHeight: 18,
    marginBottom: 20,
  },
  modalInput: {
    width: '100%',
    height: 52,
    backgroundColor: '#F8FAFC',
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    fontSize: 20,
    fontWeight: '700',
    color: '#0F172A',
    textAlign: 'center',
    letterSpacing: 8,
    marginBottom: 20,
  },
  modalActions: {
    flexDirection: 'row',
    gap: 12,
    width: '100%',
  },
  modalBtn: {
    flex: 1,
    height: 48,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalCancelBtn: {
    backgroundColor: '#F1F5F9',
  },
  modalCancelBtnText: {
    color: '#475569',
    fontWeight: '700',
    fontSize: 14,
  },
  modalSubmitBtn: {
    backgroundColor: '#4F46E5',
  },
  modalSubmitBtnText: {
    color: '#FFFFFF',
    fontWeight: '700',
    fontSize: 14,
  },
});

import React, { useState } from 'react';
import { 
  StyleSheet, Text, View, TextInput, TouchableOpacity, 
  ActivityIndicator, Alert, SafeAreaView, KeyboardAvoidingView, 
  Platform, ScrollView
} from 'react-native';
import { authService } from '../../services/api';

export default function FirstLoginScreen({ route, navigation }) {
  const { tempPassword, onLoginComplete } = route.params;
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);

  // Validate criteria
  const isLenValid = newPassword.length >= 8;
  const isUpperValid = /[A-Z]/.test(newPassword);
  const isLowerValid = /[a-z]/.test(newPassword);
  const isNumValid = /[0-9]/.test(newPassword);
  const isSpecialValid = /[^A-Za-z0-9]/.test(newPassword);
  const isMatchValid = newPassword.length > 0 && newPassword === confirmPassword;
  const isNotSameValid = newPassword.length > 0 && newPassword !== tempPassword;

  // Strength score
  const getStrengthScore = () => {
    let score = 0;
    if (!newPassword) return score;
    if (isLenValid) score += 1;
    if (isUpperValid) score += 1;
    if (isLowerValid) score += 1;
    if (isNumValid) score += 1;
    if (isSpecialValid) score += 1;
    return Math.min(score, 4); // Max 4
  };

  const strengthScore = getStrengthScore();

  const handlePasswordSetup = async () => {
    const valid = isLenValid && isUpperValid && isLowerValid && isNumValid && isSpecialValid && isMatchValid && isNotSameValid;
    if (!valid) {
      Alert.alert('Invalid Password', 'Please ensure all guidelines are satisfied.');
      return;
    }

    setLoading(true);
    try {
      const res = await authService.changePasswordFirst(tempPassword, newPassword);
      if (res.success) {
        Alert.alert(
          'Security Updated',
          'Your new security password is set up successfully. Welcome to Rentify!',
          [{ text: 'Proceed', onPress: () => onLoginComplete() }]
        );
      }
    } catch (e) {
      Alert.alert('Update Failed', e.response?.data?.message || 'Failed to update security credentials.');
    } finally {
      setLoading(false);
    }
  };

  const getStrengthLabel = () => {
    if (strengthScore === 0) return 'Very Weak';
    if (strengthScore === 1) return 'Weak';
    if (strengthScore === 2) return 'Fair';
    if (strengthScore === 3) return 'Strong';
    return 'Excellent';
  };

  const getStrengthColor = () => {
    if (strengthScore <= 1) return '#EF4444'; // Red
    if (strengthScore === 2) return '#F59E0B'; // Orange
    if (strengthScore === 3) return '#3B82F6'; // Blue
    return '#10B981'; // Green
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={{ flex: 1 }}
      >
        <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
          <View style={styles.header}>
            <Text style={styles.badgeText}>🛡️ SECURITY REQUIREMENT</Text>
            <Text style={styles.title}>Update Security Password</Text>
            <Text style={styles.subtitle}>You are logging in with a temporary password. Choose a new secure password to proceed.</Text>
          </View>

          <View style={styles.form}>
            <Text style={styles.label}>New Secure Password</Text>
            <View style={styles.passwordWrapper}>
              <TextInput
                style={styles.passwordInput}
                placeholder="Choose new password"
                placeholderTextColor="#94A3B8"
                value={newPassword}
                onChangeText={setNewPassword}
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

            {/* Strength indicator */}
            <View style={styles.strengthContainer}>
              <View style={styles.strengthBarRow}>
                <View style={[styles.strengthBar, { backgroundColor: strengthScore >= 1 ? getStrengthColor() : '#E2E8F0' }]} />
                <View style={[styles.strengthBar, { backgroundColor: strengthScore >= 2 ? getStrengthColor() : '#E2E8F0' }]} />
                <View style={[styles.strengthBar, { backgroundColor: strengthScore >= 3 ? getStrengthColor() : '#E2E8F0' }]} />
                <View style={[styles.strengthBar, { backgroundColor: strengthScore >= 4 ? getStrengthColor() : '#E2E8F0' }]} />
              </View>
              <Text style={[styles.strengthLabel, { color: getStrengthColor() }]}>
                {getStrengthLabel()}
              </Text>
            </View>

            <Text style={styles.label}>Confirm New Password</Text>
            <TextInput
              style={styles.input}
              placeholder="Confirm new password"
              placeholderTextColor="#94A3B8"
              value={confirmPassword}
              onChangeText={setConfirmPassword}
              secureTextEntry={!showPassword}
              autoCapitalize="none"
              autoCorrect={false}
              editable={!loading}
            />

            {/* Requirements Checklist */}
            <View style={styles.checklistCard}>
              <Text style={styles.checklistTitle}>Security Criteria Checklist:</Text>
              
              <View style={styles.checkRow}>
                <Text style={[styles.checkIndicator, isLenValid ? styles.checkValid : styles.checkInvalid]}>
                  {isLenValid ? '✓' : '✗'}
                </Text>
                <Text style={[styles.checkLabel, isLenValid && styles.checkTextValid]}>At least 8 characters long</Text>
              </View>

              <View style={styles.checkRow}>
                <Text style={[styles.checkIndicator, isUpperValid && isLowerValid ? styles.checkValid : styles.checkInvalid]}>
                  {isUpperValid && isLowerValid ? '✓' : '✗'}
                </Text>
                <Text style={[styles.checkLabel, isUpperValid && isLowerValid && styles.checkTextValid]}>Uppercase & lowercase letters</Text>
              </View>

              <View style={styles.checkRow}>
                <Text style={[styles.checkIndicator, isNumValid ? styles.checkValid : styles.checkInvalid]}>
                  {isNumValid ? '✓' : '✗'}
                </Text>
                <Text style={[styles.checkLabel, isNumValid && styles.checkTextValid]}>Contains a number (0-9)</Text>
              </View>

              <View style={styles.checkRow}>
                <Text style={[styles.checkIndicator, isSpecialValid ? styles.checkValid : styles.checkInvalid]}>
                  {isSpecialValid ? '✓' : '✗'}
                </Text>
                <Text style={[styles.checkLabel, isSpecialValid && styles.checkTextValid]}>Contains a special symbol</Text>
              </View>

              <View style={styles.checkRow}>
                <Text style={[styles.checkIndicator, isMatchValid ? styles.checkValid : styles.checkInvalid]}>
                  {isMatchValid ? '✓' : '✗'}
                </Text>
                <Text style={[styles.checkLabel, isMatchValid && styles.checkTextValid]}>Passwords match exactly</Text>
              </View>

              <View style={styles.checkRow}>
                <Text style={[styles.checkIndicator, isNotSameValid ? styles.checkValid : styles.checkInvalid]}>
                  {isNotSameValid ? '✓' : '✗'}
                </Text>
                <Text style={[styles.checkLabel, isNotSameValid && styles.checkTextValid]}>Different from temporary password</Text>
              </View>
            </View>

            <TouchableOpacity 
              style={[
                styles.setupBtn, 
                (!isMatchValid || strengthScore < 4 || !isNotSameValid || loading) && styles.setupBtnDisabled
              ]}
              onPress={handlePasswordSetup}
              disabled={!isMatchValid || strengthScore < 4 || !isNotSameValid || loading}
            >
              {loading ? (
                <ActivityIndicator color="#FFFFFF" />
              ) : (
                <Text style={styles.setupBtnText}>Save Security Setup</Text>
              )}
            </TouchableOpacity>
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
    paddingVertical: 30,
    justifyContent: 'center',
  },
  header: {
    marginBottom: 28,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#EF4444',
    letterSpacing: 1,
    marginBottom: 8,
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
    lineHeight: 18,
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
    marginBottom: 12,
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
  strengthContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 20,
  },
  strengthBarRow: {
    flexDirection: 'row',
    width: 120,
    gap: 4,
  },
  strengthBar: {
    flex: 1,
    height: 4,
    borderRadius: 2,
  },
  strengthLabel: {
    fontSize: 12,
    fontWeight: '700',
  },
  checklistCard: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 16,
    padding: 18,
    marginBottom: 24,
  },
  checklistTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#0F172A',
    marginBottom: 12,
  },
  checkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  checkIndicator: {
    fontSize: 14,
    fontWeight: 'bold',
    width: 20,
  },
  checkValid: {
    color: '#10B981',
  },
  checkInvalid: {
    color: '#94A3B8',
  },
  checkLabel: {
    fontSize: 12,
    color: '#64748B',
  },
  checkTextValid: {
    color: '#10B981',
    fontWeight: '500',
  },
  setupBtn: {
    height: 54,
    backgroundColor: '#10B981',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#10B981',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 3,
  },
  setupBtnDisabled: {
    backgroundColor: '#CBD5E1',
    shadowOpacity: 0,
    elevation: 0,
  },
  setupBtnText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '700',
  }
});

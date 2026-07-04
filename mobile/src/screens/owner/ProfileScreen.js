import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, Image, TouchableOpacity, ActivityIndicator } from 'react-native';
import api, { authService } from '../../services/api';

export default function ProfileScreen({ navigation, route }) {
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState(null);

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    try {
      setLoading(true);
      const res = await authService.getProfile();
      setUser(res.user);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  if (loading && !user) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#4F46E5" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {user ? (
        <>
          {/* Top header avatar card */}
          <View style={styles.headerCard}>
            <Image source={{ uri: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150' }} style={styles.avatar} />
            <Text style={styles.nameText}>{user.name || 'Sandeep Kumar'}</Text>
            <Text style={styles.occupationText}>{user.email}</Text>
            <View style={styles.statusBadge}>
              <Text style={styles.statusText}>Landlord / Owner</Text>
            </View>
          </View>

          {/* Account Profile Card */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Account Details</Text>
            <View style={styles.row}>
              <Text style={styles.lbl}>Primary Phone</Text>
              <Text style={styles.val}>{user.phone || '9999999999'}</Text>
            </View>
            <View style={styles.row}>
              <Text style={styles.lbl}>Associated Role</Text>
              <Text style={styles.val}>Primary Administrator</Text>
            </View>
          </View>

          {/* Security & Account Configuration */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Security & Account settings</Text>
            <TouchableOpacity 
              style={styles.settingLinkBtn}
              onPress={() => navigation.navigate('ActiveSessions')}
            >
              <Text style={styles.settingLinkText}>🖥️ Monitor Active Sessions</Text>
            </TouchableOpacity>

            <TouchableOpacity 
              style={styles.settingLinkBtn}
              onPress={() => navigation.navigate('AppLockSettings')}
            >
              <Text style={styles.settingLinkText}>🛡️ Passcode & Biometric Security</Text>
            </TouchableOpacity>

            <TouchableOpacity 
              style={[styles.settingLinkBtn, styles.logoutBtn]}
              onPress={async () => {
                try {
                  await api.post('/auth/logout');
                } catch (e) {}
                if (route.params?.onLogout) {
                  route.params.onLogout();
                }
              }}
            >
              <Text style={[styles.settingLinkText, styles.logoutBtnText]}>👋 Disconnect & Log Out</Text>
            </TouchableOpacity>
          </View>
        </>
      ) : (
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>Failed to load owner profile details.</Text>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  content: {
    padding: 20,
    gap: 20,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 24,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 8,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 3,
    borderColor: '#EEF2FF',
    marginBottom: 4,
  },
  nameText: {
    fontSize: 18,
    fontWeight: '700',
    color: '#0F172A',
  },
  occupationText: {
    fontSize: 13,
    color: '#64748B',
  },
  statusBadge: {
    backgroundColor: '#EEF2FF',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    marginTop: 4,
  },
  statusText: {
    color: '#4F46E5',
    fontSize: 11,
    fontWeight: '700',
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 14,
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#0F172A',
    borderBottomWidth: 1,
    borderBottomColor: '#F1F5F9',
    paddingBottom: 8,
    marginBottom: 4,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 20,
  },
  lbl: {
    fontSize: 12,
    color: '#94A3B8',
  },
  val: {
    fontSize: 13,
    fontWeight: '600',
    color: '#334155',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyText: {
    color: '#94A3B8',
    fontSize: 14,
  },
  settingLinkBtn: {
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F1F5F9',
  },
  settingLinkText: {
    fontSize: 14,
    color: '#4F46E5',
    fontWeight: '600',
  },
  logoutBtn: {
    borderBottomWidth: 0,
    marginTop: 6,
  },
  logoutBtnText: {
    color: '#EF4444',
  },
});

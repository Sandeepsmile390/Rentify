import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, Image, ActivityIndicator } from 'react-native';
import api from '../services/api';

export default function ProfileScreen({ navigation, route }) {
  const [loading, setLoading] = useState(true);
  const [tenant, setTenant] = useState(null);
  const tenantId = 'tenant-1'; // Ravi Kumar demo

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    try {
      setLoading(true);
      const response = await api.get('/tenants');
      const data = response.data;
      const myProfile = data.find(t => t.id === tenantId);
      if (myProfile) {
        setTenant(myProfile);
      }
    } catch (error) {
      console.error('Error loading profile:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading && !tenant) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6366F1" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {tenant ? (
        <>
          {/* Top header avatar card */}
          <View style={styles.headerCard}>
            <Image source={{ uri: tenant.photo }} style={styles.avatar} />
            <Text style={styles.nameText}>{tenant.name}</Text>
            <Text style={styles.occupationText}>{tenant.occupation}</Text>
            <View style={styles.statusBadge}>
              <Text style={styles.statusText}>{tenant.status} Tenant</Text>
            </View>
          </View>

          {/* Details Section */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Property Details</Text>
            <View style={styles.grid}>
              <View style={styles.col}>
                <Text style={styles.lbl}>Building</Text>
                <Text style={styles.val}>{tenant.propertyName}</Text>
              </View>
              <View style={styles.col}>
                <Text style={styles.lbl}>Room / Space</Text>
                <Text style={styles.val}>{tenant.roomNumber} ({tenant.roomType})</Text>
              </View>
              <View style={styles.col}>
                <Text style={styles.lbl}>Move In Date</Text>
                <Text style={styles.val}>{tenant.moveInDate}</Text>
              </View>
              <View style={styles.col}>
                <Text style={styles.lbl}>Agreement Duration</Text>
                <Text style={styles.val}>{tenant.agreementDuration} Months</Text>
              </View>
            </View>
          </View>

          {/* Finance Section */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Financial Terms</Text>
            <View style={styles.grid}>
              <View style={styles.col}>
                <Text style={styles.lbl}>Monthly Rent</Text>
                <Text style={styles.val}>₹{tenant.rentAmount}</Text>
              </View>
              <View style={styles.col}>
                <Text style={styles.lbl}>Security Deposit</Text>
                <Text style={styles.val}>₹{tenant.securityDeposit}</Text>
              </View>
              <View style={styles.col}>
                <Text style={styles.lbl}>Electricity Rate</Text>
                <Text style={styles.val}>₹{tenant.electricityRate} / Unit</Text>
              </View>
              <View style={styles.col}>
                <Text style={styles.lbl}>Fixed Water Cost</Text>
                <Text style={styles.val}>₹{tenant.waterCharges} / Mo</Text>
              </View>
            </View>
          </View>

          {/* Personal Details */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Personal Details</Text>
            <View style={styles.row}>
              <Text style={styles.lbl}>Father's Name</Text>
              <Text style={styles.val}>{tenant.fatherName}</Text>
            </View>
            <View style={styles.row}>
              <Text style={styles.lbl}>Phone Number</Text>
              <Text style={styles.val}>{tenant.phone}</Text>
            </View>
            <View style={styles.row}>
              <Text style={styles.lbl}>Aadhaar Number</Text>
              <Text style={styles.val}>{tenant.aadhaar}</Text>
            </View>
            <View style={styles.row}>
              <Text style={styles.lbl}>PAN Number</Text>
              <Text style={styles.val}>{tenant.pan}</Text>
            </View>
            <View style={styles.row}>
              <Text style={styles.lbl}>Permanent Address</Text>
              <Text style={styles.val}>{tenant.permanentAddress}</Text>
            </View>
          </View>

          {/* Documents Status */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Documents Status</Text>
            <View style={styles.docItem}>
              <Text style={styles.docName}>Profile Photo</Text>
              <Text style={styles.docStatus}>✓ Verified</Text>
            </View>
            <View style={styles.docItem}>
              <Text style={styles.docName}>Aadhaar Card (Front/Back)</Text>
              <Text style={styles.docStatus}>✓ Verified</Text>
            </View>
            <View style={styles.docItem}>
              <Text style={styles.docName}>PAN Card</Text>
              <Text style={styles.docStatus}>✓ Verified</Text>
            </View>
            <View style={styles.docItem}>
              <Text style={styles.docName}>Rental Agreement</Text>
              <Text style={styles.docStatus}>✓ Signed</Text>
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
          <Text style={styles.emptyText}>Failed to load profile details.</Text>
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
    backgroundColor: '#ECFDF5',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    marginTop: 4,
  },
  statusText: {
    color: '#10B981',
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
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 16,
  },
  col: {
    width: '45%',
    gap: 4,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 20,
  },
  lbl: {
    fontSize: 11,
    color: '#94A3B8',
  },
  val: {
    fontSize: 13,
    fontWeight: '600',
    color: '#334155',
    flexShrink: 1,
  },
  docItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 4,
  },
  docName: {
    fontSize: 13,
    color: '#475569',
  },
  docStatus: {
    fontSize: 12,
    color: '#10B981',
    fontWeight: '600',
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

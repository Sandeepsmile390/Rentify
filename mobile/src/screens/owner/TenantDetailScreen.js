import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, ActivityIndicator, Alert, Image, Linking, SafeAreaView } from 'react-native';
import { tenantService, billService } from '../../services/api';

export default function TenantDetailScreen({ route, navigation }) {
  const { tenantId } = route.params || {};
  const [loading, setLoading] = useState(true);
  const [tenant, setTenant] = useState(null);
  const [bills, setBills] = useState([]);
  const [activeTab, setActiveTab] = useState('details'); // 'details' | 'bills' | 'documents'

  useEffect(() => {
    fetchTenantDetails();
  }, [tenantId]);

  const fetchTenantDetails = async () => {
    if (!tenantId) return;
    try {
      setLoading(true);
      const list = await tenantService.getTenants();
      const match = list.find(t => t.id === tenantId);
      if (match) {
        setTenant(match);
        
        // Fetch bills
        const allBills = await billService.getBills();
        const tenantBills = allBills.filter(b => b.tenantId === tenantId);
        setBills(tenantBills.reverse());
      }
    } catch (e) {
      console.error(e);
      Alert.alert('Error', 'Failed to retrieve tenant information.');
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDoc = (url) => {
    if (!url) {
      Alert.alert('Not Uploaded', 'This document has not been uploaded by the tenant yet.');
      return;
    }
    Linking.openURL(url).catch(() => {
      Alert.alert('Error', 'Failed to open document link.');
    });
  };

  if (loading && !tenant) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#4F46E5" />
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity style={styles.backBtn} onPress={() => navigation.goBack()}>
          <Text style={styles.backBtnText}>← Tenants</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Tenant Details</Text>
      </View>

      {tenant ? (
        <>
          <View style={styles.topCard}>
            <Image 
              source={{ uri: tenant.photo || 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100' }} 
              style={styles.avatar} 
            />
            <View>
              <Text style={styles.name}>{tenant.name}</Text>
              <Text style={styles.roomText}>{tenant.propertyName} • Room {tenant.roomNumber}</Text>
              <View style={[styles.badge, tenant.status === 'Active' ? styles.badgeSuccess : styles.badgeInfo]}>
                <Text style={styles.badgeText}>{tenant.status}</Text>
              </View>
            </View>
          </View>

          {/* TAB SEGMENTS */}
          <View style={styles.tabRow}>
            {['details', 'bills', 'documents'].map((tab) => (
              <TouchableOpacity
                key={tab}
                style={[styles.tabButton, activeTab === tab && styles.tabButtonActive]}
                onPress={() => setActiveTab(tab)}
              >
                <Text style={[styles.tabText, activeTab === tab && styles.tabTextActive]}>
                  {tab.toUpperCase()}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <ScrollView contentContainerStyle={styles.scrollContent}>
            {activeTab === 'details' && (
              <View style={styles.section}>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Father's Name</Text>
                  <Text style={styles.val}>{tenant.fatherName || 'N/A'}</Text>
                </View>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Phone Number</Text>
                  <Text style={styles.val}>{tenant.phone}</Text>
                </View>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Email ID</Text>
                  <Text style={styles.val}>{tenant.email || 'N/A'}</Text>
                </View>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Aadhaar Card</Text>
                  <Text style={styles.val}>{tenant.aadhaar || 'N/A'}</Text>
                </View>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>PAN Card</Text>
                  <Text style={styles.val}>{tenant.pan || 'N/A'}</Text>
                </View>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Occupation</Text>
                  <Text style={styles.val}>{tenant.occupation || 'N/A'}</Text>
                </View>
                
                <View style={styles.divider} />
                
                <Text style={styles.sectionTitle}>Financial Config</Text>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Monthly Rent</Text>
                  <Text style={styles.val}>₹{tenant.rentAmount}</Text>
                </View>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Security Deposit</Text>
                  <Text style={styles.val}>₹{tenant.securityDeposit}</Text>
                </View>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Electricity Charge</Text>
                  <Text style={styles.val}>₹{tenant.electricityRate}/Unit</Text>
                </View>
                <View style={styles.infoRow}>
                  <Text style={styles.label}>Fixed Water Cost</Text>
                  <Text style={styles.val}>₹{tenant.waterCharges}/Mo</Text>
                </View>
              </View>
            )}

            {activeTab === 'bills' && (
              <View style={styles.section}>
                {bills.length === 0 ? (
                  <Text style={styles.emptyText}>No bills generated for this tenant.</Text>
                ) : (
                  bills.map((b) => (
                    <View key={b.id} style={styles.billItem}>
                      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                        <Text style={styles.billMonth}>{b.billingMonth}</Text>
                        <Text style={styles.billStatus}>{b.status}</Text>
                      </View>
                      <Text style={styles.billAmt}>Total: ₹{b.totalAmount} • Pending: ₹{b.pendingAmount}</Text>
                    </View>
                  ))
                )}
              </View>
            )}

            {activeTab === 'documents' && (
              <View style={styles.section}>
                <View style={styles.docRow}>
                  <Text style={styles.docName}>Profile Photo</Text>
                  <TouchableOpacity onPress={() => handleOpenDoc(tenant.photo)}>
                    <Text style={styles.docLink}>{tenant.photo ? '👁️ Open Link' : 'Pending'}</Text>
                  </TouchableOpacity>
                </View>

                <View style={styles.docRow}>
                  <Text style={styles.docName}>Aadhaar Card (Front)</Text>
                  <TouchableOpacity onPress={() => handleOpenDoc(tenant.aadhaarFront || tenant.photo)}>
                    <Text style={styles.docLink}>{(tenant.aadhaarFront || tenant.aadhaar) ? '👁️ Open Link' : 'Pending'}</Text>
                  </TouchableOpacity>
                </View>

                <View style={styles.docRow}>
                  <Text style={styles.docName}>Aadhaar Card (Back)</Text>
                  <TouchableOpacity onPress={() => handleOpenDoc(tenant.aadhaarBack)}>
                    <Text style={styles.docLink}>{tenant.aadhaarBack ? '👁️ Open Link' : 'Pending'}</Text>
                  </TouchableOpacity>
                </View>

                <View style={styles.docRow}>
                  <Text style={styles.docName}>PAN Card Scan</Text>
                  <TouchableOpacity onPress={() => handleOpenDoc(tenant.panCard)}>
                    <Text style={styles.docLink}>{tenant.panCard ? '👁️ Open Link' : 'Pending'}</Text>
                  </TouchableOpacity>
                </View>

                <View style={styles.docRow}>
                  <Text style={styles.docName}>Rental Agreement</Text>
                  <TouchableOpacity onPress={() => handleOpenDoc(tenant.agreement)}>
                    <Text style={styles.docLink}>{tenant.agreement ? '👁️ Open Link' : 'Pending'}</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}
          </ScrollView>
        </>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
    backgroundColor: '#FFFFFF',
  },
  backBtn: {
    marginRight: 16,
  },
  backBtnText: {
    color: '#4F46E5',
    fontWeight: '700',
    fontSize: 14,
  },
  title: {
    fontSize: 18,
    fontWeight: '800',
    color: '#0F172A',
  },
  topCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
    gap: 20,
  },
  avatar: {
    width: 64,
    height: 64,
    borderRadius: 32,
    borderWidth: 2,
    borderColor: '#EEF2FF',
  },
  name: {
    fontSize: 18,
    fontWeight: '700',
    color: '#0F172A',
  },
  roomText: {
    fontSize: 13,
    color: '#64748B',
    marginTop: 2,
  },
  badge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
    marginTop: 4,
  },
  badgeSuccess: {
    backgroundColor: '#ECFDF5',
  },
  badgeInfo: {
    backgroundColor: '#EEF2FF',
  },
  badgeText: {
    fontSize: 9,
    fontWeight: '700',
    color: '#1E293B',
  },
  tabRow: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
  },
  tabButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 14,
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabButtonActive: {
    borderBottomColor: '#4F46E5',
  },
  tabText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#94A3B8',
  },
  tabTextActive: {
    color: '#4F46E5',
  },
  scrollContent: {
    padding: 20,
  },
  section: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    padding: 20,
    gap: 14,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#94A3B8',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  label: {
    fontSize: 13,
    color: '#94A3B8',
  },
  val: {
    fontSize: 13,
    fontWeight: '600',
    color: '#334155',
  },
  divider: {
    height: 1,
    backgroundColor: '#F1F5F9',
  },
  billItem: {
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F1F5F9',
    gap: 4,
  },
  billMonth: {
    fontSize: 14,
    fontWeight: '700',
    color: '#0F172A',
  },
  billStatus: {
    fontSize: 11,
    fontWeight: '600',
    color: '#4F46E5',
  },
  billAmt: {
    fontSize: 12,
    color: '#64748B',
  },
  docRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F1F5F9',
  },
  docName: {
    fontSize: 13,
    color: '#475569',
    fontWeight: '500',
  },
  docLink: {
    fontSize: 13,
    color: '#4F46E5',
    fontWeight: '700',
  },
  emptyText: {
    fontSize: 13,
    color: '#94A3B8',
    textAlign: 'center',
    paddingVertical: 20,
  },
});

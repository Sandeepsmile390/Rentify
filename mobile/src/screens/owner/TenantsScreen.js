import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, TextInput, ActivityIndicator, Alert, Modal, SafeAreaView } from 'react-native';
import { tenantService, propertyService } from '../../services/api';

export default function TenantsScreen({ route, navigation }) {
  const [loading, setLoading] = useState(true);
  const [tenants, setTenants] = useState([]);
  const [properties, setProperties] = useState([]);
  const [vacantRooms, setVacantRooms] = useState([]);

  // Wizard modal
  const [showWizard, setShowWizard] = useState(false);
  const [step, setStep] = useState(1);
  const [wizardForm, setWizardForm] = useState({
    name: '',
    phone: '',
    email: '',
    propertyName: '',
    roomNumber: '',
    rentAmount: '',
    securityDeposit: '',
    electricityRate: '',
    waterCharges: '',
    agreementDuration: '',
    moveInDate: new Date().toISOString().split('T')[0],
  });

  useEffect(() => {
    fetchInitialData();
    if (route.params?.openCheckin) {
      setShowWizard(true);
    }
  }, [route.params]);

  const fetchInitialData = async () => {
    try {
      setLoading(true);
      const list = await tenantService.getTenants();
      setTenants(list);

      const props = await propertyService.getProperties();
      setProperties(props);

      // Find vacant rooms
      const vacant = [];
      props.forEach(p => {
        if (p.rooms) {
          p.rooms.forEach(r => {
            if (r.status === 'Vacant') {
              vacant.push({
                propertyName: p.name,
                roomNumber: r.roomNumber
              });
            }
          });
        }
      });
      setVacantRooms(vacant);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleNextStep = () => {
    if (step === 1) {
      if (!wizardForm.name.trim() || !wizardForm.phone.trim() || !wizardForm.propertyName || !wizardForm.roomNumber) {
        Alert.alert('Missing Fields', 'Please complete Step 1 details.');
        return;
      }
      setStep(2);
    } else if (step === 2) {
      if (!wizardForm.rentAmount || !wizardForm.securityDeposit || !wizardForm.electricityRate || !wizardForm.waterCharges || !wizardForm.agreementDuration) {
        Alert.alert('Missing Fields', 'Please complete Step 2 details.');
        return;
      }
      setStep(3);
    }
  };

  const handleSaveTenant = async () => {
    setLoading(true);
    try {
      const payload = {
        name: wizardForm.name.trim(),
        phone: wizardForm.phone.trim(),
        email: wizardForm.email.trim(),
        propertyName: wizardForm.propertyName,
        roomNumber: wizardForm.roomNumber,
        rentAmount: parseFloat(wizardForm.rentAmount),
        securityDeposit: parseFloat(wizardForm.securityDeposit),
        electricityRate: parseFloat(wizardForm.electricityRate),
        waterCharges: parseFloat(wizardForm.waterCharges),
        agreementDuration: parseInt(wizardForm.agreementDuration),
        moveInDate: wizardForm.moveInDate,
      };

      const res = await tenantService.createTenant(payload);
      if (res.success) {
        Alert.alert('Tenant Created', `Temporary Password: ${res.tempPassword}`, [
          { text: 'OK', onPress: () => {
            setShowWizard(false);
            setStep(1);
            setWizardForm({
              name: '',
              phone: '',
              email: '',
              propertyName: '',
              roomNumber: '',
              rentAmount: '',
              securityDeposit: '',
              electricityRate: '',
              waterCharges: '',
              agreementDuration: '',
              moveInDate: new Date().toISOString().split('T')[0],
            });
            fetchInitialData();
          }}
        ]);
      }
    } catch (e) {
      Alert.alert('Error', e.response?.data?.message || 'Failed to create tenant.');
    } finally {
      setLoading(false);
    }
  };

  if (loading && tenants.length === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#4F46E5" />
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.headerRow}>
        <TouchableOpacity style={styles.backBtn} onPress={() => navigation.navigate('DashboardTab')}>
          <Text style={styles.backBtnText}>← Dashboard</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Tenants</Text>
        <TouchableOpacity style={styles.addButton} onPress={() => setShowWizard(true)}>
          <Text style={styles.addButtonText}>+ Check-in Tenant</Text>
        </TouchableOpacity>
      </View>

      <ScrollView contentContainerStyle={styles.listContent}>
        {tenants.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyText}>No tenants checked in yet. Tap "Check-in Tenant" to begin.</Text>
          </View>
        ) : (
          tenants.map((t) => (
            <TouchableOpacity 
              key={t.id} 
              style={styles.tenantCard}
              onPress={() => navigation.navigate('TenantDetail', { tenantId: t.id })}
              activeOpacity={0.7}
            >
              <View style={styles.avatarPlaceholder}>
                <Text style={styles.avatarText}>{t.name[0].toUpperCase()}</Text>
              </View>
              <View style={styles.info}>
                <Text style={styles.tenantName}>{t.name}</Text>
                <Text style={styles.tenantSub}>{t.propertyName} • Room {t.roomNumber}</Text>
                <Text style={styles.tenantPhone}>📞 {t.phone}</Text>
              </View>
              <View style={[styles.badge, t.status === 'Active' ? styles.badgeSuccess : styles.badgeInfo]}>
                <Text style={styles.badgeText}>{t.status}</Text>
              </View>
            </TouchableOpacity>
          ))
        )}
      </ScrollView>

      {/* MULTI-STEP WIZARD MODAL */}
      <Modal visible={showWizard} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.wizardHeader}>
              <Text style={styles.modalTitle}>Tenant Check-in (Step {step}/3)</Text>
              <TouchableOpacity onPress={() => setShowWizard(false)}>
                <Text style={styles.closeText}>✕</Text>
              </TouchableOpacity>
            </View>

            {step === 1 && (
              <ScrollView style={styles.wizardBody}>
                <Text style={styles.label}>Full Name</Text>
                <TextInput 
                  style={styles.input} 
                  placeholder="e.g. Ramesh Sharma" 
                  value={wizardForm.name}
                  onChangeText={(t) => setWizardForm({ ...wizardForm, name: t })}
                />

                <Text style={styles.label}>Phone Number</Text>
                <TextInput 
                  style={styles.input} 
                  placeholder="e.g. 9876543210" 
                  keyboardType="phone-pad"
                  value={wizardForm.phone}
                  onChangeText={(t) => setWizardForm({ ...wizardForm, phone: t })}
                />

                <Text style={styles.label}>Email Address (Optional)</Text>
                <TextInput 
                  style={styles.input} 
                  placeholder="e.g. ramesh@gmail.com" 
                  keyboardType="email-address"
                  value={wizardForm.email}
                  onChangeText={(t) => setWizardForm({ ...wizardForm, email: t })}
                />

                <Text style={styles.label}>Assign Property / Room</Text>
                <View style={styles.roomsList}>
                  {vacantRooms.length === 0 ? (
                    <Text style={styles.emptyRoomsText}>⚠️ No vacant rooms. Add rooms in Properties screen first.</Text>
                  ) : (
                    vacantRooms.map((r, idx) => {
                      const isSelected = wizardForm.propertyName === r.propertyName && wizardForm.roomNumber === r.roomNumber;
                      return (
                        <TouchableOpacity
                          key={idx}
                          style={[styles.vacantBtn, isSelected && styles.vacantBtnActive]}
                          onPress={() => setWizardForm({ ...wizardForm, propertyName: r.propertyName, roomNumber: r.roomNumber })}
                        >
                          <Text style={[styles.vacantBtnText, isSelected && styles.vacantBtnTextActive]}>
                            {r.propertyName} - Room {r.roomNumber}
                          </Text>
                        </TouchableOpacity>
                      );
                    })
                  )}
                </View>
              </ScrollView>
            )}

            {step === 2 && (
              <ScrollView style={styles.wizardBody}>
                <Text style={styles.label}>Monthly Rent (₹)</Text>
                <TextInput 
                  style={styles.input} 
                  placeholder="e.g. 12000" 
                  keyboardType="numeric"
                  value={wizardForm.rentAmount}
                  onChangeText={(t) => setWizardForm({ ...wizardForm, rentAmount: t })}
                />

                <Text style={styles.label}>Security Deposit (₹)</Text>
                <TextInput 
                  style={styles.input} 
                  placeholder="e.g. 24000" 
                  keyboardType="numeric"
                  value={wizardForm.securityDeposit}
                  onChangeText={(t) => setWizardForm({ ...wizardForm, securityDeposit: t })}
                />

                <Text style={styles.label}>Electricity Rate (₹/unit)</Text>
                <TextInput 
                  style={styles.input} 
                  placeholder="e.g. 8" 
                  keyboardType="numeric"
                  value={wizardForm.electricityRate}
                  onChangeText={(t) => setWizardForm({ ...wizardForm, electricityRate: t })}
                />

                <Text style={styles.label}>Fixed Monthly Water Charges (₹)</Text>
                <TextInput 
                  style={styles.input} 
                  placeholder="e.g. 300" 
                  keyboardType="numeric"
                  value={wizardForm.waterCharges}
                  onChangeText={(t) => setWizardForm({ ...wizardForm, waterCharges: t })}
                />

                <Text style={styles.label}>Agreement Duration (Months)</Text>
                <TextInput 
                  style={styles.input} 
                  placeholder="e.g. 11" 
                  keyboardType="numeric"
                  value={wizardForm.agreementDuration}
                  onChangeText={(t) => setWizardForm({ ...wizardForm, agreementDuration: t })}
                />
              </ScrollView>
            )}

            {step === 3 && (
              <View style={styles.wizardBody}>
                <View style={styles.summaryBox}>
                  <Text style={styles.summaryTitle}>Check-in Confirmation</Text>
                  <Text style={styles.summaryText}>Tenant: {wizardForm.name}</Text>
                  <Text style={styles.summaryText}>Phone: {wizardForm.phone}</Text>
                  <Text style={styles.summaryText}>Property: {wizardForm.propertyName}</Text>
                  <Text style={styles.summaryText}>Room: {wizardForm.roomNumber}</Text>
                  <Text style={styles.summaryText}>Rent Rate: ₹{wizardForm.rentAmount}/Mo</Text>
                </View>
                <Text style={styles.hintText}>
                  ℹ️ Click Save to auto-generate security credentials. Tenant will receive login credentials.
                </Text>
              </View>
            )}

            <View style={styles.modalActions}>
              {step > 1 && (
                <TouchableOpacity style={styles.backWizardBtn} onPress={() => setStep(step - 1)}>
                  <Text style={styles.backWizardBtnText}>Back</Text>
                </TouchableOpacity>
              )}
              <View style={{ flexGrow: 1 }} />
              {step < 3 ? (
                <TouchableOpacity style={styles.submitBtn} onPress={handleNextStep}>
                  <Text style={styles.submitBtnText}>Next Step</Text>
                </TouchableOpacity>
              ) : (
                <TouchableOpacity style={styles.submitBtn} onPress={handleSaveTenant}>
                  <Text style={styles.submitBtnText}>Save Check-in</Text>
                </TouchableOpacity>
              )}
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
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
  },
  backBtn: {
    marginRight: 12,
  },
  backBtnText: {
    color: '#4F46E5',
    fontWeight: '700',
    fontSize: 13,
  },
  title: {
    flex: 1,
    fontSize: 20,
    fontWeight: '800',
    color: '#0F172A',
  },
  addButton: {
    backgroundColor: '#4F46E5',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
  },
  addButtonText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '700',
  },
  listContent: {
    padding: 20,
    gap: 16,
  },
  tenantCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 16,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 16,
  },
  avatarPlaceholder: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#EEF2FF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#4F46E5',
    fontSize: 16,
    fontWeight: '700',
  },
  info: {
    flex: 1,
    gap: 4,
  },
  tenantName: {
    fontSize: 15,
    fontWeight: '700',
    color: '#0F172A',
  },
  tenantSub: {
    fontSize: 12,
    color: '#64748B',
  },
  tenantPhone: {
    fontSize: 11,
    color: '#94A3B8',
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
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
  emptyState: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyText: {
    fontSize: 13,
    color: '#94A3B8',
    textAlign: 'center',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#FFFFFF',
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    padding: 24,
    maxHeight: '90%',
  },
  wizardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  modalTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: '#0F172A',
  },
  closeText: {
    fontSize: 16,
    color: '#94A3B8',
  },
  wizardBody: {
    maxHeight: 400,
    marginBottom: 16,
  },
  label: {
    fontSize: 12,
    fontWeight: '600',
    color: '#475569',
    marginBottom: 6,
    marginTop: 12,
  },
  input: {
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 12,
    padding: 12,
    fontSize: 14,
    color: '#0F172A',
  },
  roomsList: {
    gap: 8,
    marginTop: 8,
  },
  vacantBtn: {
    padding: 12,
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
  },
  vacantBtnActive: {
    borderColor: '#4F46E5',
    backgroundColor: '#EEF2FF',
  },
  vacantBtnText: {
    fontSize: 13,
    color: '#475569',
  },
  vacantBtnTextActive: {
    color: '#4F46E5',
    fontWeight: '700',
  },
  emptyRoomsText: {
    color: '#F59E0B',
    fontSize: 12,
    paddingVertical: 10,
  },
  summaryBox: {
    backgroundColor: '#F8FAFC',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 8,
  },
  summaryTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#0F172A',
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
    paddingBottom: 8,
    marginBottom: 4,
  },
  summaryText: {
    fontSize: 13,
    color: '#475569',
  },
  hintText: {
    fontSize: 12,
    color: '#64748B',
    marginTop: 16,
    lineHeight: 16,
  },
  modalActions: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
  },
  backWizardBtn: {
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  backWizardBtnText: {
    color: '#64748B',
    fontWeight: '700',
  },
  submitBtn: {
    backgroundColor: '#4F46E5',
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 12,
  },
  submitBtnText: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
});

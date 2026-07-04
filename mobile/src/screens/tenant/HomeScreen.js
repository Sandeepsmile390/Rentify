import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, TextInput, Alert, ActivityIndicator } from 'react-native';
import { authService, tenantService, billService, commentService } from '../../services/api';

export default function TenantHomeScreen({ navigation }) {
  const [loading, setLoading] = useState(true);
  const [currentUser, setCurrentUser] = useState(null);
  const [tenant, setTenant] = useState(null);
  const [bill, setBill] = useState(null);
  const [ticketTitle, setTicketTitle] = useState('');
  const [ticketMsg, setTicketMsg] = useState('');
  const [ticketCategory, setTicketCategory] = useState('Maintenance');

  useEffect(() => {
    fetchInitialData();
  }, []);

  const fetchInitialData = async () => {
    try {
      setLoading(true);
      const userRes = await authService.getProfile();
      const me = userRes.user;
      setCurrentUser(me);

      const tenantsList = await tenantService.getTenants();
      const myProfile = tenantsList.find(t => t.userId === me.id);
      
      if (myProfile) {
        setTenant(myProfile);
        
        // Fetch bills and filter by tenant ID
        const bills = await billService.getBills();
        const tenantBills = bills.filter(b => b.tenantId === myProfile.id);
        if (tenantBills.length > 0) {
          setBill(tenantBills[tenantBills.length - 1]);
        }
      }
    } catch (error) {
      console.error('Error fetching tenant home data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handlePay = async () => {
    if (!bill || !tenant) return;
    if (bill.pendingAmount <= 0) {
      Alert.alert('No Dues', 'All dues for this month are already cleared!');
      return;
    }

    try {
      setLoading(true);
      await billService.payBill(bill.id, bill.pendingAmount, 'UPI', 'Paid via mobile app');
      Alert.alert('Payment Recorded', `Successfully paid ₹${bill.pendingAmount} via UPI.`);
      fetchInitialData();
    } catch (error) {
      Alert.alert('Error', 'Failed to process payment');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmitTicket = async () => {
    if (!tenant) return;
    if (!ticketTitle || !ticketMsg) {
      Alert.alert('Missing Fields', 'Please enter a title and description for your issue.');
      return;
    }

    try {
      setLoading(true);
      await commentService.createTicket(tenant.id, ticketTitle, ticketCategory, ticketMsg);
      Alert.alert('Ticket Submitted', 'Owner has been notified of your maintenance request.');
      setTicketTitle('');
      setTicketMsg('');
    } catch (error) {
      Alert.alert('Error', 'Failed to log maintenance issue');
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
      {/* Header Info */}
      <View style={styles.welcomeCard}>
        <Text style={styles.welcomeTitle}>Welcome Back, {tenant ? tenant.name : 'Resident'}!</Text>
        <Text style={styles.welcomeSub}>{tenant ? `${tenant.propertyName} • Room ${tenant.roomNumber}` : 'Loading...'}</Text>
      </View>

      {/* Due Card */}
      {bill ? (
        <View style={styles.dueCard}>
          <Text style={styles.dueLabel}>Current Month Rent ({bill.billingMonth})</Text>
          <Text style={styles.dueAmount}>₹{bill.pendingAmount}</Text>
          
          <View style={styles.progressBarContainer}>
            <View 
              style={[
                styles.progressBarFill, 
                { width: `${(bill.paidAmount / bill.totalAmount) * 100}%` }
              ]} 
            />
          </View>
          <Text style={styles.progressText}>
            {Math.round((bill.paidAmount / bill.totalAmount) * 100)}% Paid (Received ₹{bill.paidAmount} of ₹{bill.totalAmount})
          </Text>

          <View style={styles.dueDateRow}>
            <Text style={styles.dueDateLabel}>Due Date: </Text>
            <Text style={styles.dueDateVal}>{bill.dueDate}</Text>
            <View style={[styles.statusBadge, bill.status === 'Paid' ? styles.badgeSuccess : styles.badgeWarning]}>
              <Text style={styles.statusText}>{bill.status}</Text>
            </View>
          </View>

          {bill.pendingAmount > 0 && (
            <TouchableOpacity style={styles.payButton} onPress={handlePay}>
              <Text style={styles.payButtonText}>Pay Now (UPI / Card)</Text>
            </TouchableOpacity>
          )}
        </View>
      ) : (
        <View style={styles.dueCard}>
          <Text style={styles.dueLabel}>No active bills generated for this month.</Text>
        </View>
      )}

      {/* Maintenance Form */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Report a Maintenance Issue</Text>
        
        <View style={styles.categoryRow}>
          {['Maintenance', 'Plumbing', 'Electrical'].map((cat) => (
            <TouchableOpacity
              key={cat}
              style={[styles.categoryBtn, ticketCategory === cat && styles.categoryBtnActive]}
              onPress={() => setTicketCategory(cat)}
            >
              <Text style={[styles.categoryBtnText, ticketCategory === cat && styles.categoryBtnTextActive]}>
                {cat}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <TextInput
          style={styles.input}
          placeholder="Issue Title (e.g. Water leakage, Fan broken)"
          placeholderTextColor="#94A3B8"
          value={ticketTitle}
          onChangeText={setTicketTitle}
        />

        <TextInput
          style={[styles.input, styles.textArea]}
          placeholder="Describe the issue in detail..."
          placeholderTextColor="#94A3B8"
          multiline
          numberOfLines={4}
          value={ticketMsg}
          onChangeText={setTicketMsg}
        />

        <TouchableOpacity style={styles.submitBtn} onPress={handleSubmitTicket}>
          <Text style={styles.submitBtnText}>Submit Maintenance Request</Text>
        </TouchableOpacity>
      </View>
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
    backgroundColor: '#F8FAFC',
  },
  welcomeCard: {
    padding: 24,
    borderRadius: 20,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  welcomeTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: '#0F172A',
  },
  welcomeSub: {
    fontSize: 14,
    color: '#64748B',
    marginTop: 4,
  },
  dueCard: {
    backgroundColor: '#1E293B',
    padding: 24,
    borderRadius: 20,
    gap: 12,
  },
  dueLabel: {
    color: '#94A3B8',
    fontSize: 13,
    fontWeight: '500',
  },
  dueAmount: {
    color: '#FFFFFF',
    fontSize: 32,
    fontWeight: '800',
  },
  progressBarContainer: {
    height: 6,
    backgroundColor: '#334155',
    borderRadius: 3,
    overflow: 'hidden',
    marginTop: 6,
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: '#6366F1',
    borderRadius: 3,
  },
  progressText: {
    color: '#94A3B8',
    fontSize: 11,
  },
  dueDateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 10,
    gap: 8,
  },
  dueDateLabel: {
    color: '#94A3B8',
    fontSize: 12,
  },
  dueDateVal: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 12,
  },
  badgeSuccess: {
    backgroundColor: '#064E3B',
  },
  badgeWarning: {
    backgroundColor: '#78350F',
  },
  statusText: {
    color: '#FFFFFF',
    fontSize: 10,
    fontWeight: '700',
  },
  payButton: {
    backgroundColor: '#6366F1',
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    marginTop: 10,
  },
  payButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '700',
  },
  card: {
    backgroundColor: '#FFFFFF',
    padding: 20,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 16,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#0F172A',
  },
  categoryRow: {
    flexDirection: 'row',
    gap: 10,
  },
  categoryBtn: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  categoryBtnActive: {
    backgroundColor: '#EEF2FF',
    borderColor: '#6366F1',
  },
  categoryBtnText: {
    fontSize: 12,
    color: '#475569',
  },
  categoryBtnTextActive: {
    color: '#6366F1',
    fontWeight: '600',
  },
  input: {
    borderWidth: 1,
    borderColor: '#E2E8F0',
    borderRadius: 10,
    padding: 12,
    fontSize: 14,
    color: '#0F172A',
  },
  textArea: {
    height: 100,
    textAlignVertical: 'top',
  },
  submitBtn: {
    backgroundColor: '#475569',
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  submitBtnText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '700',
  },
});

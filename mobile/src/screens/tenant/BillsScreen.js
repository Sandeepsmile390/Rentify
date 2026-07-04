import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, FlatList, TouchableOpacity, Alert, ActivityIndicator } from 'react-native';
import { authService, tenantService, billService } from '../../services/api';

export default function TenantBillsScreen() {
  const [loading, setLoading] = useState(true);
  const [bills, setBills] = useState([]);

  useEffect(() => {
    fetchBills();
  }, []);

  const fetchBills = async () => {
    try {
      setLoading(true);
      const userRes = await authService.getProfile();
      const me = userRes.user;

      const tenantsList = await tenantService.getTenants();
      const myProfile = tenantsList.find(t => t.userId === me.id);

      if (myProfile) {
        const data = await billService.getBills();
        const tenantBills = data.filter(b => b.tenantId === myProfile.id);
        setBills(tenantBills.reverse());
      }
    } catch (error) {
      console.error('Error fetching tenant bills:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleDownloadReceipt = (bill) => {
    if (bill.paidAmount === 0) {
      Alert.alert('No Receipt', 'No payment has been recorded for this bill yet.');
      return;
    }
    Alert.alert(
      'Receipt Downloaded',
      `Receipt_${bill.billingMonth.replace(' ', '_')}.pdf has been saved to your downloads.\nTotal Paid: ₹${bill.paidAmount}\nStatus: ${bill.status}`
    );
  };

  const renderBillItem = ({ item }) => (
    <View style={styles.billCard}>
      <View style={styles.billHeader}>
        <Text style={styles.monthText}>{item.billingMonth}</Text>
        <View style={[styles.badge, item.status === 'Paid' ? styles.badgeSuccess : item.status === 'Partial Paid' ? styles.badgeWarning : styles.badgeDanger]}>
          <Text style={styles.badgeText}>{item.status}</Text>
        </View>
      </View>

      <View style={styles.divider} />

      <View style={styles.detailsRow}>
        <View style={styles.detailCol}>
          <Text style={styles.lbl}>Rent Amount</Text>
          <Text style={styles.val}>₹{item.rentAmount}</Text>
        </View>
        <View style={styles.detailCol}>
          <Text style={styles.lbl}>Electricity ({item.electricityUnits} units)</Text>
          <Text style={styles.val}>₹{item.electricityAmount}</Text>
        </View>
        <View style={styles.detailCol}>
          <Text style={styles.lbl}>Water & Fixed</Text>
          <Text style={styles.val}>₹{item.waterCharges}</Text>
        </View>
      </View>

      {item.lateFee > 0 || item.discount > 0 || item.extraCharges > 0 ? (
        <View style={styles.extraRow}>
          {item.lateFee > 0 && <Text style={styles.extraText}>Late Fee: +₹{item.lateFee}</Text>}
          {item.extraCharges > 0 && <Text style={styles.extraText}>Extra: +₹{item.extraCharges} ({item.extraChargesReason})</Text>}
          {item.discount > 0 && <Text style={[styles.extraText, styles.greenText]}>Discount: -₹{item.discount}</Text>}
        </View>
      ) : null}

      <View style={styles.totalRow}>
        <View>
          <Text style={styles.totalLabel}>Total Due</Text>
          <Text style={styles.totalVal}>₹{item.totalAmount}</Text>
        </View>
        <View style={styles.alignRight}>
          <Text style={styles.totalLabel}>Paid So Far</Text>
          <Text style={[styles.totalVal, styles.indigoText]}>₹{item.paidAmount}</Text>
        </View>
      </View>

      {item.payments && item.payments.length > 0 && (
        <View style={styles.ledgerSection}>
          <Text style={styles.ledgerHeader}>Payments Ledger</Text>
          {item.payments.map((p, idx) => (
            <View key={idx} style={styles.ledgerItem}>
              <Text style={styles.ledgerDate}>{p.date} • {p.method}</Text>
              <Text style={styles.ledgerAmount}>₹{p.amount}</Text>
            </View>
          ))}
        </View>
      )}

      <View style={styles.actionRow}>
        <TouchableOpacity 
          style={[styles.btn, item.paidAmount === 0 && styles.disabledBtn]} 
          onPress={() => handleDownloadReceipt(item)}
        >
          <Text style={styles.btnText}>Download Receipt</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  if (loading && bills.length === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6366F1" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={bills}
        renderItem={renderBillItem}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContent}
        onRefresh={fetchBills}
        refreshing={loading}
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Text style={styles.emptyText}>No bills found.</Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  listContent: {
    padding: 20,
    gap: 20,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  billCard: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    borderRadius: 20,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.02,
    shadowRadius: 10,
    elevation: 1,
  },
  billHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  monthText: {
    fontSize: 16,
    fontWeight: '700',
    color: '#0F172A',
  },
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 20,
  },
  badgeSuccess: {
    backgroundColor: '#ECFDF5',
  },
  badgeWarning: {
    backgroundColor: '#FEF3C7',
  },
  badgeDanger: {
    backgroundColor: '#FEF2F2',
  },
  badgeText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#1E293B',
  },
  divider: {
    height: 1,
    backgroundColor: '#E2E8F0',
    marginVertical: 14,
  },
  detailsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  detailCol: {
    flex: 1,
  },
  lbl: {
    fontSize: 10,
    color: '#94A3B8',
    marginBottom: 4,
  },
  val: {
    fontSize: 13,
    fontWeight: '600',
    color: '#475569',
  },
  extraRow: {
    backgroundColor: '#F8FAFC',
    padding: 8,
    borderRadius: 8,
    gap: 4,
    marginBottom: 12,
  },
  extraText: {
    fontSize: 11,
    color: '#64748B',
  },
  greenText: {
    color: '#10B981',
  },
  totalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: '#EEF2FF',
    padding: 12,
    borderRadius: 12,
    marginTop: 6,
  },
  totalLabel: {
    fontSize: 10,
    color: '#6366F1',
    fontWeight: '600',
    marginBottom: 2,
  },
  totalVal: {
    fontSize: 15,
    fontWeight: '700',
    color: '#0F172A',
  },
  alignRight: {
    alignItems: 'flex-end',
  },
  indigoText: {
    color: '#6366F1',
  },
  ledgerSection: {
    marginTop: 16,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#F1F5F9',
  },
  ledgerHeader: {
    fontSize: 12,
    fontWeight: '700',
    color: '#334155',
    marginBottom: 8,
  },
  ledgerItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 6,
    borderBottomWidth: 1,
    borderBottomColor: '#F8FAFC',
  },
  ledgerDate: {
    fontSize: 11,
    color: '#64748B',
  },
  ledgerAmount: {
    fontSize: 11,
    fontWeight: '600',
    color: '#0F172A',
  },
  actionRow: {
    marginTop: 16,
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  btn: {
    backgroundColor: '#F1F5F9',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 10,
  },
  disabledBtn: {
    opacity: 0.5,
  },
  btnText: {
    fontSize: 12,
    color: '#475569',
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
});

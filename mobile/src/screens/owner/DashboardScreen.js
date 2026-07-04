import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { propertyService, tenantService, billService, commentService } from '../../services/api';

export default function DashboardScreen({ navigation }) {
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    propertiesCount: 0,
    roomsCount: 0,
    vacantCount: 0,
    occupiedCount: 0,
    revenue: 0,
    activeTickets: 0
  });

  useEffect(() => {
    fetchDashboardStats();
    const unsubscribe = navigation.addListener('focus', () => {
      fetchDashboardStats();
    });
    return unsubscribe;
  }, [navigation]);

  const fetchDashboardStats = async () => {
    try {
      setLoading(true);
      const props = await propertyService.getProperties();
      const tenantsList = await tenantService.getTenants();
      const bills = await billService.getBills();
      const tickets = await commentService.getComments();

      let roomsCount = 0;
      let vacantCount = 0;
      let occupiedCount = 0;

      props.forEach(p => {
        if (p.rooms) {
          roomsCount += p.rooms.length;
          p.rooms.forEach(r => {
            if (r.status === 'Occupied') occupiedCount++;
            else vacantCount++;
          });
        }
      });

      // Sum revenue (sum of payments or paidAmount inside bills)
      let revenue = 0;
      bills.forEach(b => {
        if (b.paidAmount) revenue += b.paidAmount;
      });

      // Sum active maintenance tickets
      const activeTickets = tickets.length;

      setStats({
        propertiesCount: props.length,
        roomsCount,
        vacantCount,
        occupiedCount,
        revenue,
        activeTickets
      });
    } catch (e) {
      console.error('Error fetching dashboard stats:', e);
    } finally {
      setLoading(false);
    }
  };

  if (loading && stats.propertiesCount === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#4F46E5" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Text style={styles.title}>Landlord Portal</Text>
        <Text style={styles.sub}>Dashboard overview & quick actions</Text>
      </View>

      {/* Grid of Stats Cards */}
      <View style={styles.grid}>
        <View style={styles.statCard}>
          <Text style={styles.statEmoji}>🏢</Text>
          <Text style={styles.statVal}>{stats.propertiesCount}</Text>
          <Text style={styles.statLabel}>Total Properties</Text>
        </View>

        <View style={styles.statCard}>
          <Text style={styles.statEmoji}>🔑</Text>
          <Text style={styles.statVal}>{stats.roomsCount}</Text>
          <Text style={styles.statLabel}>Total Rooms</Text>
        </View>

        <View style={[styles.statCard, styles.greenStat]}>
          <Text style={styles.statEmoji}>🟢</Text>
          <Text style={styles.statVal}>{stats.vacantCount}</Text>
          <Text style={styles.statLabel}>Vacant Rooms</Text>
        </View>

        <View style={[styles.statCard, styles.indigoStat]}>
          <Text style={styles.statEmoji}>🔵</Text>
          <Text style={styles.statVal}>{stats.occupiedCount}</Text>
          <Text style={styles.statLabel}>Occupied Rooms</Text>
        </View>

        <View style={[styles.statCard, styles.wideStat]}>
          <Text style={styles.statEmoji}>💵</Text>
          <View>
            <Text style={styles.wideStatVal}>₹{stats.revenue}</Text>
            <Text style={styles.statLabel}>Total Collections</Text>
          </View>
        </View>

        <View style={[styles.statCard, styles.wideStat, styles.orangeStat]}>
          <Text style={styles.statEmoji}>🛠️</Text>
          <View>
            <Text style={styles.wideStatVal}>{stats.activeTickets}</Text>
            <Text style={styles.statLabel}>Active Maintenance Tickets</Text>
          </View>
        </View>
      </View>

      {/* Quick Action Buttons */}
      <View style={styles.actionsCard}>
        <Text style={styles.sectionTitle}>Quick Operations</Text>
        
        <TouchableOpacity 
          style={styles.actionBtn} 
          onPress={() => navigation.navigate('Tenants', { openCheckin: true })}
        >
          <Text style={styles.actionIcon}>➕</Text>
          <View>
            <Text style={styles.actionTitle}>Check-in New Tenant</Text>
            <Text style={styles.actionDesc}>Launch the multi-step tenant setup wizard</Text>
          </View>
        </TouchableOpacity>

        <TouchableOpacity 
          style={styles.actionBtn} 
          onPress={() => navigation.navigate('Properties', { openAddProperty: true })}
        >
          <Text style={styles.actionIcon}>🏗️</Text>
          <View>
            <Text style={styles.actionTitle}>Add New Property</Text>
            <Text style={styles.actionDesc}>Configure buildings and room specifications</Text>
          </View>
        </TouchableOpacity>

        <TouchableOpacity 
          style={styles.actionBtn}
          onPress={async () => {
            Alert.prompt(
              'Generate Monthly Bills',
              'Enter billing month (e.g. "July 2026"):',
              [
                { text: 'Cancel', style: 'cancel' },
                {
                  text: 'Generate',
                  onPress: async (month) => {
                    if (!month) return;
                    try {
                      setLoading(true);
                      await billService.generateMonthlyBills(month);
                      Alert.alert('Success', `Monthly bills for ${month} generated successfully.`);
                      fetchDashboardStats();
                    } catch (err) {
                      Alert.alert('Error', 'Failed to generate bills.');
                    } finally {
                      setLoading(false);
                    }
                  }
                }
              ]
            );
          }}
        >
          <Text style={styles.actionIcon}>🧾</Text>
          <View>
            <Text style={styles.actionTitle}>Bulk Generate Bills</Text>
            <Text style={styles.actionDesc}>Generate rent invoices for all occupied rooms</Text>
          </View>
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
    padding: 24,
    gap: 24,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F8FAFC',
  },
  header: {
    marginBottom: 4,
  },
  title: {
    fontSize: 24,
    fontWeight: '800',
    color: '#0F172A',
  },
  sub: {
    fontSize: 13,
    color: '#64748B',
    marginTop: 4,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 16,
  },
  statCard: {
    width: '47%',
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 6,
  },
  greenStat: {
    borderColor: '#A7F3D0',
  },
  indigoStat: {
    borderColor: '#C7D2FE',
  },
  wideStat: {
    width: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  orangeStat: {
    borderColor: '#FED7AA',
  },
  statEmoji: {
    fontSize: 24,
  },
  statVal: {
    fontSize: 22,
    fontWeight: '800',
    color: '#0F172A',
  },
  wideStatVal: {
    fontSize: 26,
    fontWeight: '800',
    color: '#0F172A',
  },
  statLabel: {
    fontSize: 12,
    color: '#64748B',
    fontWeight: '500',
  },
  actionsCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 16,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#94A3B8',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 4,
  },
  actionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderRadius: 16,
    backgroundColor: '#F8FAFC',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 16,
  },
  actionIcon: {
    fontSize: 22,
  },
  actionTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#0F172A',
  },
  actionDesc: {
    fontSize: 11,
    color: '#64748B',
    marginTop: 2,
  },
});

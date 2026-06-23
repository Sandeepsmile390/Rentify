import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, FlatList, TouchableOpacity, ActivityIndicator, Alert, SafeAreaView } from 'react-native';
import { authService } from '../services/api';

export default function ActiveSessionsScreen({ navigation }) {
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadSessions();
  }, []);

  const loadSessions = async () => {
    setLoading(true);
    try {
      const data = await authService.getSessions();
      setSessions(data);
    } catch (e) {
      console.warn(e);
      Alert.alert('Load Error', 'Failed to retrieve active session records.');
    } finally {
      setLoading(false);
    }
  };

  const handleRevoke = async (sessionId) => {
    Alert.alert(
      'Revoke Device Session',
      'Are you sure you want to log out and disconnect this device?',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Disconnect', 
          style: 'destructive',
          onPress: async () => {
            try {
              await authService.logoutSession(sessionId);
              Alert.alert('Success', 'Device disconnected.');
              loadSessions();
            } catch (err) {
              Alert.alert('Error', 'Failed to revoke device session.');
            }
          }
        }
      ]
    );
  };

  const handleRevokeAll = () => {
    Alert.alert(
      'Logout All Other Devices',
      'Are you sure you want to clear all active sessions except this current device?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear All Sessions',
          style: 'destructive',
          onPress: async () => {
            try {
              await authService.logoutAllSessions();
              Alert.alert('Revoked', 'All other device sessions have been cleared.', [
                { text: 'OK', onPress: () => navigation.goBack() }
              ]);
            } catch (err) {
              Alert.alert('Error', 'Failed to clear other sessions.');
            }
          }
        }
      ]
    );
  };

  const renderSessionCard = ({ item }) => {
    const isCurrent = item.tokenHash === null; // local mock or marker representation
    
    return (
      <View style={[styles.sessionCard, isCurrent && styles.currentCard]}>
        <View style={styles.cardInfo}>
          <View style={styles.cardHeader}>
            <Text style={styles.deviceName}>{item.deviceName}</Text>
            {isCurrent && <Text style={styles.currentBadge}>Current Device</Text>}
          </View>
          <Text style={styles.deviceMeta}>{item.browser} • {item.os}</Text>
          <Text style={styles.deviceIp}>{item.ipAddress} • {item.location || 'Unknown Location'}</Text>
          <Text style={styles.deviceActive}>Active: {new Date(item.lastActive).toLocaleString()}</Text>
        </View>

        {!isCurrent && (
          <TouchableOpacity style={styles.revokeBtn} onPress={() => handleRevoke(item.id)}>
            <Text style={styles.revokeBtnText}>Disconnect</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.headerRow}>
        <View>
          <Text style={styles.title}>Active Sessions</Text>
          <Text style={styles.subtitle}>Manage devices logged into your account</Text>
        </View>
        <TouchableOpacity 
          style={styles.revokeAllBtn} 
          onPress={handleRevokeAll}
          disabled={sessions.length <= 1}
        >
          <Text style={styles.revokeAllBtnText}>Revoke All Other</Text>
        </TouchableOpacity>
      </View>

      {loading ? (
        <View style={styles.loader}>
          <ActivityIndicator size="large" color="#4F46E5" />
          <Text style={styles.loaderText}>Syncing session registry...</Text>
        </View>
      ) : (
        <FlatList
          data={sessions}
          keyExtractor={(item) => item.id}
          renderItem={renderSessionCard}
          contentContainerStyle={styles.listContainer}
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <Text style={styles.emptyStateText}>No active device sessions registered.</Text>
            </View>
          }
          onRefresh={loadSessions}
          refreshing={loading}
        />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
    backgroundColor: '#FFFFFF',
  },
  title: {
    fontSize: 18,
    fontWeight: '800',
    color: '#0F172A',
  },
  subtitle: {
    fontSize: 12,
    color: '#64748B',
    marginTop: 2,
  },
  revokeAllBtn: {
    backgroundColor: '#FEF2F2',
    borderWidth: 1,
    borderColor: '#EF4444',
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
  },
  revokeAllBtnText: {
    color: '#EF4444',
    fontSize: 12,
    fontWeight: '700',
  },
  listContainer: {
    padding: 16,
  },
  sessionCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#0F172A',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.02,
    shadowRadius: 8,
    elevation: 1,
  },
  currentCard: {
    borderColor: '#10B981',
    backgroundColor: '#ECFDF5',
  },
  cardInfo: {
    flex: 1,
    paddingRight: 10,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
    gap: 8,
  },
  deviceName: {
    fontSize: 15,
    fontWeight: '700',
    color: '#0F172A',
  },
  currentBadge: {
    fontSize: 9,
    fontWeight: '700',
    backgroundColor: '#10B981',
    color: '#FFFFFF',
    paddingVertical: 1,
    paddingHorizontal: 6,
    borderRadius: 6,
    textTransform: 'uppercase',
  },
  deviceMeta: {
    fontSize: 12,
    color: '#475569',
    fontWeight: '500',
    marginBottom: 2,
  },
  deviceIp: {
    fontSize: 12,
    color: '#64748B',
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    marginBottom: 4,
  },
  deviceActive: {
    fontSize: 10,
    color: '#94A3B8',
  },
  revokeBtn: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
  },
  revokeBtnText: {
    color: '#475569',
    fontSize: 12,
    fontWeight: '600',
  },
  loader: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  loaderText: {
    fontSize: 13,
    color: '#64748B',
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  emptyStateText: {
    fontSize: 13,
    color: '#94A3B8',
  }
});

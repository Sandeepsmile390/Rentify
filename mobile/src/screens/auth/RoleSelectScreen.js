import React, { useEffect, useRef } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, Animated, SafeAreaView, Dimensions } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

const { width } = Dimensions.get('window');

export default function RoleSelectScreen({ navigation }) {
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnimOwner = useRef(new Animated.Value(-100)).current;
  const slideAnimTenant = useRef(new Animated.Value(100)).current;

  useEffect(() => {
    // Run entering animations
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 800,
        useNativeDriver: true,
      }),
      Animated.timing(slideAnimOwner, {
        toValue: 0,
        duration: 800,
        useNativeDriver: true,
      }),
      Animated.timing(slideAnimTenant, {
        toValue: 0,
        duration: 800,
        useNativeDriver: true,
      })
    ]).start();

    // Check for remember last selected role
    checkLastRole();
  }, []);

  const checkLastRole = async () => {
    try {
      const lastRole = await AsyncStorage.getItem('last_selected_role');
      if (lastRole) {
        // We can auto-navigate or set initial focus
        console.log('Last selected role:', lastRole);
      }
    } catch (e) {
      console.warn(e);
    }
  };

  const handleSelectRole = async (role) => {
    try {
      await AsyncStorage.setItem('last_selected_role', role);
      if (role === 'owner') {
        navigation.navigate('OwnerLogin');
      } else {
        navigation.navigate('TenantLogin');
      }
    } catch (e) {
      console.warn(e);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <Animated.View style={[styles.headerContainer, { opacity: fadeAnim }]}>
        <Text style={styles.brandTitle}>⚡ RentFlow</Text>
        <Text style={styles.subtitle}>Smart Estates Management</Text>
        <Text style={styles.promptText}>Select your portal role to proceed:</Text>
      </Animated.View>

      <View style={styles.cardsContainer}>
        {/* OWNER CARD */}
        <Animated.View style={{ transform: [{ translateX: slideAnimOwner }], opacity: fadeAnim, width: '100%' }}>
          <TouchableOpacity 
            style={[styles.roleCard, styles.ownerCardBorder]}
            onPress={() => handleSelectRole('owner')}
            activeOpacity={0.85}
          >
            <View style={[styles.iconBox, styles.ownerGradient]}>
              <Text style={styles.cardEmoji}>🏠</Text>
            </View>
            <View style={styles.cardInfo}>
              <Text style={styles.cardTitle}>Login as Owner</Text>
              <Text style={styles.cardDesc}>Access properties, manage tenant ledgers, track audits, and review bills.</Text>
            </View>
            <Text style={styles.cardArrow}>→</Text>
          </TouchableOpacity>
        </Animated.View>

        {/* TENANT CARD */}
        <Animated.View style={{ transform: [{ translateX: slideAnimTenant }], opacity: fadeAnim, width: '100%', marginTop: 20 }}>
          <TouchableOpacity 
            style={[styles.roleCard, styles.tenantCardBorder]}
            onPress={() => handleSelectRole('tenant')}
            activeOpacity={0.85}
          >
            <View style={[styles.iconBox, styles.tenantGradient]}>
              <Text style={styles.cardEmoji}>👤</Text>
            </View>
            <View style={styles.cardInfo}>
              <Text style={styles.cardTitle}>Login as Tenant</Text>
              <Text style={styles.cardDesc}>Download invoices, review agreements, request repairs, and message owners.</Text>
            </View>
            <Text style={styles.cardArrow}>→</Text>
          </TouchableOpacity>
        </Animated.View>
      </View>

      <Text style={styles.footerNote}>RentFlow Encrypted Gate • v1.4.0</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  headerContainer: {
    alignItems: 'center',
    marginBottom: 48,
  },
  brandTitle: {
    fontSize: 32,
    fontWeight: '800',
    color: '#0F172A',
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 15,
    color: '#64748B',
    fontWeight: '500',
    marginBottom: 24,
  },
  promptText: {
    fontSize: 14,
    color: '#94A3B8',
    textTransform: 'uppercase',
    letterSpacing: 1,
    fontWeight: '600',
  },
  cardsContainer: {
    width: '100%',
    maxWidth: 400,
    alignItems: 'center',
  },
  roleCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    padding: 24,
    borderRadius: 20,
    borderWidth: 1.5,
    shadowColor: '#0F172A',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 15,
    elevation: 3,
  },
  ownerCardBorder: {
    borderColor: '#E2E8F0',
  },
  tenantCardBorder: {
    borderColor: '#E2E8F0',
  },
  iconBox: {
    width: 56,
    height: 56,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ownerGradient: {
    backgroundColor: '#4F46E5',
  },
  tenantGradient: {
    backgroundColor: '#06B6D4',
  },
  cardEmoji: {
    fontSize: 26,
  },
  cardInfo: {
    flex: 1,
    marginLeft: 16,
    paddingRight: 8,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: '#0F172A',
    marginBottom: 4,
  },
  cardDesc: {
    fontSize: 12,
    color: '#64748B',
    lineHeight: 16,
  },
  cardArrow: {
    fontSize: 18,
    color: '#94A3B8',
    fontWeight: '600',
  },
  footerNote: {
    position: 'absolute',
    bottom: 24,
    fontSize: 11,
    color: '#CBD5E1',
    letterSpacing: 0.5,
  }
});

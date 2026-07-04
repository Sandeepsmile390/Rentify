import React, { useState } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, ScrollView, ActivityIndicator, Alert, SafeAreaView } from 'react-native';
import { tenantService } from '../../services/api';

export default function DocumentUploadScreen({ route, navigation }) {
  const { tenantId, onBack } = route.params || {};
  const [uploading, setUploading] = useState(false);
  const [selectedDocKey, setSelectedDocKey] = useState('aadhaarFront');

  // Interactive templates to simulate file capture on mobile
  const mockFiles = {
    photo: { name: 'ravi_avatar.jpg', uri: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200', type: 'image/jpeg' },
    aadhaarFront: { name: 'aadhaar_front.jpg', uri: 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=600', type: 'image/jpeg' },
    aadhaarBack: { name: 'aadhaar_back.jpg', uri: 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=600', type: 'image/jpeg' },
    panCard: { name: 'pan_card.jpg', uri: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600', type: 'image/jpeg' },
    agreement: { name: 'rental_agreement.pdf', uri: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', type: 'application/pdf' },
  };

  const handleUpload = async () => {
    if (!tenantId) {
      Alert.alert('Error', 'Tenant identity not resolved.');
      return;
    }

    const fileMeta = mockFiles[selectedDocKey];
    setUploading(true);
    try {
      // Direct API call using our service layer
      await tenantService.uploadDocument(
        tenantId,
        selectedDocKey,
        fileMeta.uri,
        fileMeta.name,
        fileMeta.type
      );

      Alert.alert('Upload Success', `${selectedDocKey} uploaded successfully to Google Drive / Server.`);
      if (onBack) onBack();
    } catch (e) {
      console.error(e);
      Alert.alert('Upload Failed', e.response?.data?.message || 'Error occurred during upload.');
    } finally {
      setUploading(false);
    }
  };

  const docTypes = [
    { key: 'photo', label: 'Profile Avatar' },
    { key: 'aadhaarFront', label: 'Aadhaar Card (Front)' },
    { key: 'aadhaarBack', label: 'Aadhaar Card (Back)' },
    { key: 'panCard', label: 'PAN Card Card' },
    { key: 'agreement', label: 'Rental Agreement (Signed)' }
  ];

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <TouchableOpacity style={styles.backButton} onPress={() => navigation.goBack()}>
          <Text style={styles.backButtonText}>← BACK TO PROFILE</Text>
        </TouchableOpacity>

        <View style={styles.header}>
          <Text style={styles.title}>Upload Identity Documents</Text>
          <Text style={styles.sub}>Choose a document slot and select a simulated template to upload directly to the landlord's records.</Text>
        </View>

        <View style={styles.slotsCard}>
          <Text style={styles.sectionTitle}>1. Select Slot</Text>
          {docTypes.map((type) => (
            <TouchableOpacity
              key={type.key}
              style={[styles.slotItem, selectedDocKey === type.key && styles.slotItemActive]}
              onPress={() => setSelectedDocKey(type.key)}
              disabled={uploading}
            >
              <View style={[styles.radio, selectedDocKey === type.key && styles.radioActive]} />
              <Text style={[styles.slotLabel, selectedDocKey === type.key && styles.slotLabelActive]}>
                {type.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <View style={styles.previewCard}>
          <Text style={styles.sectionTitle}>2. Attachment Preview</Text>
          <View style={styles.fileDetails}>
            <Text style={styles.metaLbl}>Filename:</Text>
            <Text style={styles.metaVal}>{mockFiles[selectedDocKey].name}</Text>
            <Text style={styles.metaLbl}>Type:</Text>
            <Text style={styles.metaVal}>{mockFiles[selectedDocKey].type}</Text>
          </View>
        </View>

        <TouchableOpacity
          style={[styles.uploadBtn, uploading && styles.uploadBtnDisabled]}
          onPress={handleUpload}
          disabled={uploading}
        >
          {uploading ? (
            <ActivityIndicator color="#FFFFFF" />
          ) : (
            <Text style={styles.uploadBtnText}>Submit to Rentify Server</Text>
          )}
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  content: {
    padding: 24,
    gap: 20,
  },
  backButton: {
    paddingVertical: 8,
    alignSelf: 'flex-start',
  },
  backButtonText: {
    color: '#64748B',
    fontWeight: '700',
    fontSize: 12,
  },
  header: {
    marginBottom: 8,
  },
  title: {
    fontSize: 22,
    fontWeight: '800',
    color: '#0F172A',
    marginBottom: 6,
  },
  sub: {
    fontSize: 13,
    color: '#64748B',
    lineHeight: 18,
  },
  slotsCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 12,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#94A3B8',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
  },
  slotItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    backgroundColor: '#FFFFFF',
    gap: 12,
  },
  slotItemActive: {
    borderColor: '#4F46E5',
    backgroundColor: '#EEF2FF',
  },
  radio: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2,
    borderColor: '#CBD5E1',
    backgroundColor: '#FFFFFF',
  },
  radioActive: {
    borderColor: '#4F46E5',
    backgroundColor: '#4F46E5',
  },
  slotLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: '#475569',
  },
  slotLabelActive: {
    color: '#4F46E5',
    fontWeight: '700',
  },
  previewCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 12,
  },
  fileDetails: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  metaLbl: {
    fontSize: 13,
    color: '#94A3B8',
    width: '30%',
  },
  metaVal: {
    fontSize: 13,
    fontWeight: '600',
    color: '#0F172A',
    width: '60%',
  },
  uploadBtn: {
    height: 54,
    backgroundColor: '#4F46E5',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 10,
    shadowColor: '#4F46E5',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 3,
  },
  uploadBtnDisabled: {
    opacity: 0.75,
  },
  uploadBtnText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
});

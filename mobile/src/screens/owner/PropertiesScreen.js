import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, TextInput, ActivityIndicator, Alert, Modal, SafeAreaView } from 'react-native';
import { propertyService } from '../../services/api';

export default function PropertiesScreen({ route, navigation }) {
  const [loading, setLoading] = useState(true);
  const [properties, setProperties] = useState([]);
  const [expandedPropId, setExpandedPropId] = useState(null);

  // Form states
  const [showAddProp, setShowAddProp] = useState(false);
  const [newProp, setNewProp] = useState({ name: '', location: '', type: 'Residential' });

  const [showAddRoom, setShowAddRoom] = useState(false);
  const [selectedPropId, setSelectedPropId] = useState(null);
  const [newRoom, setNewRoom] = useState({ roomNumber: '', type: 'Single Room', floor: 'Ground' });
  const [showEditProp, setShowEditProp] = useState(false);
  const [editPropId, setEditPropId] = useState(null);
  const [editPropForm, setEditPropForm] = useState({ name: '', type: 'Residential', totalRooms: '10', address: '', description: '', floors: '1' });

  useEffect(() => {
    fetchProperties();
    if (route.params?.openAddProperty) {
      setShowAddProp(true);
    }
  }, [route.params]);

  const fetchProperties = async () => {
    try {
      setLoading(true);
      const data = await propertyService.getProperties();
      setProperties(data);
    } catch (e) {
      console.error(e);
      Alert.alert('Error', 'Failed to retrieve properties list.');
    } finally {
      setLoading(false);
    }
  };

  const handleAddProperty = async () => {
    if (!newProp.name.trim() || !newProp.location.trim()) {
      Alert.alert('Missing Fields', 'Please complete all fields.');
      return;
    }

    try {
      setLoading(true);
      await propertyService.createProperty(newProp);
      Alert.alert('Success', 'Property added successfully.');
      setShowAddProp(false);
      setNewProp({ name: '', location: '', type: 'Residential' });
      fetchProperties();
    } catch (e) {
      Alert.alert('Error', 'Failed to create property.');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateProperty = async () => {
    if (!editPropForm.name.trim()) {
      Alert.alert('Validation Error', 'Property name is required.');
      return;
    }
    try {
      setLoading(true);
      const parsedData = {
        ...editPropForm,
        totalRooms: editPropForm.totalRooms ? parseInt(editPropForm.totalRooms, 10) : 0,
        floors: editPropForm.floors ? parseInt(editPropForm.floors, 10) : 1
      };
      await propertyService.updateProperty(editPropId, parsedData);
      Alert.alert('Success', 'Property updated successfully!');
      setShowEditProp(false);
      fetchProperties();
    } catch (e) {
      console.error(e);
      Alert.alert('Error', 'Failed to update property details.');
    } finally {
      setLoading(false);
    }
  };

  const handleAddRoom = async () => {
    if (!newRoom.roomNumber.trim()) {
      Alert.alert('Missing Fields', 'Please enter a room number.');
      return;
    }

    try {
      setLoading(true);
      await propertyService.createRoom(selectedPropId, {
        roomNumber: newRoom.roomNumber.trim(),
        type: newRoom.type,
        floor: newRoom.floor
      });
      Alert.alert('Success', `Room ${newRoom.roomNumber} added successfully.`);
      setShowAddRoom(false);
      setNewRoom({ roomNumber: '', type: 'Single Room', floor: 'Ground' });
      fetchProperties();
    } catch (e) {
      Alert.alert('Error', 'Failed to add room.');
    } finally {
      setLoading(false);
    }
  };

  if (loading && properties.length === 0) {
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
        <Text style={styles.title}>Properties</Text>
        <TouchableOpacity style={styles.addButton} onPress={() => setShowAddProp(true)}>
          <Text style={styles.addButtonText}>+ New Property</Text>
        </TouchableOpacity>
      </View>

      <ScrollView contentContainerStyle={styles.listContent}>
        {properties.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyText}>No properties added yet. Tap "New Property" to begin.</Text>
          </View>
        ) : (
          properties.map((p) => {
            const isExpanded = expandedPropId === p.id;
            return (
              <View key={p.id} style={styles.propCard}>
                <TouchableOpacity 
                  style={styles.propHeader}
                  onPress={() => setExpandedPropId(isExpanded ? null : p.id)}
                  activeOpacity={0.7}
                >
                  <View>
                    <Text style={styles.propName}>{p.name}</Text>
                    <Text style={styles.propLocation}>📍 {p.location} • {p.type}</Text>
                  </View>
                  <Text style={styles.expandArrow}>{isExpanded ? '▲' : '▼'}</Text>
                </TouchableOpacity>

                {isExpanded && (
                  <View style={styles.propDetails}>
                    <View style={styles.divider} />
                    <View style={styles.roomsHeader}>
                      <Text style={styles.roomsTitle}>Rooms ({p.rooms ? p.rooms.length : 0})</Text>
                      <View style={{ flexDirection: 'row', gap: 8 }}>
                        <TouchableOpacity 
                          style={[styles.addRoomBtn, { backgroundColor: '#F1F5F9', borderWidth: 1, borderColor: '#CBD5E1' }]}
                          onPress={() => {
                            setEditPropId(p.id);
                            setEditPropForm({
                              name: p.name,
                              type: p.type,
                              totalRooms: p.totalRooms ? p.totalRooms.toString() : '0',
                              address: p.address || p.location || '',
                              description: p.description || '',
                              floors: p.floors ? p.floors.toString() : '1'
                            });
                            setShowEditProp(true);
                          }}
                        >
                          <Text style={[styles.addRoomBtnText, { color: '#475569' }]}>Edit Complex</Text>
                        </TouchableOpacity>
                        <TouchableOpacity 
                          style={styles.addRoomBtn}
                          onPress={() => {
                            setSelectedPropId(p.id);
                            setShowAddRoom(true);
                          }}
                        >
                          <Text style={styles.addRoomBtnText}>+ Add Room</Text>
                        </TouchableOpacity>
                      </View>
                    </View>

                    <View style={styles.roomsGrid}>
                      {(!p.rooms || p.rooms.length === 0) ? (
                        <Text style={styles.emptyRoomsText}>No rooms configured inside this building yet.</Text>
                      ) : (
                        p.rooms.map((r) => (
                          <View key={r.id} style={[styles.roomItem, r.status === 'Occupied' ? styles.roomOccupied : styles.roomVacant]}>
                            <Text style={styles.roomNumber}>{r.roomNumber}</Text>
                            <Text style={styles.roomType}>{r.type}</Text>
                            <Text style={styles.roomStatus}>{r.status}</Text>
                          </View>
                        ))
                      )}
                    </View>
                  </View>
                )}
              </View>
            );
          })
        )}
      </ScrollView>

      {/* MODAL: ADD PROPERTY */}
      <Modal visible={showAddProp} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Add New Property</Text>
            
            <Text style={styles.label}>Property / Building Name</Text>
            <TextInput 
              style={styles.input} 
              placeholder="e.g. Dream Residency" 
              value={newProp.name}
              onChangeText={(t) => setNewProp({ ...newProp, name: t })}
            />

            <Text style={styles.label}>Location / Address</Text>
            <TextInput 
              style={styles.input} 
              placeholder="e.g. Sector 62, Noida" 
              value={newProp.location}
              onChangeText={(t) => setNewProp({ ...newProp, location: t })}
            />

            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.cancelBtn} onPress={() => setShowAddProp(false)}>
                <Text style={styles.cancelBtnText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.submitBtn} onPress={handleAddProperty}>
                <Text style={styles.submitBtnText}>Create Building</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      {/* MODAL: EDIT PROPERTY */}
      <Modal visible={showEditProp} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center' }} showsVerticalScrollIndicator={false}>
            <View style={styles.modalContent}>
              <Text style={styles.modalTitle}>Edit Complex Details</Text>
              
              <Text style={styles.label}>Building Name</Text>
              <TextInput 
                style={styles.input} 
                value={editPropForm.name}
                onChangeText={(t) => setEditPropForm({ ...editPropForm, name: t })}
              />

              <Text style={styles.label}>Address</Text>
              <TextInput 
                style={styles.input} 
                value={editPropForm.address}
                onChangeText={(t) => setEditPropForm({ ...editPropForm, address: t })}
              />

              <Text style={styles.label}>Description</Text>
              <TextInput 
                style={styles.input} 
                value={editPropForm.description}
                onChangeText={(t) => setEditPropForm({ ...editPropForm, description: t })}
              />

              <Text style={styles.label}>Floors</Text>
              <TextInput 
                style={styles.input} 
                keyboardType="numeric"
                value={editPropForm.floors}
                onChangeText={(t) => setEditPropForm({ ...editPropForm, floors: t })}
              />

              <Text style={styles.label}>Total Rooms/Units</Text>
              <TextInput 
                style={styles.input} 
                keyboardType="numeric"
                value={editPropForm.totalRooms}
                onChangeText={(t) => setEditPropForm({ ...editPropForm, totalRooms: t })}
              />

              <View style={styles.modalActions}>
                <TouchableOpacity style={styles.cancelBtn} onPress={() => setShowEditProp(false)}>
                  <Text style={styles.cancelBtnText}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.submitBtn} onPress={handleUpdateProperty}>
                  <Text style={styles.submitBtnText}>Save Changes</Text>
                </TouchableOpacity>
              </View>
            </View>
          </ScrollView>
        </View>
      </Modal>

      {/* MODAL: ADD ROOM */}
      <Modal visible={showAddRoom} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Configure New Room</Text>
            
            <Text style={styles.label}>Room Name / Number</Text>
            <TextInput 
              style={styles.input} 
              placeholder="e.g. 101, Room A" 
              value={newRoom.roomNumber}
              onChangeText={(t) => setNewRoom({ ...newRoom, roomNumber: t })}
            />

            <Text style={styles.label}>Room Category</Text>
            <View style={styles.catRow}>
              {['Single Room', 'Double Room', 'Flat (1BHK/2BHK)', 'Commercial'].map((cat) => (
                <TouchableOpacity 
                  key={cat} 
                  style={[styles.catBtn, newRoom.type === cat && styles.catBtnActive]}
                  onPress={() => setNewRoom({ ...newRoom, type: cat })}
                >
                  <Text style={[styles.catBtnText, newRoom.type === cat && styles.catBtnTextActive]}>{cat}</Text>
                </TouchableOpacity>
              ))}
            </View>

            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.cancelBtn} onPress={() => setShowAddRoom(false)}>
                <Text style={styles.cancelBtnText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.submitBtn} onPress={handleAddRoom}>
                <Text style={styles.submitBtnText}>Add Room Slot</Text>
              </TouchableOpacity>
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
  propCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    overflow: 'hidden',
  },
  propHeader: {
    padding: 20,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  propName: {
    fontSize: 16,
    fontWeight: '700',
    color: '#0F172A',
  },
  propLocation: {
    fontSize: 12,
    color: '#64748B',
    marginTop: 4,
  },
  expandArrow: {
    fontSize: 12,
    color: '#94A3B8',
  },
  propDetails: {
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  divider: {
    height: 1,
    backgroundColor: '#F1F5F9',
    marginBottom: 16,
  },
  roomsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  roomsTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#475569',
  },
  addRoomBtn: {
    backgroundColor: '#EEF2FF',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 14,
  },
  addRoomBtnText: {
    color: '#4F46E5',
    fontSize: 11,
    fontWeight: '700',
  },
  roomsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  roomItem: {
    width: '30%',
    padding: 12,
    borderRadius: 12,
    borderWidth: 1,
    alignItems: 'center',
  },
  roomVacant: {
    borderColor: '#A7F3D0',
    backgroundColor: '#ECFDF5',
  },
  roomOccupied: {
    borderColor: '#FED7AA',
    backgroundColor: '#FFF7ED',
  },
  roomNumber: {
    fontSize: 13,
    fontWeight: '700',
    color: '#1E293B',
  },
  roomType: {
    fontSize: 9,
    color: '#64748B',
    marginTop: 2,
  },
  roomStatus: {
    fontSize: 9,
    fontWeight: '700',
    color: '#475569',
    marginTop: 4,
  },
  emptyRoomsText: {
    color: '#94A3B8',
    fontSize: 12,
    paddingVertical: 10,
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
    justifyContent: 'center',
    padding: 24,
  },
  modalContent: {
    backgroundColor: '#FFFFFF',
    borderRadius: 24,
    padding: 24,
    gap: 16,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: '#0F172A',
    marginBottom: 8,
  },
  label: {
    fontSize: 12,
    fontWeight: '600',
    color: '#475569',
  },
  input: {
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    borderRadius: 12,
    padding: 12,
    fontSize: 14,
    color: '#0F172A',
  },
  catRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  catBtn: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  catBtnActive: {
    backgroundColor: '#EEF2FF',
    borderColor: '#4F46E5',
  },
  catBtnText: {
    fontSize: 11,
    color: '#475569',
  },
  catBtnTextActive: {
    color: '#4F46E5',
    fontWeight: '600',
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 12,
    marginTop: 10,
  },
  cancelBtn: {
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  cancelBtnText: {
    color: '#64748B',
    fontWeight: '600',
    fontSize: 13,
  },
  submitBtn: {
    backgroundColor: '#4F46E5',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 12,
  },
  submitBtnText: {
    color: '#FFFFFF',
    fontWeight: '700',
    fontSize: 13,
  },
});

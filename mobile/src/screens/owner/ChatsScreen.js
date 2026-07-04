import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, ActivityIndicator } from 'react-native';
import { chatService, tenantService } from '../../services/api';

export default function ChatsScreen({ navigation }) {
  const [loading, setLoading] = useState(true);
  const [chatList, setChatList] = useState([]);

  useEffect(() => {
    fetchChats();
    const unsubscribe = navigation.addListener('focus', () => {
      fetchChats();
    });
    return unsubscribe;
  }, [navigation]);

  const fetchChats = async () => {
    try {
      setLoading(true);
      const chats = await chatService.getChats();
      const tenants = await tenantService.getTenants();

      // Merge tenant name with chat object
      const formatted = chats.map(c => {
        const tenant = tenants.find(t => t.id === c.tenantId);
        const lastMsg = c.messages.length > 0 ? c.messages[c.messages.length - 1] : null;
        
        // Count unread (sent by tenant but seen is false)
        const unreadCount = c.messages.filter(m => m.sender === 'tenant' && !m.seen).length;

        return {
          ...c,
          tenantName: tenant ? tenant.name : 'Unknown Tenant',
          roomNumber: tenant ? tenant.roomNumber : '',
          lastMessageText: lastMsg ? lastMsg.text : 'No messages yet.',
          lastMessageTime: lastMsg ? lastMsg.timestamp : null,
          unreadCount
        };
      });

      setChatList(formatted);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  if (loading && chatList.length === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#4F46E5" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Text style={styles.title}>Tenant Messages</Text>
        <Text style={styles.sub}>Respond to tenant maintenance tickets and questions</Text>
      </View>

      <View style={styles.list}>
        {chatList.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyText}>No active conversations found.</Text>
          </View>
        ) : (
          chatList.map((chat) => (
            <TouchableOpacity
              key={chat.id || chat.tenantId}
              style={styles.chatItem}
              onPress={() => navigation.navigate('ChatConversation', { tenantId: chat.tenantId, tenantName: chat.tenantName })}
              activeOpacity={0.7}
            >
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>{chat.tenantName[0].toUpperCase()}</Text>
              </View>
              <View style={styles.info}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                  <Text style={styles.name}>{chat.tenantName}</Text>
                  {chat.lastMessageTime && (
                    <Text style={styles.time}>
                      {new Date(chat.lastMessageTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </Text>
                  )}
                </View>
                <Text style={styles.room}>Room {chat.roomNumber}</Text>
                <Text style={styles.lastMsg} numberOfLines={1}>{chat.lastMessageText}</Text>
              </View>
              {chat.unreadCount > 0 && (
                <View style={styles.badge}>
                  <Text style={styles.badgeText}>{chat.unreadCount}</Text>
                </View>
              )}
            </TouchableOpacity>
          ))
        )}
      </View>
    </ScrollView>
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
  content: {
    padding: 24,
    gap: 20,
  },
  header: {
    marginBottom: 4,
  },
  title: {
    fontSize: 22,
    fontWeight: '800',
    color: '#0F172A',
  },
  sub: {
    fontSize: 13,
    color: '#64748B',
    marginTop: 4,
  },
  list: {
    gap: 12,
  },
  chatItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 16,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 16,
  },
  avatar: {
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
    gap: 2,
  },
  name: {
    fontSize: 15,
    fontWeight: '700',
    color: '#0F172A',
  },
  room: {
    fontSize: 11,
    color: '#64748B',
  },
  lastMsg: {
    fontSize: 13,
    color: '#475569',
    marginTop: 4,
  },
  time: {
    fontSize: 10,
    color: '#94A3B8',
  },
  badge: {
    backgroundColor: '#4F46E5',
    width: 20,
    height: 20,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 10,
    fontWeight: '700',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyText: {
    fontSize: 13,
    color: '#94A3B8',
  },
});

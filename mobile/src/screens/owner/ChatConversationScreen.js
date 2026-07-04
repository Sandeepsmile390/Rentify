import React, { useState, useEffect, useRef } from 'react';
import { StyleSheet, Text, View, ScrollView, TextInput, TouchableOpacity, KeyboardAvoidingView, Platform, ActivityIndicator, SafeAreaView } from 'react-native';
import { chatService } from '../../services/api';

export default function ChatConversationScreen({ route, navigation }) {
  const { tenantId, tenantName } = route.params || {};
  const [loading, setLoading] = useState(true);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const scrollViewRef = useRef();

  useEffect(() => {
    fetchConversation();
    const interval = setInterval(fetchConversation, 4000);
    return () => clearInterval(interval);
  }, [tenantId]);

  const fetchConversation = async () => {
    if (!tenantId) return;
    try {
      const chats = await chatService.getChats();
      const match = chats.find(c => c.tenantId === tenantId);
      if (match) {
        setMessages(match.messages);
        await chatService.markSeen(tenantId, 'owner');
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleSend = async () => {
    if (!text.trim()) return;
    const msgText = text;
    setText('');

    try {
      await chatService.sendMessage(tenantId, 'owner', msgText);
      fetchConversation();
    } catch (e) {
      console.error(e);
    }
  };

  const handleSendAttachment = async (type) => {
    try {
      const name = type === 'image' ? 'property_preview.jpg' : 'receipt_updated.pdf';
      await chatService.sendMessage(tenantId, 'owner', `Sent a ${type}`, name, type);
      fetchConversation();
    } catch (e) {
      console.error(e);
    }
  };

  if (loading && messages.length === 0) {
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
          <Text style={styles.backBtnText}>← Messages</Text>
        </TouchableOpacity>
        <Text style={styles.title}>{tenantName || 'Tenant Chat'}</Text>
      </View>

      <KeyboardAvoidingView 
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={90}
      >
        <ScrollView
          ref={scrollViewRef}
          style={styles.chatList}
          contentContainerStyle={styles.chatListContent}
          onContentSizeChange={() => scrollViewRef.current && scrollViewRef.current.scrollToEnd({ animated: true })}
        >
          {messages.length === 0 ? (
            <View style={styles.emptyState}>
              <Text style={styles.emptyText}>No messages yet. Send a response to start chatting.</Text>
            </View>
          ) : (
            messages.map((msg, index) => {
              const isMe = msg.sender === 'owner';
              return (
                <View 
                  key={msg.id || index} 
                  style={[
                    styles.msgBubble, 
                    isMe ? styles.msgSent : styles.msgReceived
                  ]}
                >
                  {msg.attachment ? (
                    <View style={styles.attachmentBox}>
                      <Text style={styles.attachmentLabel}>📎 {msg.attachment}</Text>
                      {msg.attachmentType === 'image' && (
                        <View style={styles.mockImgPlaceholder}>
                          <Text style={styles.mockImgText}>[Image Preview]</Text>
                        </View>
                      )}
                    </View>
                  ) : null}
                  <Text style={isMe ? styles.textSent : styles.textReceived}>{msg.text}</Text>
                  
                  <View style={styles.metaRow}>
                    <Text style={[styles.timeText, isMe ? styles.timeSent : styles.timeReceived]}>
                      {new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </Text>
                    {isMe && (
                      <Text style={styles.seenStatusText}>
                        {msg.seen ? '✓✓ Seen' : '✓ Sent'}
                      </Text>
                    )}
                  </View>
                </View>
              );
            })
          )}
        </ScrollView>

        {/* Input row */}
        <View style={styles.inputRow}>
          <TouchableOpacity style={styles.attachBtn} onPress={() => handleSendAttachment('image')}>
            <Text style={styles.attachBtnText}>📷</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.attachBtn} onPress={() => handleSendAttachment('document')}>
            <Text style={styles.attachBtnText}>📄</Text>
          </TouchableOpacity>
          <TextInput
            style={styles.input}
            placeholder="Type your reply..."
            placeholderTextColor="#94A3B8"
            value={text}
            onChangeText={setText}
          />
          <TouchableOpacity style={styles.sendBtn} onPress={handleSend}>
            <Text style={styles.sendBtnText}>Send</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F1F5F9',
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
  chatList: {
    flex: 1,
  },
  chatListContent: {
    padding: 16,
    gap: 12,
  },
  msgBubble: {
    padding: 12,
    borderRadius: 16,
    maxWidth: '75%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 1,
    elevation: 1,
  },
  msgSent: {
    alignSelf: 'flex-end',
    backgroundColor: '#4F46E5',
    borderBottomRightRadius: 4,
  },
  msgReceived: {
    alignSelf: 'flex-start',
    backgroundColor: '#FFFFFF',
    borderBottomLeftRadius: 4,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  textSent: {
    color: '#FFFFFF',
    fontSize: 14,
    lineHeight: 18,
  },
  textReceived: {
    color: '#0F172A',
    fontSize: 14,
    lineHeight: 18,
  },
  metaRow: {
    flexDirection: 'row',
    alignSelf: 'flex-end',
    alignItems: 'center',
    marginTop: 4,
    gap: 4,
  },
  timeText: {
    fontSize: 9,
  },
  timeSent: {
    color: 'rgba(255, 255, 255, 0.7)',
  },
  timeReceived: {
    color: '#94A3B8',
  },
  seenStatusText: {
    fontSize: 9,
    color: 'rgba(255, 255, 255, 0.8)',
    fontWeight: '600',
  },
  inputRow: {
    backgroundColor: '#FFFFFF',
    padding: 12,
    flexDirection: 'row',
    gap: 8,
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: '#E2E8F0',
  },
  attachBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#F1F5F9',
    alignItems: 'center',
    justifyContent: 'center',
  },
  attachBtnText: {
    fontSize: 14,
  },
  input: {
    flex: 1,
    backgroundColor: '#F8FAFC',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    color: '#0F172A',
    fontSize: 14,
  },
  sendBtn: {
    backgroundColor: '#4F46E5',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
  },
  sendBtnText: {
    color: '#FFFFFF',
    fontWeight: '700',
    fontSize: 13,
  },
  attachmentBox: {
    backgroundColor: 'rgba(0, 0, 0, 0.05)',
    padding: 8,
    borderRadius: 8,
    marginBottom: 6,
  },
  attachmentLabel: {
    fontSize: 12,
    fontWeight: '600',
  },
  mockImgPlaceholder: {
    width: 150,
    height: 80,
    backgroundColor: '#CBD5E1',
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  mockImgText: {
    fontSize: 10,
    color: '#475569',
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 100,
  },
  emptyText: {
    fontSize: 13,
    color: '#94A3B8',
    textAlign: 'center',
    lineHeight: 18,
  },
});

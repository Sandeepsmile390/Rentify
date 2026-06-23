import React, { useState, useEffect, useRef } from 'react';
import { StyleSheet, Text, View, ScrollView, TextInput, TouchableOpacity, Image, KeyboardAvoidingView, Platform, ActivityIndicator } from 'react-native';
import { chatService } from '../services/api';

export default function ChatScreen() {
  const [loading, setLoading] = useState(true);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const scrollViewRef = useRef();

  const tenantId = 'tenant-1'; // Ravi Kumar demo

  useEffect(() => {
    fetchChatHistory();
    // Poll messages every 4 seconds for real-time feel
    const interval = setInterval(fetchChatHistory, 4000);
    return () => clearInterval(interval);
  }, []);

  const fetchChatHistory = async () => {
    try {
      const chats = await chatService.getChats();
      const myChat = chats.find(c => c.tenantId === tenantId);
      if (myChat) {
        setMessages(myChat.messages);
        // Mark as seen on open/update
        await chatService.markSeen(tenantId, 'tenant');
      }
    } catch (error) {
      console.error('Error fetching chat messages:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSend = async () => {
    if (!text.trim()) return;

    const msgText = text;
    setText('');

    try {
      await chatService.sendMessage(tenantId, 'tenant', msgText);
      fetchChatHistory();
    } catch (error) {
      console.error('Error sending message:', error);
    }
  };

  const handleSendAttachment = async (type) => {
    // Simulate uploading attachment
    try {
      const name = type === 'image' ? 'screenshot_utility.png' : 'agreement_signed.pdf';
      await chatService.sendMessage(tenantId, 'tenant', `Sent a ${type}`, name, type);
      fetchChatHistory();
    } catch (error) {
      console.error('Error sending attachment:', error);
    }
  };

  if (loading && messages.length === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6366F1" />
      </View>
    );
  }

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={90}
    >
      <ScrollView 
        ref={scrollViewRef}
        style={styles.chatList}
        contentContainerStyle={styles.chatListContent}
        onContentSizeChange={() => scrollViewRef.current.scrollToEnd({ animated: true })}
      >
        {messages.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyText}>No messages yet. Send a message to start chatting with the owner.</Text>
          </View>
        ) : (
          messages.map((msg, index) => {
            const isMe = msg.sender === 'tenant';
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
                        <Text style={styles.mockImgText}>[Simulated Image Preview]</Text>
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
          placeholder="Type your message..."
          placeholderTextColor="#94A3B8"
          value={text}
          onChangeText={setText}
        />
        <TouchableOpacity style={styles.sendBtn} onPress={handleSend}>
          <Text style={styles.sendBtnText}>Send</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F1F5F9', // light grey chat background
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
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
    backgroundColor: '#6366F1', // Indigo
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
    backgroundColor: '#6366F1',
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

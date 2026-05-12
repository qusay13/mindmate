import React, { useState, useEffect, useRef } from 'react';
import { chatAPI, WS_BASE_URL } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { Send, MessageCircle, ArrowLeft, Loader } from 'lucide-react';

const ChatPage = () => {
  const { user } = useAuth();
  const [conversations, setConversations] = useState([]);
  const [selectedConv, setSelectedConv] = useState(null);
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sendingMsg, setSendingMsg] = useState(false);
  const [isOtherTyping, setIsOtherTyping] = useState(false);
  const [typingTimeout, setTypingTimeout] = useState(null);
  const wsRef = useRef(null);
  const messagesEndRef = useRef(null);
  const token = localStorage.getItem('mindmate_token');

  useEffect(() => {
    fetchConversations();
    return () => { if (wsRef.current) wsRef.current.close(); };
  }, []);

  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages, isOtherTyping]);

  const fetchConversations = async () => {
    try {
      const res = await chatAPI.getConversations();
      setConversations(res.data);
    } catch (err) {
      console.error('Failed to load conversations', err);
    } finally {
      setLoading(false);
    }
  };

  const openConversation = async (conv) => {
    setSelectedConv(conv);
    setMessages([]);
    setIsOtherTyping(false);

    // Load history
    try {
      const res = await chatAPI.getMessages(conv.id);
      setMessages(res.data);
      
      // Mark last messages as read if they are not mine
      if (res.data.length > 0) {
        const lastMsg = res.data[res.data.length - 1];
        if (!isMine(lastMsg) && !lastMsg.is_seen) {
           // We'll send read receipts after websocket is open (handled in ws.onopen)
        }
      }
    } catch (err) {
      console.error('Failed to load messages', err);
    }

    // Close old WebSocket if any
    if (wsRef.current) wsRef.current.close();

    // Open WebSocket
    const ws = new WebSocket(`${WS_BASE_URL}chat/${conv.id}/?token=${token}`);
    ws.onopen = () => {
      console.log('WebSocket connected');
      // Send read receipts for all unread messages from other party
      setMessages(prev => {
        prev.filter(m => !isMine(m) && !m.is_seen).forEach(m => {
          ws.send(JSON.stringify({ type: 'read_receipt', message_id: m.id }));
        });
        return prev;
      });
    };
    ws.onmessage = (e) => {
      const data = JSON.parse(e.data);
      
      if (data.type === 'message') {
        setMessages(prev => [...prev, {
          id: data.id,
          sender_type: data.sender_type,
          sender_id: data.sender_id,
          content: data.message,
          created_at: data.created_at,
          is_seen: false,
        }]);
        
        // If message is from other party, send read receipt
        const myId = getMyId();
        const myRole = getMyRole();
        if (!(data.sender_type === myRole && String(data.sender_id) === String(myId))) {
          ws.send(JSON.stringify({ type: 'read_receipt', message_id: data.id }));
        }
      } else if (data.type === 'typing') {
        setIsOtherTyping(data.is_typing);
      } else if (data.type === 'read_receipt') {
        setMessages(prev => prev.map(m => 
          m.id === data.message_id ? { ...m, is_seen: true } : m
        ));
      }
    };
    ws.onerror = (e) => console.error('WebSocket error', e);
    ws.onclose = () => console.log('WebSocket closed');
    wsRef.current = ws;
  };

  const sendMessage = () => {
    if (!newMessage.trim() || !wsRef.current) return;
    setSendingMsg(true);
    try {
      wsRef.current.send(JSON.stringify({ type: 'message', message: newMessage.trim() }));
      setNewMessage('');
      // Stop typing status immediately when sending
      sendTypingStatus(false);
    } finally {
      setSendingMsg(false);
    }
  };

  const sendTypingStatus = (isTyping) => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ type: 'typing', is_typing: isTyping }));
    }
  };

  const handleInputChange = (e) => {
    setNewMessage(e.target.value);

    // Typing indicator logic
    if (typingTimeout) clearTimeout(typingTimeout);
    
    sendTypingStatus(true);
    
    setTypingTimeout(setTimeout(() => {
      sendTypingStatus(false);
    }, 2000));
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const getMyId = () => {
    if (!user) return null;
    return user.user_id || user.doctor_id;
  };

  const getMyRole = () => {
    if (!user) return null;
    return user.role === 'user' ? 'user' : 'doctor';
  };

  const isMine = (msg) => {
    const myId   = getMyId();
    const myRole = getMyRole();
    return msg.sender_type === myRole && String(msg.sender_id) === String(myId);
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading conversations...</p>
    </div>
  );

  return (
    <div className="dashboard-page fade-in" style={{ padding: 0, height: '100%' }}>
      <div style={{ display: 'flex', height: 'calc(100vh - 80px)', gap: 0 }}>

        {/* Conversations sidebar */}
        <div className="glass-card" style={{
          width: selectedConv ? '300px' : '100%',
          maxWidth: '360px',
          borderRadius: selectedConv ? '16px 0 0 16px' : '16px',
          overflowY: 'auto',
          flexShrink: 0,
          transition: 'width 0.3s ease'
        }}>
          <div className="card-header" style={{ padding: '1.25rem 1.5rem', borderBottom: '1px solid rgba(255,255,255,0.07)' }}>
            <MessageCircle size={18} className="accent" />
            <h3>Conversations</h3>
          </div>

          {conversations.length === 0 ? (
            <div style={{ padding: '2rem', textAlign: 'center', color: '#888' }}>
              <MessageCircle size={40} style={{ opacity: 0.3, marginBottom: '1rem' }} />
              <p>No conversations yet.</p>
            </div>
          ) : (
            conversations.map((conv) => (
              <div
                key={conv.id}
                onClick={() => openConversation(conv)}
                style={{
                  padding: '1rem 1.5rem',
                  cursor: 'pointer',
                  borderBottom: '1px solid rgba(255,255,255,0.05)',
                  background: selectedConv?.id === conv.id ? 'rgba(160,120,255,0.1)' : 'transparent',
                  transition: 'background 0.2s',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.75rem',
                }}
                onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.05)'}
                onMouseLeave={e => e.currentTarget.style.background = selectedConv?.id === conv.id ? 'rgba(160,120,255,0.1)' : 'transparent'}
              >
                <div style={{
                  width: 40, height: 40, borderRadius: '50%',
                  background: 'linear-gradient(135deg, #a78bfa, #7c3aed)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontWeight: 700, fontSize: '1rem', color: '#fff', flexShrink: 0
                }}>
                  {(conv.other_party?.name || 'U')[0].toUpperCase()}
                </div>
                <div style={{ overflow: 'hidden' }}>
                  <div style={{ fontWeight: 600, marginBottom: '0.2rem' }}>{conv.other_party?.name || 'Unknown'}</div>
                  <div style={{ fontSize: '0.8rem', color: '#888', textOverflow: 'ellipsis', whiteSpace: 'nowrap', overflow: 'hidden' }}>
                    {conv.last_message?.content || 'No messages yet'}
                  </div>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Chat area */}
        {selectedConv && (
          <div style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            background: 'rgba(20,18,30,0.7)',
            borderRadius: '0 16px 16px 0',
            backdropFilter: 'blur(12px)',
            border: '1px solid rgba(255,255,255,0.06)',
            borderLeft: 'none',
            overflow: 'hidden',
          }}>
            {/* Chat header */}
            <div style={{
              padding: '1rem 1.5rem',
              borderBottom: '1px solid rgba(255,255,255,0.07)',
              display: 'flex',
              alignItems: 'center',
              gap: '0.75rem',
              background: 'rgba(255,255,255,0.02)',
            }}>
              <button
                onClick={() => { setSelectedConv(null); if (wsRef.current) wsRef.current.close(); }}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#aaa', display: 'flex' }}
              >
                <ArrowLeft size={20} />
              </button>
              <div style={{
                width: 36, height: 36, borderRadius: '50%',
                background: 'linear-gradient(135deg, #a78bfa, #7c3aed)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontWeight: 700, color: '#fff'
              }}>
                {(selectedConv.other_party?.name || 'U')[0].toUpperCase()}
              </div>
              <div>
                <div style={{ fontWeight: 600 }}>{selectedConv.other_party?.name || 'Unknown'}</div>
                <div style={{ fontSize: '0.75rem', color: '#888', textTransform: 'capitalize' }}>
                  {selectedConv.other_party?.role}
                </div>
              </div>
            </div>

            {/* Messages */}
            <div style={{
              flex: 1,
              overflowY: 'auto',
              padding: '1.5rem',
              display: 'flex',
              flexDirection: 'column',
              gap: '0.75rem',
            }}>
              {messages.map((msg) => {
                const mine = isMine(msg);
                return (
                  <div key={msg.id} style={{
                    display: 'flex',
                    justifyContent: mine ? 'flex-end' : 'flex-start',
                  }}>
                    <div style={{
                      maxWidth: '65%',
                      padding: '0.65rem 1rem',
                      borderRadius: mine ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
                      background: mine
                        ? 'linear-gradient(135deg, #7c3aed, #a78bfa)'
                        : 'rgba(255,255,255,0.08)',
                      color: mine ? '#fff' : '#e2e8f0',
                      fontSize: '0.9rem',
                      lineHeight: 1.5,
                      wordBreak: 'break-word',
                    }}>
                      {msg.content}
                      <div style={{ 
                        fontSize: '0.7rem', 
                        marginTop: '0.3rem', 
                        opacity: 0.7, 
                        textAlign: 'right',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'flex-end',
                        gap: '4px'
                      }}>
                        {new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        {mine && (
                          <span style={{ color: msg.is_seen ? '#4ade80' : 'rgba(255,255,255,0.5)' }}>
                            {msg.is_seen ? '✓✓' : '✓'}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
              
              {isOtherTyping && (
                <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
                  <div style={{
                    padding: '0.65rem 1rem',
                    borderRadius: '16px 16px 16px 4px',
                    background: 'rgba(255,255,255,0.05)',
                    color: '#888',
                    fontSize: '0.8rem',
                    fontStyle: 'italic',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    <div className="typing-dot-container">
                      <div className="typing-dot"></div>
                      <div className="typing-dot"></div>
                      <div className="typing-dot"></div>
                    </div>
                    {selectedConv.other_party?.name} is typing...
                  </div>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Input */}
            <div style={{
              padding: '1rem 1.5rem',
              borderTop: '1px solid rgba(255,255,255,0.07)',
              display: 'flex',
              gap: '0.75rem',
              alignItems: 'flex-end',
              background: 'rgba(255,255,255,0.02)',
            }}>
              <textarea
                value={newMessage}
                onChange={handleInputChange}
                onKeyDown={handleKeyDown}
                placeholder="Type a message... (Enter to send)"
                rows={1}
                style={{
                  flex: 1,
                  background: 'rgba(255,255,255,0.07)',
                  border: '1px solid rgba(255,255,255,0.1)',
                  borderRadius: '12px',
                  padding: '0.75rem 1rem',
                  color: '#e2e8f0',
                  fontSize: '0.9rem',
                  resize: 'none',
                  outline: 'none',
                  lineHeight: 1.5,
                  maxHeight: '120px',
                  overflowY: 'auto',
                  fontFamily: 'inherit',
                }}
              />
              <button
                onClick={sendMessage}
                disabled={!newMessage.trim() || sendingMsg}
                className="btn-primary"
                style={{
                  padding: '0.75rem',
                  borderRadius: '12px',
                  minWidth: 'unset',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  opacity: !newMessage.trim() ? 0.5 : 1,
                  transition: 'opacity 0.2s',
                }}
              >
                {sendingMsg ? <Loader size={18} className="spin" /> : <Send size={18} />}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default ChatPage;

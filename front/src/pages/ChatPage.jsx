import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { chatAPI, WS_BASE_URL } from '../services/api';
import { useAuth } from '../context/AuthContext';
import {
  Send, MessageCircle, ArrowLeft, Loader,
  Paperclip, MoreVertical, Archive, Eye, EyeOff,
  Wifi, WifiOff, RefreshCw, Download, FileText
} from 'lucide-react';

// Self-contained UUID generator for optimistic UI
const generateUUID = () => {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
};

// Memoized single message bubble component to boost rendering speed
const MessageBubble = React.memo(({ msg, mine }) => {
  const renderMessageContent = () => {
    if (msg.status === 'uploading') {
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', minWidth: '180px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', opacity: 0.8, fontSize: '0.8rem' }}>
            <Loader size={14} className="spin" />
            <span>Uploading... {msg.progress || 0}%</span>
          </div>
          <div style={{ width: '100%', height: '4px', background: 'rgba(255,255,255,0.2)', borderRadius: '2px', overflow: 'hidden' }}>
            <div style={{ width: `${msg.progress || 0}%`, height: '100%', background: '#fff', transition: 'width 0.2s' }}></div>
          </div>
        </div>
      );
    }

    if (msg.status === 'failed') {
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', minWidth: '180px' }}>
          <span style={{ color: '#f87171', fontWeight: 600, fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '4px' }}>
            ⚠️ Upload Failed
          </span>
          {msg.onRetry && (
            <button
              onClick={msg.onRetry}
              style={{
                alignSelf: 'flex-start',
                background: 'rgba(248, 113, 113, 0.2)',
                border: '1px solid #f87171',
                color: '#fff',
                padding: '2px 8px',
                borderRadius: '4px',
                fontSize: '0.75rem',
                cursor: 'pointer',
                fontWeight: 600,
                display: 'flex',
                alignItems: 'center',
                gap: '4px'
              }}
            >
              <RefreshCw size={10} /> Retry
            </button>
          )}
        </div>
      );
    }

    if (msg.message_type === 'IMAGE') {
      return (
        <div 
          style={{ borderRadius: '8px', overflow: 'hidden', cursor: 'zoom-in', margin: '-4px -6px' }}
          onClick={() => window.open(msg.content, '_blank')}
        >
          <img
            src={msg.content}
            alt="Shared Image"
            style={{ maxWidth: '100%', maxHeight: '240px', objectFit: 'cover', display: 'block' }}
            loading="lazy"
          />
        </div>
      );
    }

    if (msg.message_type === 'FILE') {
      const fileName = msg.content.split('/').pop() || 'Shared Document';
      return (
        <a
          href={msg.content}
          target="_blank"
          rel="noopener noreferrer"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            color: '#38bdf8',
            textDecoration: 'none',
            fontWeight: 600,
            fontSize: '0.85rem'
          }}
        >
          <FileText size={20} style={{ color: '#38bdf8' }} />
          <span style={{ textDecoration: 'underline', wordBreak: 'break-all' }}>{fileName}</span>
          <Download size={14} style={{ marginLeft: 'auto', opacity: 0.8 }} />
        </a>
      );
    }

    return <span>{msg.content}</span>;
  };

  return (
    <div style={{
      maxWidth: '65%',
      padding: '0.65rem 1rem',
      borderRadius: mine ? '12px 12px 4px 12px' : '12px 12px 12px 4px',
      background: mine
        ? 'linear-gradient(135deg, #7c3aed, #a78bfa)'
        : 'rgba(255,255,255,0.08)',
      color: mine ? '#fff' : '#e2e8f0',
      fontSize: '0.9rem',
      lineHeight: 1.5,
      wordBreak: 'break-word',
      boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
      alignSelf: mine ? 'flex-end' : 'flex-start',
    }}>
      {renderMessageContent()}
      <div style={{
        fontSize: '0.65rem',
        marginTop: '0.3rem',
        opacity: 0.7,
        textAlign: 'right',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'flex-end',
        gap: '4px'
      }}>
        {new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        {mine && msg.status !== 'uploading' && msg.status !== 'failed' && (
          <span style={{ color: msg.is_seen ? '#4ade80' : 'rgba(255,255,255,0.5)', fontWeight: 'bold' }}>
            {msg.is_seen ? '✓✓' : '✓'}
          </span>
        )}
      </div>
    </div>
  );
});

MessageBubble.displayName = 'MessageBubble';

const ChatPage = () => {
  const { user } = useAuth();
  
  // Tabbed sidebar lists: Active vs Archived
  const [conversations, setConversations] = useState([]);
  const [archivedConvs, setArchivedConvs] = useState([]);
  const [activeTab, setActiveTab] = useState('active'); // 'active' | 'archived'

  const [selectedConv, setSelectedConv] = useState(null);
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  
  const [loading, setLoading] = useState(true);
  const [loadingHistory, setLoadingHistory] = useState(false);
  const [sendingMsg, setSendingMsg] = useState(false);
  const [isOtherTyping, setIsOtherTyping] = useState(false);
  
  const [nextCursor, setNextCursor] = useState(null);
  const [isOffline, setIsOffline] = useState(!navigator.onLine);
  const [wsConnected, setWsConnected] = useState(false);
  const [showMenu, setShowMenu] = useState(false);
  
  // Map to store File objects by client_msg_id for retry mechanism
  const [tempFiles, setTempFiles] = useState({});

  const wsRef = useRef(null);
  const messagesEndRef = useRef(null);
  const messageListRef = useRef(null);
  const fileInputRef = useRef(null);
  
  const selectedConvRef = useRef(null);
  const reconnectTimeoutRef = useRef(null);
  const reconnectDelayRef = useRef(1000);
  const lastTypingSentRef = useRef(0);
  const typingTimeoutRef = useRef(null);

  const token = localStorage.getItem('mindmate_token');

  // Keep ref in sync for WebSockets close callback check
  useEffect(() => {
    selectedConvRef.current = selectedConv;
  }, [selectedConv]);

  // Handle Online/Offline browser triggers
  useEffect(() => {
    const goOnline = () => setIsOffline(false);
    const goOffline = () => setIsOffline(true);
    window.addEventListener('online', goOnline);
    window.addEventListener('offline', goOffline);
    return () => {
      window.removeEventListener('online', goOnline);
      window.removeEventListener('offline', goOffline);
    };
  }, []);

  // Fetch both active and archived chats
  const fetchConversations = async () => {
    try {
      const [activeRes, archivedRes] = await Promise.all([
        chatAPI.getConversations({ archived: false }),
        chatAPI.getConversations({ archived: true })
      ]);
      setConversations(activeRes.data);
      setArchivedConvs(archivedRes.data);
    } catch (err) {
      console.error('Failed to load conversations', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConversations();
    return () => {
      if (wsRef.current) wsRef.current.close();
      if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current);
    };
  }, []);

  // Auto scroll to bottom when new messages arrive or when first opening chat
  useEffect(() => {
    if (messagesEndRef.current && !loadingHistory) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages, isOtherTyping, loadingHistory]);

  const getMyId = useCallback(() => {
    if (!user) return null;
    return user.user_id || user.doctor_id;
  }, [user]);

  const getMyRole = useCallback(() => {
    if (!user) return null;
    return user.role === 'user' ? 'user' : 'doctor';
  }, [user]);

  const isMine = useCallback((msg) => {
    const myId = getMyId();
    const myRole = getMyRole();
    return msg.sender_type === myRole && String(msg.sender_id) === String(myId);
  }, [getMyId, getMyRole]);

  // Strict sorting and deduplication
  const deduplicateAndSort = useCallback((msgs) => {
    const map = new Map();
    msgs.forEach(m => {
      const key = m.client_msg_id || m.id;
      if (!map.has(key) || (m.id && !map.get(key).id)) {
        map.set(key, m);
      }
    });
    return Array.from(map.values()).sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  }, []);

  // Mark all unread messages as read
  const triggerMarkAsRead = async (convId) => {
    if (document.visibilityState === 'visible' && convId) {
      try {
        await chatAPI.markConversationRead(convId);
        if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
          wsRef.current.send(JSON.stringify({ type: 'messages_read' }));
        }
        // Locally zero the unread count in conversations state
        setConversations(prev => prev.map(c => c.id === convId ? { ...c, unread_count: 0 } : c));
        setArchivedConvs(prev => prev.map(c => c.id === convId ? { ...c, unread_count: 0 } : c));
      } catch (err) {
        console.error('Failed to mark conversation read', err);
      }
    }
  };

  // VisibilityChange listener
  useEffect(() => {
    const handleVisibility = () => {
      if (selectedConv) {
        triggerMarkAsRead(selectedConv.id);
      }
    };
    document.addEventListener('visibilitychange', handleVisibility);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibility);
    };
  }, [selectedConv]);

  // WebSocket connection with Exponential Backoff strategy
  const connectWebSocket = (convId) => {
    if (wsRef.current) wsRef.current.close();
    if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current);

    const ws = new WebSocket(`${WS_BASE_URL}chat/${convId}/?token=${token}`);
    wsRef.current = ws;

    ws.onopen = () => {
      console.log('WebSocket connected');
      setWsConnected(true);
      reconnectDelayRef.current = 1000; // Reset exponential reconnect delay
      triggerMarkAsRead(convId);
    };

    ws.onmessage = (e) => {
      const data = JSON.parse(e.data);

      if (data.type === 'message') {
        const newMsg = {
          id: data.id,
          client_msg_id: data.client_msg_id,
          sender_type: data.sender_type,
          sender_id: data.sender_id,
          content: data.message,
          message_type: data.message_type || 'TEXT',
          created_at: data.created_at,
          is_seen: false,
        };

        setMessages(prev => deduplicateAndSort([...prev, newMsg]));

        // Send read receipt if it's from the other party and visible
        if (!isMine(newMsg)) {
          if (document.visibilityState === 'visible') {
            ws.send(JSON.stringify({ type: 'read_receipt', message_id: data.id }));
          }
        }
      } else if (data.type === 'typing') {
        setIsOtherTyping(data.is_typing);
      } else if (data.type === 'read_receipt') {
        setMessages(prev => prev.map(m =>
          m.id === data.message_id ? { ...m, is_seen: true } : m
        ));
      } else if (data.type === 'messages_read') {
        // Mark all my sent messages as read immediately
        setMessages(prev => prev.map(m =>
          isMine(m) ? { ...m, is_seen: true } : m
        ));
      } else if (data.type === 'user_status') {
        // Presence Status update handler (Online/Offline)
        const updatePresence = (list) => list.map(c => {
          if (c.other_party && String(c.other_party.id) === String(data.user_id)) {
            return {
              ...c,
              other_party: {
                ...c.other_party,
                is_online: data.status === 'online',
                last_seen: data.status === 'offline' ? new Date().toISOString() : c.other_party.last_seen
              }
            };
          }
          return c;
        });

        setConversations(updatePresence);
        setArchivedConvs(updatePresence);

        setSelectedConv(prev => {
          if (prev && prev.other_party && String(prev.other_party.id) === String(data.user_id)) {
            return {
              ...prev,
              other_party: {
                ...prev.other_party,
                is_online: data.status === 'online',
                last_seen: data.status === 'offline' ? new Date().toISOString() : prev.other_party.last_seen
              }
            };
          }
          return prev;
        });
      } else if (data.type === 'message_ack') {
        // Acknowledge sending and replace temporary id with backend uuid
        setMessages(prev => prev.map(m =>
          m.client_msg_id === data.client_msg_id
            ? { ...m, id: data.message_id, status: 'success' }
            : m
        ));
        // Refresh conversations to update last message description in sidebar
        fetchConversations();
      }
    };

    ws.onerror = (e) => console.error('WebSocket error', e);

    ws.onclose = () => {
      setWsConnected(false);
      // Scheduled reconnect with exponential delay
      if (selectedConvRef.current && selectedConvRef.current.id === convId) {
        const delay = reconnectDelayRef.current;
        reconnectDelayRef.current = Math.min(delay * 2, 30000); // Caps at 30 seconds
        console.log(`WebSocket closed. Reconnecting in ${delay}ms...`);
        reconnectTimeoutRef.current = setTimeout(() => {
          connectWebSocket(convId);
        }, delay);
      }
    };
  };

  const openConversation = async (conv) => {
    setSelectedConv(conv);
    setMessages([]);
    setIsOtherTyping(false);
    setNextCursor(null);
    setLoadingHistory(true);
    setShowMenu(false);

    try {
      const res = await chatAPI.getMessages(conv.id);
      if (res.data && res.data.results) {
        // Reverse pagination since backend sends -created_at (newest first)
        const chatHistory = res.data.results.reverse();
        setMessages(deduplicateAndSort(chatHistory));
        setNextCursor(res.data.next);
      } else {
        setMessages(deduplicateAndSort(res.data));
      }
    } catch (err) {
      console.error('Failed to load messages', err);
    } finally {
      setLoadingHistory(false);
    }

    connectWebSocket(conv.id);
  };

  // Scroll Restoration Logic for Infinite Scroll
  const handleScroll = async () => {
    const container = messageListRef.current;
    if (!container || loadingHistory || !nextCursor) return;

    if (container.scrollTop <= 30) {
      setLoadingHistory(true);
      try {
        const oldHeight = container.scrollHeight;
        const res = await chatAPI.getMessagesCursor(nextCursor);
        if (res.data && res.data.results) {
          const olderMessages = res.data.results.reverse();
          setMessages(prev => deduplicateAndSort([...olderMessages, ...prev]));
          setNextCursor(res.data.next);
          
          // Fix scroll position instantly
          setTimeout(() => {
            const newHeight = container.scrollHeight;
            container.scrollTop += (newHeight - oldHeight);
          }, 0);
        }
      } catch (err) {
        console.error('Failed to load older messages', err);
      } finally {
        setLoadingHistory(false);
      }
    }
  };

  const sendTypingStatus = (isTyping) => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ type: isTyping ? 'typing' : 'stop_typing' }));
    }
  };

  const handleInputChange = (e) => {
    setNewMessage(e.target.value);

    const now = Date.now();
    // Debounce: send typing updates at most once every 1000ms
    if (now - lastTypingSentRef.current > 1000) {
      sendTypingStatus(true);
      lastTypingSentRef.current = now;
    }

    if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
    typingTimeoutRef.current = setTimeout(() => {
      sendTypingStatus(false);
    }, 2000);
  };

  const sendMessage = () => {
    if (!newMessage.trim() || !wsRef.current) return;
    setSendingMsg(true);
    const clientMsgId = generateUUID();

    try {
      wsRef.current.send(JSON.stringify({
        type: 'message',
        message: newMessage.trim(),
        message_type: 'TEXT',
        client_msg_id: clientMsgId
      }));
      setNewMessage('');
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
      sendTypingStatus(false);
    } finally {
      setSendingMsg(false);
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  // Perform backend file upload and emit event
  const performUpload = async (tempMsg) => {
    const formData = new FormData();
    formData.append('file', tempMsg.fileRef);

    try {
      const res = await chatAPI.uploadChatFile(formData, (progressEvent) => {
        const percent = Math.round((progressEvent.loaded * 100) / progressEvent.total);
        setMessages(prev => prev.map(m =>
          m.client_msg_id === tempMsg.client_msg_id ? { ...m, progress: percent } : m
        ));
      });

      const fileUrl = res.data.file_url;
      const msgType = res.data.message_type;

      if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
        wsRef.current.send(JSON.stringify({
          type: 'message',
          message: fileUrl,
          message_type: msgType,
          client_msg_id: tempMsg.client_msg_id
        }));
      }
    } catch (err) {
      console.error('File upload failed', err);
      setMessages(prev => prev.map(m =>
        m.client_msg_id === tempMsg.client_msg_id ? { ...m, status: 'failed' } : m
      ));
    }
  };

  // Upload Retry logic
  const handleRetryUpload = useCallback((clientMsgId, file) => {
    if (!file) return;
    setMessages(prev => prev.map(m =>
      m.client_msg_id === clientMsgId ? { ...m, status: 'uploading', progress: 0 } : m
    ));
    performUpload({ client_msg_id: clientMsgId, fileRef: file });
  }, []);

  const triggerFileUpload = (file) => {
    // Whitelist check
    const ALLOWED_EXTS = ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'webp'];
    const ext = file.name.split('.').pop().toLowerCase();
    if (!ALLOWED_EXTS.includes(ext)) {
      alert(`File type not allowed. Supported extensions: ${ALLOWED_EXTS.join(', ')}`);
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      alert('File size exceeds the 10MB limit.');
      return;
    }

    const clientMsgId = generateUUID();
    const messageType = ext.match(/(png|jpg|jpeg|webp)$/i) ? 'IMAGE' : 'FILE';

    // Store file reference in temp state for retries
    setTempFiles(prev => ({ ...prev, [clientMsgId]: file }));

    const tempMsg = {
      id: `temp_${clientMsgId}`,
      client_msg_id: clientMsgId,
      sender_type: getMyRole(),
      sender_id: getMyId(),
      content: file.name,
      message_type: messageType,
      is_seen: false,
      created_at: new Date().toISOString(),
      status: 'uploading',
      progress: 0,
      fileRef: file,
      onRetry: () => handleRetryUpload(clientMsgId, file)
    };

    setMessages(prev => deduplicateAndSort([...prev, tempMsg]));
    performUpload(tempMsg);
  };

  const handleArchiveToggle = async (conv) => {
    try {
      await chatAPI.archiveConversation(conv.id);
      fetchConversations();
      setShowMenu(false);
      setSelectedConv(prev => {
        if (!prev) return null;
        const role = getMyRole();
        if (role === 'user') {
          return { ...prev, is_archived_by_patient: !prev.is_archived_by_patient };
        } else {
          return { ...prev, is_archived_by_doctor: !prev.is_archived_by_doctor };
        }
      });
    } catch (err) {
      console.error('Failed to toggle archive status', err);
    }
  };

  const handleHideConversation = async (convId) => {
    if (window.confirm('Are you sure you want to remove this conversation from your list? This will hide it from your active chat room.')) {
      try {
        await chatAPI.deleteConversation(convId);
        setSelectedConv(null);
        if (wsRef.current) wsRef.current.close();
        fetchConversations();
        setShowMenu(false);
      } catch (err) {
        console.error('Failed to hide conversation', err);
      }
    }
  };

  // Group messages sent by same sender within 2 minutes window
  const groupedMessages = useMemo(() => {
    const groups = [];
    messages.forEach((msg, idx) => {
      const prevMsg = messages[idx - 1];
      const timeDiff = prevMsg ? (new Date(msg.created_at) - new Date(prevMsg.created_at)) / 1000 / 60 : 0;
      const isSameSender = prevMsg && prevMsg.sender_type === msg.sender_type && String(prevMsg.sender_id) === String(msg.sender_id);

      // We don't group files or images together to render them clean
      const isSpecialType = msg.message_type === 'IMAGE' || msg.message_type === 'FILE' || (prevMsg && (prevMsg.message_type === 'IMAGE' || prevMsg.message_type === 'FILE'));

      if (isSameSender && timeDiff <= 2 && !isSpecialType && msg.status !== 'failed' && msg.status !== 'uploading') {
        groups[groups.length - 1].messages.push(msg);
      } else {
        // Build retry callback mapping on group items
        const formattedMsg = {
          ...msg,
          onRetry: msg.status === 'failed' ? () => handleRetryUpload(msg.client_msg_id, tempFiles[msg.client_msg_id]) : undefined
        };
        groups.push({
          sender_type: msg.sender_type,
          sender_id: msg.sender_id,
          created_at: msg.created_at,
          messages: [formattedMsg]
        });
      }
    });
    return groups;
  }, [messages, handleRetryUpload, tempFiles]);

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading conversations...</p>
    </div>
  );

  const displayedSidebarList = activeTab === 'active' ? conversations : archivedConvs;

  return (
    <div className="dashboard-page fade-in" style={{ padding: 0, height: '100%' }}>
      <div style={{ display: 'flex', height: 'calc(100vh - 80px)', gap: 0 }}>

        {/* Sidebar */}
        <div className="glass-card" style={{
          width: selectedConv ? '300px' : '100%',
          maxWidth: '360px',
          borderRadius: selectedConv ? '16px 0 0 16px' : '16px',
          overflowY: 'hidden',
          display: 'flex',
          flexDirection: 'column',
          flexShrink: 0,
          transition: 'width 0.3s ease'
        }}>
          {/* Header */}
          <div className="card-header" style={{ padding: '1.25rem 1.5rem', borderBottom: '1px solid rgba(255,255,255,0.07)' }}>
            <MessageCircle size={18} className="accent" />
            <h3>Conversations</h3>
          </div>

          {/* Tab Selection */}
          <div style={{ display: 'flex', background: 'rgba(255,255,255,0.02)', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
            <button
              onClick={() => setActiveTab('active')}
              style={{
                flex: 1, padding: '0.75rem', border: 'none', background: 'none', cursor: 'pointer',
                color: activeTab === 'active' ? '#a78bfa' : '#888',
                fontWeight: activeTab === 'active' ? 700 : 500,
                borderBottom: activeTab === 'active' ? '2px solid #a78bfa' : 'none',
                fontSize: '0.85rem', transition: 'all 0.2s'
              }}
            >
              Active ({conversations.length})
            </button>
            <button
              onClick={() => setActiveTab('archived')}
              style={{
                flex: 1, padding: '0.75rem', border: 'none', background: 'none', cursor: 'pointer',
                color: activeTab === 'archived' ? '#a78bfa' : '#888',
                fontWeight: activeTab === 'archived' ? 700 : 500,
                borderBottom: activeTab === 'archived' ? '2px solid #a78bfa' : 'none',
                fontSize: '0.85rem', transition: 'all 0.2s'
              }}
            >
              Archived ({archivedConvs.length})
            </button>
          </div>

          {/* List Wrapper */}
          <div style={{ overflowY: 'auto', flex: 1 }}>
            {displayedSidebarList.length === 0 ? (
              <div style={{ padding: '3rem 2rem', textAlign: 'center', color: '#888' }}>
                <MessageCircle size={40} style={{ opacity: 0.2, marginBottom: '1rem' }} />
                <p style={{ fontSize: '0.85rem' }}>No conversations here.</p>
              </div>
            ) : (
              displayedSidebarList.map((conv) => (
                <div
                  key={conv.id}
                  onClick={() => openConversation(conv)}
                  style={{
                    padding: '1rem 1.25rem',
                    cursor: 'pointer',
                    borderBottom: '1px solid rgba(255,255,255,0.05)',
                    background: selectedConv?.id === conv.id ? 'rgba(160,120,255,0.08)' : 'transparent',
                    transition: 'background 0.2s',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.75rem',
                  }}
                  onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.03)'}
                  onMouseLeave={e => e.currentTarget.style.background = selectedConv?.id === conv.id ? 'rgba(160,120,255,0.08)' : 'transparent'}
                >
                  {/* Status Indicator Avatar */}
                  <div style={{ position: 'relative', flexShrink: 0 }}>
                    <div style={{
                      width: 40, height: 40, borderRadius: '50%',
                      background: 'linear-gradient(135deg, #a78bfa, #7c3aed)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontWeight: 700, fontSize: '1rem', color: '#fff'
                    }}>
                      {(conv.other_party?.name || 'U')[0].toUpperCase()}
                    </div>
                    <div style={{
                      width: 10, height: 10, borderRadius: '50%',
                      background: conv.other_party?.is_online ? '#22c55e' : '#64748b',
                      border: '2px solid #0a0516',
                      position: 'absolute', bottom: 0, right: 0
                    }} />
                  </div>

                  <div style={{ overflow: 'hidden', flex: 1 }}>
                    <div style={{ fontWeight: 600, fontSize: '0.9rem', marginBottom: '0.2rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ textOverflow: 'ellipsis', whiteSpace: 'nowrap', overflow: 'hidden' }}>
                        {conv.other_party?.name || 'Unknown'}
                      </span>
                      {conv.unread_count > 0 && (
                        <span style={{
                          background: '#7c3aed', color: '#fff', borderRadius: '10px',
                          fontSize: '0.7rem', padding: '2px 6px', fontWeight: 700
                        }}>
                          {conv.unread_count}
                        </span>
                      )}
                    </div>
                    <div style={{ fontSize: '0.75rem', color: '#888', textOverflow: 'ellipsis', whiteSpace: 'nowrap', overflow: 'hidden' }}>
                      {conv.last_message?.content || 'No messages yet'}
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Chat window */}
        {selectedConv ? (
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
            {/* Header */}
            <div style={{
              padding: '1rem 1.5rem',
              borderBottom: '1px solid rgba(255,255,255,0.07)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              background: 'rgba(255,255,255,0.02)',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <button
                  onClick={() => { setSelectedConv(null); if (wsRef.current) wsRef.current.close(); }}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#aaa', display: 'flex', padding: 0 }}
                >
                  <ArrowLeft size={20} />
                </button>
                <div style={{ position: 'relative' }}>
                  <div style={{
                    width: 38, height: 38, borderRadius: '50%',
                    background: 'linear-gradient(135deg, #a78bfa, #7c3aed)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontWeight: 700, color: '#fff'
                  }}>
                    {(selectedConv.other_party?.name || 'U')[0].toUpperCase()}
                  </div>
                  <div style={{
                    width: 10, height: 10, borderRadius: '50%',
                    background: selectedConv.other_party?.is_online ? '#22c55e' : '#64748b',
                    border: '2px solid #0f172a',
                    position: 'absolute', bottom: 0, right: 0
                  }} />
                </div>
                <div>
                  <div style={{ fontWeight: 600, fontSize: '0.95rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    {selectedConv.other_party?.name || 'Unknown'}
                  </div>
                  <div style={{ fontSize: '0.75rem', color: '#aaa' }}>
                    {selectedConv.other_party?.is_online
                      ? 'Online'
                      : selectedConv.other_party?.last_seen
                        ? `Last seen: ${new Date(selectedConv.other_party.last_seen).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`
                        : 'Offline'}
                  </div>
                </div>
              </div>

              {/* Menu options drop-down */}
              <div style={{ position: 'relative' }}>
                <button
                  onClick={() => setShowMenu(prev => !prev)}
                  style={{ background: 'none', border: 'none', color: '#aaa', cursor: 'pointer', display: 'flex', padding: 4 }}
                >
                  <MoreVertical size={20} />
                </button>
                {showMenu && (
                  <div style={{
                    position: 'absolute', top: '100%', right: 0,
                    background: '#180e29', border: '1px solid rgba(255,255,255,0.1)',
                    borderRadius: '8px', width: '180px', zIndex: 100,
                    boxShadow: '0 4px 15px rgba(0,0,0,0.5)', overflow: 'hidden', marginTop: '4px'
                  }}>
                    <button
                      onClick={() => handleArchiveToggle(selectedConv)}
                      style={{
                        width: '100%', padding: '0.75rem 1rem', border: 'none', background: 'none',
                        color: '#cbd5e1', cursor: 'pointer', display: 'flex', alignItems: 'center',
                        gap: '8px', fontSize: '0.85rem', textAlign: 'left'
                      }}
                      onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.05)'}
                      onMouseLeave={e => e.currentTarget.style.background = 'none'}
                    >
                      <Archive size={16} />
                      {selectedConv.is_archived_by_patient || selectedConv.is_archived_by_doctor ? 'Unarchive Chat' : 'Archive Chat'}
                    </button>
                    <button
                      onClick={() => handleHideConversation(selectedConv.id)}
                      style={{
                        width: '100%', padding: '0.75rem 1rem', border: 'none', background: 'none',
                        color: '#f87171', cursor: 'pointer', display: 'flex', alignItems: 'center',
                        gap: '8px', fontSize: '0.85rem', textAlign: 'left'
                      }}
                      onMouseEnter={e => e.currentTarget.style.background = 'rgba(239,68,68,0.1)'}
                      onMouseLeave={e => e.currentTarget.style.background = 'none'}
                    >
                      <EyeOff size={16} />
                      Remove from my chats
                    </button>
                  </div>
                )}
              </div>
            </div>

            {/* Offline Network Banner */}
            {isOffline && (
              <div style={{
                background: 'rgba(234,179,8,0.15)', borderBottom: '1px solid rgba(234,179,8,0.3)',
                color: '#facc15', padding: '0.5rem 1rem', textAlign: 'center', fontSize: '0.8rem',
                fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px'
              }}>
                <WifiOff size={14} /> Connection lost. Reconnecting...
              </div>
            )}
            {!isOffline && !wsConnected && (
              <div style={{
                background: 'rgba(124,58,237,0.15)', borderBottom: '1px solid rgba(124,58,237,0.3)',
                color: '#a78bfa', padding: '0.5rem 1rem', textAlign: 'center', fontSize: '0.8rem',
                fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px'
              }}>
                <Wifi size={14} className="pulse" /> Connecting to chat server...
              </div>
            )}

            {/* Message Area */}
            <div
              ref={messageListRef}
              onScroll={handleScroll}
              style={{
                flex: 1,
                overflowY: 'auto',
                padding: '1.5rem',
                display: 'flex',
                flexDirection: 'column',
                gap: '1rem',
              }}
            >
              {loadingHistory && (
                <div style={{ textAlign: 'center', padding: '0.5rem' }}>
                  <Loader size={16} className="spin" style={{ color: '#a78bfa' }} />
                </div>
              )}

              {groupedMessages.map((group, idx) => {
                const mine = group.sender_type === getMyRole() && String(group.sender_id) === String(getMyId());
                return (
                  <div key={idx} style={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: mine ? 'flex-end' : 'flex-start',
                    gap: '4px',
                    width: '100%'
                  }}>
                    {/* Header showing name once for non-mine groups */}
                    {!mine && (
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', margin: '2px 4px' }}>
                        <span style={{ fontSize: '0.75rem', color: '#888', fontWeight: 600 }}>
                          {selectedConv.other_party?.name || 'Unknown'}
                        </span>
                      </div>
                    )}
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', width: '100%', alignItems: mine ? 'flex-end' : 'flex-start' }}>
                      {group.messages.map((msg) => (
                        <MessageBubble key={msg.id} msg={msg} mine={mine} />
                      ))}
                    </div>
                  </div>
                );
              })}

              {isOtherTyping && (
                <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
                  <div style={{
                    padding: '0.5rem 0.85rem',
                    borderRadius: '12px 12px 12px 4px',
                    background: 'rgba(255,255,255,0.05)',
                    color: '#a78bfa',
                    fontSize: '0.75rem',
                    fontWeight: 500,
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    <span className="typing-dots">
                      <span>•</span><span>•</span><span>•</span>
                    </span>
                    {selectedConv.other_party?.name} is typing...
                  </div>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Input strip */}
            <div style={{
              padding: '1rem 1.5rem',
              borderTop: '1px solid rgba(255,255,255,0.07)',
              display: 'flex',
              gap: '0.75rem',
              alignItems: 'flex-end',
              background: 'rgba(255,255,255,0.02)',
            }}>
              {/* Attachment Button */}
              <button
                onClick={() => fileInputRef.current?.click()}
                style={{
                  background: 'none', border: 'none', cursor: 'pointer', color: '#aaa',
                  padding: '0.5rem', display: 'flex', alignItems: 'center',
                  transition: 'color 0.2s'
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#aaa'}
              >
                <Paperclip size={20} />
              </button>
              <input
                type="file"
                ref={fileInputRef}
                style={{ display: 'none' }}
                onChange={(e) => {
                  if (e.target.files && e.target.files[0]) {
                    triggerFileUpload(e.target.files[0]);
                  }
                  e.target.value = ''; // Reset input selection
                }}
              />

              {/* Textarea */}
              <textarea
                value={newMessage}
                onChange={handleInputChange}
                onKeyDown={handleKeyDown}
                placeholder="Type a message... (Enter to send)"
                rows={1}
                style={{
                  flex: 1,
                  background: 'rgba(255,255,255,0.06)',
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

              {/* Send Button */}
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
                  opacity: !newMessage.trim() ? 0.4 : 1,
                  transition: 'opacity 0.2s',
                }}
              >
                {sendingMsg ? <Loader size={18} className="spin" /> : <Send size={18} />}
              </button>
            </div>
          </div>
        ) : (
          <div style={{
            flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', color: '#888', background: 'rgba(10,8,20,0.4)'
          }}>
            <MessageCircle size={64} style={{ opacity: 0.15, marginBottom: '1rem' }} />
            <p style={{ fontSize: '0.95rem', fontWeight: 500 }}>Select a conversation to start chatting</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default ChatPage;

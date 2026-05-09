import React, { useState, useEffect, useRef } from 'react';
import { chatbotAPI } from '../services/api';
import { Send, Bot, User, Loader, Sparkles } from 'lucide-react';

const ChatbotPage = () => {
  const [messages, setMessages] = useState([]);
  const [inputValue, setInputValue] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const scrollRef = useRef(null);

  useEffect(() => {
    fetchConversation();
  }, []);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages]);

  const fetchConversation = async () => {
    try {
      setLoading(true);
      const res = await chatbotAPI.getConversation();
      setMessages(res.data.messages || []);
    } catch (err) {
      console.error('Error fetching chatbot conversation', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!inputValue.trim() || sending) return;

    const userText = inputValue;
    setInputValue('');
    setSending(true);

    // Optimistically add user message
    const tempUserMsg = { message_id: Date.now(), sender: 'user', content: userText, sent_at: new Date().toISOString() };
    setMessages(prev => [...prev, tempUserMsg]);

    try {
      const res = await chatbotAPI.sendMessage(userText);
      // Replace with actual data from server
      setMessages(prev => {
        const filtered = prev.filter(m => m.message_id !== tempUserMsg.message_id);
        return [...filtered, res.data.user_message, res.data.bot_message];
      });
    } catch (err) {
      console.error('Error sending message to chatbot', err);
      // Maybe add an error message from bot
      setMessages(prev => [...prev, { 
        message_id: Date.now() + 1, 
        sender: 'bot', 
        content: "I'm sorry, I'm having trouble connecting right now. Please try again later.",
        sent_at: new Date().toISOString()
      }]);
    } finally {
      setSending(false);
    }
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Starting MindMate AI Session...</p>
    </div>
  );

  return (
    <div className="dashboard-page fade-in" style={{ maxWidth: '800px', margin: '0 auto', height: 'calc(100vh - 120px)', display: 'flex', flexDirection: 'column' }}>
      <header className="page-header" style={{ textAlign: 'center', marginBottom: '1.5rem' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', background: 'rgba(167, 139, 250, 0.1)', padding: '0.5rem 1rem', borderRadius: '20px', color: '#a78bfa', marginBottom: '0.5rem' }}>
          <Sparkles size={16} />
          <span style={{ fontSize: '0.8rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '1px' }}>AI Companion</span>
        </div>
        <h1>MindMate Assistant</h1>
        <p>Your safe space for conversation and support. I'm here to listen and help.</p>
      </header>

      <div className="glass-card" style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', borderRadius: '24px' }}>
        {/* Chat Area */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          {messages.length === 0 && (
            <div style={{ textAlign: 'center', padding: '2rem', color: '#888' }}>
              <Bot size={48} style={{ opacity: 0.2, marginBottom: '1rem' }} />
              <p>Say hello to start your session.</p>
            </div>
          )}
          
          {messages.map((msg) => (
            <div key={msg.message_id} style={{ 
              display: 'flex', 
              justifyContent: msg.sender === 'user' ? 'flex-end' : 'flex-start',
              alignItems: 'flex-start',
              gap: '0.75rem'
            }}>
              {msg.sender === 'bot' && (
                <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(167, 139, 250, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#a78bfa', flexShrink: 0 }}>
                  <Bot size={16} />
                </div>
              )}
              <div style={{ 
                maxWidth: '75%', 
                padding: '0.75rem 1rem', 
                borderRadius: msg.sender === 'user' ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                background: msg.sender === 'user' ? 'linear-gradient(135deg, #7c3aed, #a78bfa)' : 'rgba(255, 255, 255, 0.05)',
                color: msg.sender === 'user' ? '#fff' : '#e2e8f0',
                fontSize: '0.95rem',
                lineHeight: 1.5,
                boxShadow: msg.sender === 'user' ? '0 4px 12px rgba(124, 58, 237, 0.2)' : 'none'
              }}>
                {msg.content}
              </div>
            </div>
          ))}
          {sending && (
            <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
               <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(167, 139, 250, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#a78bfa' }}>
                  <Bot size={16} />
                </div>
                <div className="typing-indicator">
                  <span></span><span></span><span></span>
                </div>
            </div>
          )}
          <div ref={scrollRef} />
        </div>

        {/* Input Area */}
        <form onSubmit={handleSendMessage} style={{ padding: '1.25rem', background: 'rgba(255, 255, 255, 0.02)', borderTop: '1px solid rgba(255, 255, 255, 0.05)', display: 'flex', gap: '0.75rem' }}>
          <input 
            type="text" 
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            placeholder="Type your message here..."
            disabled={sending}
            style={{ 
              flex: 1, 
              background: 'rgba(255, 255, 255, 0.05)', 
              border: '1px solid rgba(255, 255, 255, 0.1)', 
              borderRadius: '14px', 
              padding: '0.75rem 1rem', 
              color: '#fff',
              outline: 'none',
              transition: 'border-color 0.2s'
            }}
            onFocus={(e) => e.target.style.borderColor = '#a78bfa'}
            onBlur={(e) => e.target.style.borderColor = 'rgba(255, 255, 255, 0.1)'}
          />
          <button 
            type="submit" 
            disabled={!inputValue.trim() || sending}
            className="btn-primary"
            style={{ 
              padding: '0.75rem', 
              minWidth: 'unset', 
              borderRadius: '14px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            {sending ? <Loader size={20} className="spin" /> : <Send size={20} />}
          </button>
        </form>
      </div>
    </div>
  );
};

export default ChatbotPage;

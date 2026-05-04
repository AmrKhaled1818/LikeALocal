import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { Send, ArrowLeft, Phone, Video, Info } from 'lucide-react';
import { Avatar, AvatarImage, AvatarFallback } from '../components/ui/avatar';
import { Button } from '../components/ui/button';

interface Message {
  id: string;
  senderId: string;
  content: string;
  timestamp: Date;
}

const MOCK_CONVERSATIONS = {
  'ai': {
    name: 'AI Discovery Assistant',
    avatar: null,
    isAI: true,
  },
  '1': {
    name: 'Sarah Chen',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
    online: true,
  },
  '2': {
    name: 'Mike Johnson',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mike',
    online: true,
  },
  'group-1': {
    name: 'Weekend Explorers',
    avatar: 'https://api.dicebear.com/7.x/identicon/svg?seed=group1',
    isGroup: true,
    members: 5,
  },
};

export function ConversationScreen() {
  const { conversationId } = useParams();
  const navigate = useNavigate();
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '1',
      senderId: conversationId || '',
      content: "Hey! How are you doing?",
      timestamp: new Date(Date.now() - 3600000),
    },
    {
      id: '2',
      senderId: 'me',
      content: "I'm good! Just found an amazing hidden cafe",
      timestamp: new Date(Date.now() - 3500000),
    },
  ]);
  const [input, setInput] = useState('');

  const conversation = MOCK_CONVERSATIONS[conversationId as keyof typeof MOCK_CONVERSATIONS];

  if (!conversation) {
    return <div>Conversation not found</div>;
  }

  const handleSend = () => {
    if (!input.trim()) return;

    const newMessage: Message = {
      id: Date.now().toString(),
      senderId: 'me',
      content: input,
      timestamp: new Date(),
    };

    setMessages([...messages, newMessage]);
    setInput('');

    // Simulate response
    if (conversation.isAI) {
      setTimeout(() => {
        const aiMessage: Message = {
          id: (Date.now() + 1).toString(),
          senderId: conversationId || '',
          content: "That sounds great! I'd love to help you discover more hidden gems. What kind of places are you looking for?",
          timestamp: new Date(),
        };
        setMessages((prev) => [...prev, aiMessage]);
      }, 1000);
    }
  };

  return (
    <div className="flex flex-col h-screen">
      {/* Header */}
      <div className="border-b bg-background sticky top-0 z-10">
        <div className="flex items-center justify-between p-3">
          <div className="flex items-center gap-3 flex-1">
            <Button variant="ghost" size="icon" onClick={() => navigate('/chat')}>
              <ArrowLeft size={20} />
            </Button>

            <div className="relative">
              <Avatar className="h-10 w-10">
                {conversation.isAI ? (
                  <div className="bg-gradient-to-r from-purple-500 to-pink-500 w-full h-full flex items-center justify-center text-white">
                    AI
                  </div>
                ) : (
                  <>
                    <AvatarImage src={conversation.avatar || ''} alt={conversation.name} />
                    <AvatarFallback>{conversation.name[0]}</AvatarFallback>
                  </>
                )}
              </Avatar>
              {conversation.online && !conversation.isAI && (
                <div className="absolute bottom-0 right-0 w-3 h-3 bg-green-500 border-2 border-background rounded-full" />
              )}
            </div>

            <div className="flex-1 min-w-0">
              <p className="font-medium truncate">{conversation.name}</p>
              {conversation.isGroup && (
                <p className="text-xs text-muted-foreground">{conversation.members} members</p>
              )}
              {conversation.online && !conversation.isAI && !conversation.isGroup && (
                <p className="text-xs text-green-500">Online</p>
              )}
              {conversation.isAI && (
                <p className="text-xs text-muted-foreground">Always active</p>
              )}
            </div>
          </div>

          {!conversation.isAI && (
            <div className="flex items-center gap-1">
              <Button variant="ghost" size="icon">
                <Phone size={20} />
              </Button>
              <Button variant="ghost" size="icon">
                <Video size={20} />
              </Button>
              <Button variant="ghost" size="icon">
                <Info size={20} />
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4 pb-20">
        {messages.map((message) => {
          const isMe = message.senderId === 'me';

          return (
            <div key={message.id} className={`flex gap-2 ${isMe ? 'justify-end' : ''}`}>
              {!isMe && (
                <Avatar className="h-8 w-8">
                  {conversation.isAI ? (
                    <div className="bg-gradient-to-r from-purple-500 to-pink-500 w-full h-full flex items-center justify-center text-white text-xs">
                      AI
                    </div>
                  ) : (
                    <>
                      <AvatarImage src={conversation.avatar || ''} alt={conversation.name} />
                      <AvatarFallback>{conversation.name[0]}</AvatarFallback>
                    </>
                  )}
                </Avatar>
              )}

              <div className={`max-w-[75%] ${isMe ? 'order-first' : ''}`}>
                <div
                  className={`rounded-2xl px-4 py-2 ${
                    isMe
                      ? 'bg-primary text-primary-foreground ml-auto'
                      : 'bg-muted'
                  }`}
                >
                  <p className="text-sm">{message.content}</p>
                </div>
                <p className="text-xs text-muted-foreground mt-1 px-2">
                  {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </p>
              </div>

              {isMe && (
                <Avatar className="h-8 w-8">
                  <AvatarImage src="https://api.dicebear.com/7.x/avataaars/svg?seed=You" alt="You" />
                  <AvatarFallback>Y</AvatarFallback>
                </Avatar>
              )}
            </div>
          );
        })}
      </div>

      {/* Input */}
      <div className="border-t bg-background p-4 sticky bottom-0">
        <div className="flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
            placeholder="Type a message..."
            className="flex-1 px-4 py-2 border rounded-full bg-background focus:outline-none focus:ring-2 focus:ring-ring"
          />
          <Button size="icon" onClick={handleSend} className="rounded-full shrink-0">
            <Send size={20} />
          </Button>
        </div>
      </div>
    </div>
  );
}

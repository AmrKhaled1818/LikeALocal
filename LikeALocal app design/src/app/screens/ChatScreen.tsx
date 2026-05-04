import { useState } from 'react';
import { useNavigate } from 'react-router';
import { Sparkles, Users, Menu, Search } from 'lucide-react';
import { Avatar, AvatarImage, AvatarFallback } from '../components/ui/avatar';
import { Button } from '../components/ui/button';
import { FriendsSidebar } from '../components/FriendsSidebar';

interface ChatPreview {
  id: string;
  name: string;
  avatar?: string;
  lastMessage: string;
  timestamp: Date;
  unread: number;
  online?: boolean;
  isAI?: boolean;
  isGroup?: boolean;
}

export function ChatScreen() {
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const chats: ChatPreview[] = [
    {
      id: 'ai',
      name: 'AI Discovery Assistant',
      lastMessage: 'I can help you find hidden gems in your area!',
      timestamp: new Date(Date.now() - 300000),
      unread: 0,
      isAI: true,
    },
    {
      id: '1',
      name: 'Sarah Chen',
      avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
      lastMessage: 'That place looks amazing! 😍',
      timestamp: new Date(Date.now() - 600000),
      unread: 2,
      online: true,
    },
    {
      id: '2',
      name: 'Mike Johnson',
      avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mike',
      lastMessage: 'Thanks for the recommendation!',
      timestamp: new Date(Date.now() - 3600000),
      unread: 0,
      online: true,
    },
    {
      id: 'group-1',
      name: 'Weekend Explorers',
      avatar: 'https://api.dicebear.com/7.x/identicon/svg?seed=group1',
      lastMessage: 'Emma: Who wants to check out that new cafe?',
      timestamp: new Date(Date.now() - 7200000),
      unread: 5,
      isGroup: true,
    },
  ];

  const filteredChats = chats.filter(chat =>
    chat.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="h-[calc(100vh-8rem)]">
      <FriendsSidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Header */}
      <div className="border-b bg-background p-4">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-3">
            <Button variant="ghost" size="icon" onClick={() => setSidebarOpen(true)}>
              <Menu size={24} />
            </Button>
            <h1>Messages</h1>
          </div>
        </div>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" size={18} />
          <input
            type="text"
            placeholder="Search conversations..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-muted rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>
      </div>

      {/* Chat List */}
      <div className="overflow-y-auto h-[calc(100%-9rem)]">
        {filteredChats.map((chat) => (
          <button
            key={chat.id}
            onClick={() => navigate(`/conversation/${chat.id}`)}
            className="w-full flex items-center gap-3 p-4 hover:bg-muted transition-colors border-b"
          >
            <div className="relative">
              <Avatar className="h-14 w-14">
                {chat.isAI ? (
                  <div className="bg-gradient-to-r from-purple-500 to-pink-500 w-full h-full flex items-center justify-center">
                    <Sparkles size={24} className="text-white" />
                  </div>
                ) : (
                  <>
                    <AvatarImage src={chat.avatar} alt={chat.name} />
                    <AvatarFallback>{chat.name[0]}</AvatarFallback>
                  </>
                )}
              </Avatar>
              {chat.online && !chat.isAI && (
                <div className="absolute bottom-0 right-0 w-4 h-4 bg-green-500 border-2 border-background rounded-full" />
              )}
              {chat.isGroup && (
                <div className="absolute bottom-0 right-0 w-5 h-5 bg-primary border-2 border-background rounded-full flex items-center justify-center">
                  <Users size={12} className="text-primary-foreground" />
                </div>
              )}
            </div>

            <div className="flex-1 min-w-0 text-left">
              <div className="flex items-center justify-between mb-1">
                <p className="font-medium truncate">{chat.name}</p>
                <span className="text-xs text-muted-foreground ml-2 shrink-0">
                  {chat.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <p className="text-sm text-muted-foreground truncate">
                  {chat.lastMessage}
                </p>
                {chat.unread > 0 && (
                  <span className="ml-2 shrink-0 bg-primary text-primary-foreground text-xs rounded-full px-2 py-0.5 min-w-[20px] text-center">
                    {chat.unread}
                  </span>
                )}
              </div>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}

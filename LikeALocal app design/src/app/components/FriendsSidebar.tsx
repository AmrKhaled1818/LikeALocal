import { X, UserPlus, Users, Search } from 'lucide-react';
import { Avatar, AvatarImage, AvatarFallback } from './ui/avatar';
import { Button } from './ui/button';
import { useState } from 'react';

interface FriendsSidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

const MOCK_FRIENDS = [
  { id: '1', username: 'Sarah Chen', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah', online: true },
  { id: '2', username: 'Mike Johnson', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mike', online: true },
  { id: '3', username: 'Emma Wilson', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Emma', online: false },
  { id: '4', username: 'Alex Rodriguez', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex', online: true },
  { id: '5', username: 'Lisa Park', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Lisa', online: false },
];

export function FriendsSidebar({ isOpen, onClose }: FriendsSidebarProps) {
  const [searchQuery, setSearchQuery] = useState('');

  const filteredFriends = MOCK_FRIENDS.filter(friend =>
    friend.username.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (!isOpen) return null;

  return (
    <>
      {/* Overlay */}
      <div
        className="fixed inset-0 bg-black/50 z-50 transition-opacity"
        onClick={onClose}
      />

      {/* Sidebar */}
      <div className="fixed top-0 left-0 bottom-0 w-80 max-w-[85vw] bg-background z-50 shadow-xl">
        <div className="flex flex-col h-full">
          {/* Header */}
          <div className="p-4 border-b">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-lg">Friends</h2>
              <Button variant="ghost" size="icon" onClick={onClose}>
                <X size={24} />
              </Button>
            </div>

            {/* Search */}
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" size={18} />
              <input
                type="text"
                placeholder="Search friends..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-4 py-2 bg-muted rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
              />
            </div>
          </div>

          {/* Friends List */}
          <div className="flex-1 overflow-y-auto p-2">
            <div className="mb-4">
              <h3 className="text-sm font-medium text-muted-foreground px-2 mb-2">
                {filteredFriends.filter(f => f.online).length} Online
              </h3>

              {filteredFriends.map((friend) => (
                <button
                  key={friend.id}
                  onClick={onClose}
                  className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-muted transition-colors"
                >
                  <div className="relative">
                    <Avatar className="h-10 w-10">
                      <AvatarImage src={friend.avatar} alt={friend.username} />
                      <AvatarFallback>{friend.username[0]}</AvatarFallback>
                    </Avatar>
                    {friend.online && (
                      <div className="absolute bottom-0 right-0 w-3 h-3 bg-green-500 border-2 border-background rounded-full" />
                    )}
                  </div>
                  <div className="flex-1 text-left min-w-0">
                    <p className="font-medium truncate">{friend.username}</p>
                    <p className="text-xs text-muted-foreground">
                      {friend.online ? 'Online' : 'Offline'}
                    </p>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Footer */}
          <div className="p-4 border-t space-y-2">
            <Button className="w-full justify-start gap-3">
              <UserPlus size={20} />
              <span>Add Friend</span>
            </Button>
            <Button variant="outline" className="w-full justify-start gap-3">
              <Users size={20} />
              <span>Create Group</span>
            </Button>
          </div>
        </div>
      </div>
    </>
  );
}

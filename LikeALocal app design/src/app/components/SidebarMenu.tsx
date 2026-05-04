import { X, User, Bookmark, Bell, Settings, Crown, LogOut, TrendingUp } from 'lucide-react';
import { Link } from 'react-router';
import { Avatar, AvatarImage, AvatarFallback } from './ui/avatar';
import { Button } from './ui/button';
import { Separator } from './ui/separator';
import { UserBadge } from './UserBadge';

interface SidebarMenuProps {
  isOpen: boolean;
  onClose: () => void;
}

export function SidebarMenu({ isOpen, onClose }: SidebarMenuProps) {
  const currentUser = {
    username: 'YourUsername',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=You',
    karma: 1842,
    isSuperUser: false,
    contributionScore: 76,
  };

  const menuItems = [
    { icon: User, label: 'Profile', path: '/profile' },
    { icon: Bookmark, label: 'Saved Posts', path: '/saved' },
    { icon: Bell, label: 'Notifications', path: '/notifications' },
    { icon: Settings, label: 'Settings', path: '/settings' },
  ];

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
              <h2 className="font-bold text-lg">Menu</h2>
              <Button variant="ghost" size="icon" onClick={onClose}>
                <X size={24} />
              </Button>
            </div>

            {/* User Profile Summary */}
            <Link to="/profile" onClick={onClose}>
              <div className="flex items-center gap-3 p-3 rounded-lg hover:bg-muted transition-colors">
                <Avatar className="h-12 w-12">
                  <AvatarImage src={currentUser.avatar} alt={currentUser.username} />
                  <AvatarFallback>{currentUser.username[0]}</AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                  <p className="font-medium truncate">{currentUser.username}</p>
                  <UserBadge karma={currentUser.karma} isSuperUser={currentUser.isSuperUser} size="sm" />
                </div>
              </div>
            </Link>

            {/* Progress to Super User */}
            {!currentUser.isSuperUser && (
              <div className="mt-3 p-3 bg-muted/50 rounded-lg">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs font-medium">Path to Super User</span>
                  <span className="text-xs text-muted-foreground">{currentUser.contributionScore}%</span>
                </div>
                <div className="h-2 bg-secondary rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-amber-500 to-orange-500 transition-all"
                    style={{ width: `${currentUser.contributionScore}%` }}
                  />
                </div>
                <p className="text-xs text-muted-foreground mt-1.5">
                  {80 - currentUser.contributionScore}% more to unlock Super User status
                </p>
              </div>
            )}
          </div>

          {/* Menu Items */}
          <nav className="flex-1 overflow-y-auto p-2">
            {menuItems.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  onClick={onClose}
                  className="flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-muted transition-colors"
                >
                  <Icon size={20} />
                  <span className="font-medium">{item.label}</span>
                </Link>
              );
            })}
          </nav>

          {/* Footer */}
          <div className="p-4 border-t">
            <Button
              variant="ghost"
              className="w-full justify-start gap-3 text-red-500 hover:text-red-600 hover:bg-red-50"
            >
              <LogOut size={20} />
              <span className="font-medium">Log Out</span>
            </Button>
          </div>
        </div>
      </div>
    </>
  );
}

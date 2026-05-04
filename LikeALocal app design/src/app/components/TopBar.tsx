import { Menu, Bell } from 'lucide-react';
import { Link } from 'react-router';
import { Avatar, AvatarImage, AvatarFallback } from './ui/avatar';
import { Button } from './ui/button';
import { Badge } from './ui/badge';

interface TopBarProps {
  onMenuClick: () => void;
  notificationCount?: number;
}

export function TopBar({ onMenuClick, notificationCount = 3 }: TopBarProps) {
  return (
    <header className="fixed top-0 left-0 right-0 bg-background border-b z-50">
      <div className="max-w-md mx-auto px-4 py-3">
        <div className="flex items-center justify-between">
          {/* Menu Button */}
          <Button variant="ghost" size="icon" onClick={onMenuClick}>
            <Menu size={24} />
          </Button>

          {/* Logo */}
          <Link to="/posts" className="flex items-center gap-2">
            <div className="bg-gradient-to-r from-orange-500 to-pink-500 rounded-lg p-1.5">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 2L2 7L12 12L22 7L12 2Z" fill="white" />
                <path d="M2 17L12 22L22 17" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                <path d="M2 12L12 17L22 12" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </div>
            <span className="font-bold text-lg">LikeALocal</span>
          </Link>

          {/* Right Actions */}
          <div className="flex items-center gap-2">
            <Link to="/notifications" className="relative">
              <Button variant="ghost" size="icon">
                <Bell size={20} />
                {notificationCount > 0 && (
                  <Badge className="absolute -top-1 -right-1 h-5 w-5 p-0 flex items-center justify-center bg-red-500 text-white text-xs">
                    {notificationCount}
                  </Badge>
                )}
              </Button>
            </Link>
            <Link to="/profile">
              <Avatar className="h-8 w-8 cursor-pointer">
                <AvatarImage src="https://api.dicebear.com/7.x/avataaars/svg?seed=You" alt="Profile" />
                <AvatarFallback>Y</AvatarFallback>
              </Avatar>
            </Link>
          </div>
        </div>
      </div>
    </header>
  );
}

import { Home, Map, MessageSquare, Search, Plus } from 'lucide-react';
import { Link, useLocation } from 'react-router';

export function BottomNav() {
  const location = useLocation();

  const navItems = [
    { icon: Home, label: 'Posts', path: '/posts' },
    { icon: Map, label: 'Map', path: '/map' },
    { icon: Plus, label: 'Create', path: '/create-post', special: true },
    { icon: MessageSquare, label: 'Chat', path: '/chat' },
    { icon: Search, label: 'Search', path: '/search' },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-background border-t z-50">
      <div className="max-w-md mx-auto px-2 py-2">
        <div className="flex items-center justify-around">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path ||
                           (item.path === '/posts' && location.pathname === '/');

            if (item.special) {
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className="flex flex-col items-center gap-1 px-4 py-2 rounded-lg transition-all bg-primary text-primary-foreground hover:opacity-90"
                >
                  <Icon size={20} strokeWidth={2.5} />
                  <span className="text-xs font-medium">{item.label}</span>
                </Link>
              );
            }

            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex flex-col items-center gap-1 px-4 py-2 rounded-lg transition-colors ${
                  isActive
                    ? 'text-primary'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                <Icon size={20} strokeWidth={isActive ? 2.5 : 2} />
                <span className="text-xs font-medium">{item.label}</span>
              </Link>
            );
          })}
        </div>
      </div>
    </nav>
  );
}

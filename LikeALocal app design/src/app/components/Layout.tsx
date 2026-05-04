import { useState } from 'react';
import { Outlet, useLocation } from 'react-router';
import { TopBar } from './TopBar';
import { BottomNav } from './BottomNav';
import { SidebarMenu } from './SidebarMenu';

export function Layout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const location = useLocation();

  // Routes that should show top bar and bottom nav
  const showNav = ['/', '/posts', '/map', '/chat', '/search'].includes(location.pathname);
  const showTopBar = (showNav || location.pathname.startsWith('/post/') ||
                     location.pathname === '/notifications' ||
                     location.pathname === '/profile' ||
                     location.pathname === '/saved' ||
                     location.pathname === '/create-post') &&
                     !location.pathname.startsWith('/conversation/');

  return (
    <div className="min-h-screen bg-background">
      {/* Sidebar Menu */}
      <SidebarMenu isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Top Bar */}
      {showTopBar && <TopBar onMenuClick={() => setSidebarOpen(true)} />}

      {/* Main Content */}
      <main className={`${showTopBar ? 'pt-14' : ''} max-w-md mx-auto`}>
        <Outlet />
      </main>

      {/* Bottom Navigation */}
      {showNav && <BottomNav />}
    </div>
  );
}

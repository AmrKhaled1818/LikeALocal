import { ArrowLeft, User, Bell, Lock, Globe, HelpCircle, Info } from 'lucide-react';
import { Link } from 'react-router';
import { Button } from '../components/ui/button';
import { Switch } from '../components/ui/switch';
import { Separator } from '../components/ui/separator';

export function SettingsScreen() {
  return (
    <div className="pb-20">
      {/* Header */}
      <div className="sticky top-0 bg-background border-b z-10 p-4">
        <div className="flex items-center gap-3">
          <Link to="/profile">
            <Button variant="ghost" size="icon">
              <ArrowLeft size={20} />
            </Button>
          </Link>
          <h2 className="font-bold text-xl">Settings</h2>
        </div>
      </div>

      <div className="p-4">
        {/* Account Section */}
        <section className="mb-6">
          <h3 className="text-sm font-semibold text-muted-foreground mb-3">ACCOUNT</h3>
          <div className="space-y-1">
            <button className="flex items-center gap-3 w-full p-3 rounded-lg hover:bg-muted transition-colors">
              <User size={20} />
              <span className="flex-1 text-left">Edit Profile</span>
            </button>
            <button className="flex items-center gap-3 w-full p-3 rounded-lg hover:bg-muted transition-colors">
              <Lock size={20} />
              <span className="flex-1 text-left">Privacy & Security</span>
            </button>
          </div>
        </section>

        <Separator className="my-6" />

        {/* Notifications Section */}
        <section className="mb-6">
          <h3 className="text-sm font-semibold text-muted-foreground mb-3">NOTIFICATIONS</h3>
          <div className="space-y-3">
            <div className="flex items-center justify-between p-3 rounded-lg hover:bg-muted transition-colors">
              <div className="flex items-center gap-3">
                <Bell size={20} />
                <div>
                  <p className="font-medium">Push Notifications</p>
                  <p className="text-xs text-muted-foreground">Get notified about activity</p>
                </div>
              </div>
              <Switch defaultChecked />
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg hover:bg-muted transition-colors">
              <div className="flex items-center gap-3">
                <MapPin size={20} />
                <div>
                  <p className="font-medium">Nearby Gems</p>
                  <p className="text-xs text-muted-foreground">Alert when new spots are posted nearby</p>
                </div>
              </div>
              <Switch defaultChecked />
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg hover:bg-muted transition-colors">
              <div className="flex items-center gap-3">
                <MessageCircle size={20} />
                <div>
                  <p className="font-medium">Comments & Replies</p>
                  <p className="text-xs text-muted-foreground">When someone replies to your posts</p>
                </div>
              </div>
              <Switch defaultChecked />
            </div>
          </div>
        </section>

        <Separator className="my-6" />

        {/* Preferences Section */}
        <section className="mb-6">
          <h3 className="text-sm font-semibold text-muted-foreground mb-3">PREFERENCES</h3>
          <div className="space-y-1">
            <button className="flex items-center gap-3 w-full p-3 rounded-lg hover:bg-muted transition-colors">
              <Globe size={20} />
              <span className="flex-1 text-left">Language</span>
              <span className="text-sm text-muted-foreground">English</span>
            </button>
            <button className="flex items-center gap-3 w-full p-3 rounded-lg hover:bg-muted transition-colors">
              <MapPin size={20} />
              <span className="flex-1 text-left">Location Services</span>
            </button>
          </div>
        </section>

        <Separator className="my-6" />

        {/* Support Section */}
        <section className="mb-6">
          <h3 className="text-sm font-semibold text-muted-foreground mb-3">SUPPORT</h3>
          <div className="space-y-1">
            <button className="flex items-center gap-3 w-full p-3 rounded-lg hover:bg-muted transition-colors">
              <HelpCircle size={20} />
              <span className="flex-1 text-left">Help Center</span>
            </button>
            <button className="flex items-center gap-3 w-full p-3 rounded-lg hover:bg-muted transition-colors">
              <Info size={20} />
              <span className="flex-1 text-left">About</span>
            </button>
          </div>
        </section>

        {/* App Version */}
        <div className="text-center mt-8">
          <p className="text-xs text-muted-foreground">LikeALocal v1.0.0</p>
        </div>
      </div>
    </div>
  );
}

// Additional icon components
function MapPin({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z" />
      <circle cx="12" cy="10" r="3" />
    </svg>
  );
}

function MessageCircle({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z" />
    </svg>
  );
}

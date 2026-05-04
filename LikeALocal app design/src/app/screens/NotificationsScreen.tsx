import { ArrowBigUp, MessageCircle, UserPlus, MapPin, Sparkles } from 'lucide-react';
import { Link } from 'react-router';
import { Avatar, AvatarImage, AvatarFallback } from '../components/ui/avatar';
import { Card } from '../components/ui/card';
import { Badge } from '../components/ui/badge';

interface Notification {
  id: string;
  type: 'upvote' | 'comment' | 'follow' | 'nearby' | 'ai_recommendation';
  user?: {
    username: string;
    avatar: string;
  };
  post?: {
    id: string;
    title: string;
  };
  content: string;
  timestamp: string;
  read: boolean;
}

export function NotificationsScreen() {
  const notifications: Notification[] = [
    {
      id: '1',
      type: 'upvote',
      user: {
        username: 'AlexTheExplorer',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',
      },
      post: {
        id: '1',
        title: 'Hidden Rooftop Garden with Amazing Sunset Views',
      },
      content: 'upvoted your post',
      timestamp: '2026-04-10T10:30:00Z',
      read: false,
    },
    {
      id: '2',
      type: 'comment',
      user: {
        username: 'SarahLocal',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
      },
      post: {
        id: '2',
        title: 'Authentic Dumpling Spot',
      },
      content: 'commented: "This place looks amazing! Thanks for sharing."',
      timestamp: '2026-04-10T09:15:00Z',
      read: false,
    },
    {
      id: '3',
      type: 'nearby',
      content: 'New hidden gem discovered 0.5 miles from you',
      timestamp: '2026-04-10T08:00:00Z',
      read: false,
      post: {
        id: '3',
        title: 'Secret Urban Garden Behind Old Factory',
      },
    },
    {
      id: '4',
      type: 'follow',
      user: {
        username: 'MikeDiscovers',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mike',
      },
      content: 'started following you',
      timestamp: '2026-04-09T18:45:00Z',
      read: true,
    },
    {
      id: '5',
      type: 'ai_recommendation',
      content: 'Based on your interests, we found 3 new spots you might love',
      timestamp: '2026-04-09T14:00:00Z',
      read: true,
    },
    {
      id: '6',
      type: 'upvote',
      user: {
        username: 'EmilyWanders',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Emily',
      },
      post: {
        id: '4',
        title: 'Cozy Bookshop with Cat & Free Coffee',
      },
      content: 'and 12 others upvoted your post',
      timestamp: '2026-04-09T12:30:00Z',
      read: true,
    },
  ];

  const getIcon = (type: string) => {
    switch (type) {
      case 'upvote':
        return <ArrowBigUp size={20} className="text-orange-500" />;
      case 'comment':
        return <MessageCircle size={20} className="text-blue-500" />;
      case 'follow':
        return <UserPlus size={20} className="text-green-500" />;
      case 'nearby':
        return <MapPin size={20} className="text-purple-500" />;
      case 'ai_recommendation':
        return <Sparkles size={20} className="text-pink-500" />;
      default:
        return null;
    }
  };

  const timeAgo = (timestamp: string) => {
    const now = new Date();
    const posted = new Date(timestamp);
    const diffMs = now.getTime() - posted.getTime();
    const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
    
    if (diffHrs < 1) return 'Just now';
    if (diffHrs < 24) return `${diffHrs}h ago`;
    const diffDays = Math.floor(diffHrs / 24);
    if (diffDays === 1) return 'Yesterday';
    return `${diffDays}d ago`;
  };

  return (
    <div className="pb-20">
      {/* Header */}
      <div className="sticky top-0 bg-background border-b z-10 p-4">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-xl">Notifications</h2>
          <button className="text-sm text-primary hover:underline">
            Mark all as read
          </button>
        </div>
      </div>

      {/* Notifications List */}
      <div className="divide-y">
        {notifications.map((notification) => {
          const link = notification.post ? `/post/${notification.post.id}` : '#';
          
          return (
            <Link key={notification.id} to={link}>
              <div
                className={`p-4 hover:bg-muted/50 transition-colors ${
                  !notification.read ? 'bg-blue-50/50' : ''
                }`}
              >
                <div className="flex gap-3">
                  {/* Icon or Avatar */}
                  <div className="flex-shrink-0">
                    {notification.user ? (
                      <Avatar className="h-10 w-10">
                        <AvatarImage src={notification.user.avatar} alt={notification.user.username} />
                        <AvatarFallback>{notification.user.username[0]}</AvatarFallback>
                      </Avatar>
                    ) : (
                      <div className="h-10 w-10 rounded-full bg-muted flex items-center justify-center">
                        {getIcon(notification.type)}
                      </div>
                    )}
                  </div>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm">
                      {notification.user && (
                        <span className="font-semibold">{notification.user.username} </span>
                      )}
                      <span className={notification.read ? 'text-muted-foreground' : ''}>
                        {notification.content}
                      </span>
                    </p>
                    {notification.post && (
                      <p className="text-sm text-muted-foreground mt-1 line-clamp-1">
                        "{notification.post.title}"
                      </p>
                    )}
                    <p className="text-xs text-muted-foreground mt-1">
                      {timeAgo(notification.timestamp)}
                    </p>
                  </div>

                  {/* Unread Badge */}
                  {!notification.read && (
                    <div className="flex-shrink-0">
                      <div className="w-2 h-2 bg-blue-500 rounded-full" />
                    </div>
                  )}
                </div>
              </div>
            </Link>
          );
        })}
      </div>

      {/* Empty State (if needed) */}
      {notifications.length === 0 && (
        <div className="text-center py-12 px-4">
          <div className="bg-muted rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-4">
            <MessageCircle size={32} className="text-muted-foreground" />
          </div>
          <h3 className="font-semibold mb-2">No notifications yet</h3>
          <p className="text-sm text-muted-foreground">
            When people interact with your posts, you'll see it here
          </p>
        </div>
      )}
    </div>
  );
}

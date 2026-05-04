import { ArrowBigUp, ArrowBigDown, MessageCircle, Bookmark, Share2, MapPin } from 'lucide-react';
import { Link } from 'react-router';
import { Post } from '../data/mockData';
import { UserBadge } from './UserBadge';
import { Avatar, AvatarImage, AvatarFallback } from './ui/avatar';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { useState } from 'react';

interface PostCardProps {
  post: Post;
  onVote?: (postId: string, vote: 'up' | 'down') => void;
  onSave?: (postId: string) => void;
  onShare?: (postId: string) => void;
}

export function PostCard({ post, onVote, onSave, onShare }: PostCardProps) {
  const [localUpvotes, setLocalUpvotes] = useState(post.upvotes);
  const [localDownvotes, setLocalDownvotes] = useState(post.downvotes);
  const [userVote, setUserVote] = useState<'up' | 'down' | null>(null);
  const [isSaved, setIsSaved] = useState(post.saved);

  const score = localUpvotes - localDownvotes;

  const handleVote = (vote: 'up' | 'down') => {
    if (userVote === vote) {
      // Un-vote
      if (vote === 'up') {
        setLocalUpvotes(localUpvotes - 1);
      } else {
        setLocalDownvotes(localDownvotes - 1);
      }
      setUserVote(null);
    } else {
      // New vote or change vote
      if (userVote === 'up') {
        setLocalUpvotes(localUpvotes - 1);
      } else if (userVote === 'down') {
        setLocalDownvotes(localDownvotes - 1);
      }

      if (vote === 'up') {
        setLocalUpvotes(localUpvotes + 1);
      } else {
        setLocalDownvotes(localDownvotes + 1);
      }
      setUserVote(vote);
    }
    onVote?.(post.id, vote);
  };

  const handleSave = () => {
    setIsSaved(!isSaved);
    onSave?.(post.id);
  };

  const handleShare = () => {
    onShare?.(post.id);
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
    <Card className={`overflow-hidden ${post.isSuperUser ? 'ring-1 ring-amber-500/30' : ''}`}>
      {/* User Info */}
      <div className="p-3 flex items-center gap-2">
        <Avatar className="h-9 w-9">
          <AvatarImage src={post.userAvatar} alt={post.username} />
          <AvatarFallback>{post.username[0]}</AvatarFallback>
        </Avatar>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <p className="font-medium text-sm truncate">{post.username}</p>
            <UserBadge karma={post.userKarma} isSuperUser={post.isSuperUser} size="sm" />
          </div>
          <div className="flex items-center gap-1 text-xs text-muted-foreground">
            <MapPin size={12} />
            <span className="truncate">{post.location}</span>
            <span>·</span>
            <span>{timeAgo(post.timestamp)}</span>
          </div>
        </div>
      </div>

      {/* Post Content */}
      <Link to={`/post/${post.id}`}>
        <div className="px-3 pb-2">
          <h3 className="font-semibold text-base mb-1">{post.title}</h3>
          <p className="text-sm text-muted-foreground line-clamp-2">{post.description}</p>
        </div>

        {/* Post Image */}
        <div className="relative aspect-[4/3] overflow-hidden">
          <img
            src={post.image}
            alt={post.title}
            className="w-full h-full object-cover"
          />
        </div>
      </Link>

      {/* Actions */}
      <div className="px-3 py-2 flex items-center gap-1">
        {/* Vote Controls */}
        <div className="flex items-center gap-1 bg-secondary rounded-full px-2 py-1">
          <Button
            variant="ghost"
            size="sm"
            className={`h-7 w-7 p-0 hover:bg-transparent ${userVote === 'up' ? 'text-orange-500' : ''}`}
            onClick={() => handleVote('up')}
          >
            <ArrowBigUp size={20} fill={userVote === 'up' ? 'currentColor' : 'none'} />
          </Button>
          <span className="text-sm font-medium min-w-[2rem] text-center">
            {score > 0 ? '+' : ''}{score}
          </span>
          <Button
            variant="ghost"
            size="sm"
            className={`h-7 w-7 p-0 hover:bg-transparent ${userVote === 'down' ? 'text-blue-500' : ''}`}
            onClick={() => handleVote('down')}
          >
            <ArrowBigDown size={20} fill={userVote === 'down' ? 'currentColor' : 'none'} />
          </Button>
        </div>

        {/* Comments */}
        <Link to={`/post/${post.id}`}>
          <Button variant="ghost" size="sm" className="gap-1 h-8 px-2">
            <MessageCircle size={16} />
            <span className="text-sm">{post.commentCount}</span>
          </Button>
        </Link>

        <div className="flex-1" />

        {/* Save & Share */}
        <Button
          variant="ghost"
          size="sm"
          className={`h-8 w-8 p-0 ${isSaved ? 'text-amber-500' : ''}`}
          onClick={handleSave}
        >
          <Bookmark size={16} fill={isSaved ? 'currentColor' : 'none'} />
        </Button>
        <Button variant="ghost" size="sm" className="h-8 w-8 p-0" onClick={handleShare}>
          <Share2 size={16} />
        </Button>
      </div>
    </Card>
  );
}

import { useParams, Link } from 'react-router';
import { ArrowLeft, ArrowBigUp, ArrowBigDown, Bookmark, Share2, MapPin } from 'lucide-react';
import { mockPosts, mockComments } from '../data/mockData';
import { UserBadge } from '../components/UserBadge';
import { CommentItem } from '../components/CommentItem';
import { Avatar, AvatarImage, AvatarFallback } from '../components/ui/avatar';
import { Button } from '../components/ui/button';
import { Separator } from '../components/ui/separator';
import { useState } from 'react';

export function PostDetailScreen() {
  const { id } = useParams();
  const post = mockPosts.find((p) => p.id === id);
  const comments = mockComments[id || ''] || [];

  const [localUpvotes, setLocalUpvotes] = useState(post?.upvotes || 0);
  const [localDownvotes, setLocalDownvotes] = useState(post?.downvotes || 0);
  const [userVote, setUserVote] = useState<'up' | 'down' | null>(null);
  const [isSaved, setIsSaved] = useState(post?.saved || false);

  if (!post) {
    return (
      <div className="p-4">
        <p>Post not found</p>
      </div>
    );
  }

  const score = localUpvotes - localDownvotes;

  const handleVote = (vote: 'up' | 'down') => {
    if (userVote === vote) {
      if (vote === 'up') {
        setLocalUpvotes(localUpvotes - 1);
      } else {
        setLocalDownvotes(localDownvotes - 1);
      }
      setUserVote(null);
    } else {
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
      <div className="sticky top-0 bg-background border-b z-10 px-4 py-3">
        <div className="flex items-center gap-3">
          <Link to="/posts">
            <Button variant="ghost" size="icon">
              <ArrowLeft size={20} />
            </Button>
          </Link>
          <h2 className="font-bold text-lg flex-1">Post</h2>
          <Button variant="ghost" size="icon" onClick={() => setIsSaved(!isSaved)}>
            <Bookmark size={20} fill={isSaved ? 'currentColor' : 'none'} className={isSaved ? 'text-amber-500' : ''} />
          </Button>
          <Button variant="ghost" size="icon">
            <Share2 size={20} />
          </Button>
        </div>
      </div>

      {/* Post Content */}
      <div className="p-4">
        {/* User Info */}
        <div className="flex items-center gap-3 mb-4">
          <Avatar className="h-10 w-10">
            <AvatarImage src={post.userAvatar} alt={post.username} />
            <AvatarFallback>{post.username[0]}</AvatarFallback>
          </Avatar>
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-1">
              <p className="font-medium">{post.username}</p>
              <UserBadge karma={post.userKarma} isSuperUser={post.isSuperUser} size="sm" />
            </div>
            <div className="flex items-center gap-1 text-sm text-muted-foreground">
              <MapPin size={14} />
              <span>{post.location}</span>
              <span>·</span>
              <span>{timeAgo(post.timestamp)}</span>
            </div>
          </div>
        </div>

        {/* Title & Description */}
        <h1 className="text-xl font-bold mb-2">{post.title}</h1>
        <p className="text-muted-foreground mb-4">{post.description}</p>

        {/* Image */}
        <div className="rounded-lg overflow-hidden mb-4">
          <img
            src={post.image}
            alt={post.title}
            className="w-full"
          />
        </div>

        {/* Vote Actions */}
        <div className="flex items-center gap-3 mb-6">
          <div className="flex items-center gap-1 bg-secondary rounded-full px-3 py-2">
            <Button
              variant="ghost"
              size="sm"
              className={`h-8 w-8 p-0 hover:bg-transparent ${userVote === 'up' ? 'text-orange-500' : ''}`}
              onClick={() => handleVote('up')}
            >
              <ArrowBigUp size={24} fill={userVote === 'up' ? 'currentColor' : 'none'} />
            </Button>
            <span className="font-bold min-w-[3rem] text-center">
              {score > 0 ? '+' : ''}{score}
            </span>
            <Button
              variant="ghost"
              size="sm"
              className={`h-8 w-8 p-0 hover:bg-transparent ${userVote === 'down' ? 'text-blue-500' : ''}`}
              onClick={() => handleVote('down')}
            >
              <ArrowBigDown size={24} fill={userVote === 'down' ? 'currentColor' : 'none'} />
            </Button>
          </div>
          <span className="text-sm text-muted-foreground">{post.commentCount} comments</span>
        </div>

        <Separator className="mb-6" />

        {/* Comments Section */}
        <div>
          <h3 className="font-bold text-lg mb-4">Comments</h3>

          {/* Add Comment */}
          <div className="flex gap-2 mb-6">
            <Avatar className="h-8 w-8">
              <AvatarImage src="https://api.dicebear.com/7.x/avataaars/svg?seed=You" alt="You" />
              <AvatarFallback>Y</AvatarFallback>
            </Avatar>
            <input
              type="text"
              placeholder="Share your thoughts..."
              className="flex-1 px-4 py-2 border rounded-full bg-background"
            />
          </div>

          {/* Comments List */}
          <div className="space-y-1">
            {comments.map((comment) => (
              <CommentItem key={comment.id} comment={comment} currentUserId="1" />
            ))}
          </div>

          {comments.length === 0 && (
            <div className="text-center py-8 text-muted-foreground">
              <p>No comments yet. Be the first to share your thoughts!</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

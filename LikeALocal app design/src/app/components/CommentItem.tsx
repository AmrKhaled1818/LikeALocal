import { ArrowBigUp, ArrowBigDown, MessageCircle, MoreHorizontal, Pencil, Trash2 } from 'lucide-react';
import { Comment } from '../data/mockData';
import { UserBadge } from './UserBadge';
import { Avatar, AvatarImage, AvatarFallback } from './ui/avatar';
import { Button } from './ui/button';
import { useState } from 'react';
import { toast } from 'sonner';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from './ui/dropdown-menu';

interface CommentItemProps {
  comment: Comment;
  depth?: number;
  currentUserId?: string;
  onDelete?: (commentId: string) => void;
  onEdit?: (commentId: string, newContent: string) => void;
}

export function CommentItem({ comment, depth = 0, currentUserId = '1', onDelete, onEdit }: CommentItemProps) {
  const [localUpvotes, setLocalUpvotes] = useState(comment.upvotes);
  const [localDownvotes, setLocalDownvotes] = useState(comment.downvotes);
  const [userVote, setUserVote] = useState<'up' | 'down' | null>(null);
  const [showReply, setShowReply] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editedContent, setEditedContent] = useState(comment.content);
  const [isDeleted, setIsDeleted] = useState(false);

  const isAuthor = comment.userId === currentUserId;

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

  const handleDelete = () => {
    if (confirm('Are you sure you want to delete this comment?')) {
      setIsDeleted(true);
      toast.success('Comment deleted');
      onDelete?.(comment.id);
    }
  };

  const handleEdit = () => {
    setIsEditing(true);
  };

  const handleSaveEdit = () => {
    if (!editedContent.trim()) {
      toast.error('Comment cannot be empty');
      return;
    }
    setIsEditing(false);
    toast.success('Comment updated');
    onEdit?.(comment.id, editedContent);
  };

  const handleCancelEdit = () => {
    setIsEditing(false);
    setEditedContent(comment.content);
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

  if (isDeleted) {
    return null;
  }

  return (
    <div className={`${depth > 0 ? 'ml-4 pl-3 border-l-2 border-muted' : ''}`}>
      <div className="py-3">
        {/* User Info */}
        <div className="flex items-start gap-2 mb-2">
          <Avatar className="h-7 w-7">
            <AvatarImage src={comment.userAvatar} alt={comment.username} />
            <AvatarFallback>{comment.username[0]}</AvatarFallback>
          </Avatar>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <p className="font-medium text-sm">{comment.username}</p>
              <UserBadge karma={comment.userKarma} isSuperUser={comment.isSuperUser} size="sm" />
              <span className="text-xs text-muted-foreground">{timeAgo(comment.timestamp)}</span>
              {isEditing && <span className="text-xs text-muted-foreground">(editing)</span>}
            </div>
          </div>

          {/* Edit/Delete Menu */}
          {isAuthor && !isEditing && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                  <MoreHorizontal size={14} />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={handleEdit}>
                  <Pencil size={14} />
                  Edit
                </DropdownMenuItem>
                <DropdownMenuItem onClick={handleDelete} variant="destructive">
                  <Trash2 size={14} />
                  Delete
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>

        {/* Comment Content */}
        {isEditing ? (
          <div className="ml-9 mb-2">
            <textarea
              value={editedContent}
              onChange={(e) => setEditedContent(e.target.value)}
              className="w-full px-3 py-2 text-sm border rounded-lg bg-background resize-none"
              rows={3}
              autoFocus
            />
            <div className="flex gap-2 mt-2">
              <Button size="sm" onClick={handleSaveEdit}>
                Save
              </Button>
              <Button size="sm" variant="outline" onClick={handleCancelEdit}>
                Cancel
              </Button>
            </div>
          </div>
        ) : (
          <p className="text-sm mb-2 ml-9">{editedContent}</p>
        )}

        {/* Actions */}
        <div className="flex items-center gap-1 ml-9">
          <Button
            variant="ghost"
            size="sm"
            className={`h-7 px-2 gap-0.5 ${userVote === 'up' ? 'text-orange-500' : ''}`}
            onClick={() => handleVote('up')}
          >
            <ArrowBigUp size={16} fill={userVote === 'up' ? 'currentColor' : 'none'} />
          </Button>
          <span className="text-xs font-medium min-w-[1.5rem] text-center">
            {score > 0 ? '+' : ''}{score}
          </span>
          <Button
            variant="ghost"
            size="sm"
            className={`h-7 px-2 gap-0.5 ${userVote === 'down' ? 'text-blue-500' : ''}`}
            onClick={() => handleVote('down')}
          >
            <ArrowBigDown size={16} fill={userVote === 'down' ? 'currentColor' : 'none'} />
          </Button>
          <Button
            variant="ghost"
            size="sm"
            className="h-7 px-2 gap-1"
            onClick={() => setShowReply(!showReply)}
          >
            <MessageCircle size={14} />
            <span className="text-xs">Reply</span>
          </Button>
        </div>

        {/* Reply Input */}
        {showReply && (
          <div className="mt-2 ml-9">
            <input
              type="text"
              placeholder="Write a reply..."
              className="w-full px-3 py-2 text-sm border rounded-lg bg-background"
            />
          </div>
        )}
      </div>

      {/* Nested Replies */}
      {comment.replies && comment.replies.length > 0 && (
        <div>
          {comment.replies.map((reply) => (
            <CommentItem
              key={reply.id}
              comment={reply}
              depth={depth + 1}
              currentUserId={currentUserId}
              onDelete={onDelete}
              onEdit={onEdit}
            />
          ))}
        </div>
      )}
    </div>
  );
}

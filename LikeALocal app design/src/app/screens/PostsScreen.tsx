import { mockPosts } from '../data/mockData';
import { PostCard } from '../components/PostCard';
import { toast } from 'sonner';

export function PostsScreen() {
  const handleVote = (postId: string, vote: 'up' | 'down') => {
    console.log(`Voted ${vote} on post ${postId}`);
  };

  const handleSave = (postId: string) => {
    toast.success('Post saved!');
  };

  const handleShare = (postId: string) => {
    toast.success('Link copied to clipboard!');
  };

  return (
    <div className="space-y-4">
      {/* Feed Header */}
      <div className="sticky top-14 bg-background/95 backdrop-blur-sm z-10 py-3 px-4 border-b">
        <h2 className="font-bold text-lg">Hidden Gems Feed</h2>
        <p className="text-sm text-muted-foreground">Discover local spots shared by the community</p>
      </div>

      {/* Posts Feed */}
      <div className="px-4 pb-20 space-y-4">
        {mockPosts.map((post) => (
          <PostCard
            key={post.id}
            post={post}
            onVote={handleVote}
            onSave={handleSave}
            onShare={handleShare}
          />
        ))}
      </div>
    </div>
  );
}

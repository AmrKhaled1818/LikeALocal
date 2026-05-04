import { Bookmark, MapPin } from 'lucide-react';
import { Link } from 'react-router';
import { mockPosts } from '../data/mockData';
import { Card } from '../components/ui/card';
import { Badge } from '../components/ui/badge';

export function SavedPostsScreen() {
  const savedPosts = mockPosts.filter(p => p.saved);

  return (
    <div className="pb-20">
      {/* Header */}
      <div className="sticky top-0 bg-background border-b z-10 p-4">
        <h2 className="font-bold text-xl">Saved Posts</h2>
        <p className="text-sm text-muted-foreground">Your bookmarked hidden gems</p>
      </div>

      {/* Saved Posts List */}
      {savedPosts.length > 0 ? (
        <div className="p-4 space-y-3">
          {savedPosts.map((post) => (
            <Link key={post.id} to={`/post/${post.id}`}>
              <Card className="overflow-hidden hover:shadow-md transition-shadow">
                <div className="flex gap-3 p-3">
                  <img
                    src={post.image}
                    alt={post.title}
                    className="w-28 h-28 object-cover rounded-lg"
                  />
                  <div className="flex-1 min-w-0">
                    <h4 className="font-semibold mb-1 line-clamp-2">{post.title}</h4>
                    <div className="flex items-center gap-1 text-xs text-muted-foreground mb-2">
                      <MapPin size={12} />
                      <span className="truncate">{post.location}</span>
                    </div>
                    <div className="flex items-center gap-2 mb-2">
                      <span className="text-xs font-medium">{post.username}</span>
                      {post.isSuperUser && (
                        <Badge className="text-xs h-5 px-1.5 bg-gradient-to-r from-amber-500 to-orange-500 border-0">
                          Super User
                        </Badge>
                      )}
                    </div>
                    <p className="text-xs text-muted-foreground line-clamp-2 mb-2">
                      {post.description}
                    </p>
                    <div className="flex items-center gap-3 text-xs text-muted-foreground">
                      <span>↑ {post.upvotes - post.downvotes}</span>
                      <span>{post.commentCount} comments</span>
                    </div>
                  </div>
                </div>
              </Card>
            </Link>
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center h-[60vh] px-4">
          <div className="bg-muted rounded-full w-20 h-20 flex items-center justify-center mb-4">
            <Bookmark size={40} className="text-muted-foreground" />
          </div>
          <h3 className="font-semibold text-lg mb-2">No saved posts yet</h3>
          <p className="text-sm text-muted-foreground text-center max-w-sm">
            When you find hidden gems you want to remember, tap the bookmark icon to save them here
          </p>
        </div>
      )}
    </div>
  );
}

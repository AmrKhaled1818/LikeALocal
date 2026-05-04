import { Settings, MapPin, Calendar, Award, TrendingUp, Bookmark } from 'lucide-react';
import { Link } from 'react-router';
import { Avatar, AvatarImage, AvatarFallback } from '../components/ui/avatar';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { mockPosts } from '../data/mockData';

export function ProfileScreen() {
  const currentUser = {
    username: 'YourUsername',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=You',
    karma: 1842,
    isSuperUser: false,
    contributionScore: 76,
    bio: 'Explorer of hidden gems 🗺️ | Coffee enthusiast ☕ | Always looking for the next adventure',
    joinedDate: '2025-01-15',
    location: 'New York, NY',
    stats: {
      posts: 24,
      followers: 892,
      following: 347,
    },
  };

  const userPosts = mockPosts.slice(0, 3);

  return (
    <div className="pb-20">
      {/* Header */}
      <div className="sticky top-0 bg-background border-b z-10 p-4">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-xl">Profile</h2>
          <Link to="/settings">
            <Button variant="ghost" size="icon">
              <Settings size={20} />
            </Button>
          </Link>
        </div>
      </div>

      <div className="p-4">
        {/* Profile Header */}
        <Card className="p-6 mb-4">
          <div className="flex items-start gap-4 mb-4">
            <Avatar className="h-20 w-20">
              <AvatarImage src={currentUser.avatar} alt={currentUser.username} />
              <AvatarFallback>{currentUser.username[0]}</AvatarFallback>
            </Avatar>
            <div className="flex-1">
              <h1 className="text-xl font-bold mb-1">{currentUser.username}</h1>
              <div className="flex items-center gap-2 mb-2">
                {currentUser.isSuperUser ? (
                  <Badge className="bg-gradient-to-r from-amber-500 to-orange-500 text-white border-0 gap-1">
                    <Award size={14} />
                    <span>Super User</span>
                  </Badge>
                ) : (
                  <Badge variant="secondary" className="gap-1">
                    <TrendingUp size={14} />
                    <span>{currentUser.karma.toLocaleString()} karma</span>
                  </Badge>
                )}
              </div>
              <div className="flex items-center gap-4 text-sm">
                <div className="flex items-center gap-1 text-muted-foreground">
                  <MapPin size={14} />
                  <span>{currentUser.location}</span>
                </div>
                <div className="flex items-center gap-1 text-muted-foreground">
                  <Calendar size={14} />
                  <span>Joined {new Date(currentUser.joinedDate).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}</span>
                </div>
              </div>
            </div>
          </div>

          <p className="text-sm mb-4">{currentUser.bio}</p>

          {/* Stats */}
          <div className="flex gap-6">
            <button className="flex flex-col items-center">
              <span className="text-xl font-bold">{currentUser.stats.posts}</span>
              <span className="text-xs text-muted-foreground">Posts</span>
            </button>
            <button className="flex flex-col items-center">
              <span className="text-xl font-bold">{currentUser.stats.followers}</span>
              <span className="text-xs text-muted-foreground">Followers</span>
            </button>
            <button className="flex flex-col items-center">
              <span className="text-xl font-bold">{currentUser.stats.following}</span>
              <span className="text-xs text-muted-foreground">Following</span>
            </button>
          </div>

          {/* Progress to Super User */}
          {!currentUser.isSuperUser && (
            <div className="mt-4 p-4 bg-gradient-to-r from-amber-50 to-orange-50 rounded-lg border border-amber-200">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <Award size={18} className="text-amber-600" />
                  <span className="text-sm font-semibold text-amber-900">Path to Super User</span>
                </div>
                <span className="text-sm font-bold text-amber-900">{currentUser.contributionScore}%</span>
              </div>
              <div className="h-2 bg-amber-200 rounded-full overflow-hidden mb-2">
                <div
                  className="h-full bg-gradient-to-r from-amber-500 to-orange-500 transition-all"
                  style={{ width: `${currentUser.contributionScore}%` }}
                />
              </div>
              <p className="text-xs text-amber-800">
                Keep posting quality content to reach 80% and unlock Super User status!
              </p>
            </div>
          )}
        </Card>

        {/* Tabs */}
        <Tabs defaultValue="posts" className="w-full">
          <TabsList className="w-full grid grid-cols-2">
            <TabsTrigger value="posts">My Posts</TabsTrigger>
            <TabsTrigger value="saved">Saved</TabsTrigger>
          </TabsList>

          <TabsContent value="posts" className="mt-4 space-y-3">
            {userPosts.map((post) => (
              <Link key={post.id} to={`/post/${post.id}`}>
                <Card className="overflow-hidden hover:shadow-md transition-shadow">
                  <div className="flex gap-3 p-3">
                    <img
                      src={post.image}
                      alt={post.title}
                      className="w-24 h-24 object-cover rounded-lg"
                    />
                    <div className="flex-1 min-w-0">
                      <h4 className="font-semibold text-sm mb-1 line-clamp-2">{post.title}</h4>
                      <div className="flex items-center gap-1 text-xs text-muted-foreground mb-2">
                        <MapPin size={12} />
                        <span className="truncate">{post.location}</span>
                      </div>
                      <div className="flex items-center gap-3 text-xs text-muted-foreground">
                        <span>↑ {post.upvotes - post.downvotes}</span>
                        <span>{post.commentCount} comments</span>
                        <span>{new Date(post.timestamp).toLocaleDateString()}</span>
                      </div>
                    </div>
                  </div>
                </Card>
              </Link>
            ))}
          </TabsContent>

          <TabsContent value="saved" className="mt-4 space-y-3">
            {mockPosts.filter(p => p.saved).map((post) => (
              <Link key={post.id} to={`/post/${post.id}`}>
                <Card className="overflow-hidden hover:shadow-md transition-shadow">
                  <div className="flex gap-3 p-3">
                    <img
                      src={post.image}
                      alt={post.title}
                      className="w-24 h-24 object-cover rounded-lg"
                    />
                    <div className="flex-1 min-w-0">
                      <h4 className="font-semibold text-sm mb-1 line-clamp-2">{post.title}</h4>
                      <div className="flex items-center gap-1 text-xs text-muted-foreground mb-2">
                        <MapPin size={12} />
                        <span className="truncate">{post.location}</span>
                      </div>
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-xs font-medium">{post.username}</span>
                        {post.isSuperUser && (
                          <Badge className="text-xs h-5 px-1.5 bg-gradient-to-r from-amber-500 to-orange-500 border-0">
                            Super
                          </Badge>
                        )}
                      </div>
                      <div className="flex items-center gap-3 text-xs text-muted-foreground">
                        <span>↑ {post.upvotes - post.downvotes}</span>
                        <span>{post.commentCount} comments</span>
                      </div>
                    </div>
                  </div>
                </Card>
              </Link>
            ))}
            {mockPosts.filter(p => p.saved).length === 0 && (
              <div className="text-center py-12">
                <Bookmark size={48} className="mx-auto mb-4 text-muted-foreground" />
                <p className="text-muted-foreground">No saved posts yet</p>
                <p className="text-sm text-muted-foreground">Save posts to view them here later</p>
              </div>
            )}
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}

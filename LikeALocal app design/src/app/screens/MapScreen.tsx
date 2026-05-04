import { useState } from 'react';
import { MapPin, Navigation, Star } from 'lucide-react';
import { Link } from 'react-router';
import { mockPosts } from '../data/mockData';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { UserBadge } from '../components/UserBadge';

export function MapScreen() {
  const [selectedPost, setSelectedPost] = useState<string | null>(null);
  const postsWithLocation = mockPosts.filter(p => p.lat && p.lng);

  return (
    <div className="h-[calc(100vh-8rem)] relative">
      {/* Map Placeholder */}
      <div className="absolute inset-0 bg-gradient-to-br from-blue-100 to-green-100">
        {/* Mock Map UI */}
        <div className="relative w-full h-full">
          {/* Map markers */}
          {postsWithLocation.map((post, index) => {
            const top = 20 + (index * 15) % 60;
            const left = 15 + (index * 20) % 70;
            
            return (
              <button
                key={post.id}
                className="absolute transform -translate-x-1/2 -translate-y-1/2"
                style={{ top: `${top}%`, left: `${left}%` }}
                onClick={() => setSelectedPost(post.id)}
              >
                <div className={`relative ${selectedPost === post.id ? 'scale-125' : ''} transition-transform`}>
                  <MapPin
                    size={32}
                    className={`${
                      post.isSuperUser
                        ? 'text-amber-500 fill-amber-500'
                        : 'text-orange-500 fill-orange-500'
                    } drop-shadow-lg`}
                  />
                  {post.isSuperUser && (
                    <Star
                      size={12}
                      className="absolute top-0 right-0 text-yellow-300 fill-yellow-300"
                    />
                  )}
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Top Controls */}
      <div className="absolute top-4 left-4 right-4 z-10 flex gap-2">
        <input
          type="text"
          placeholder="Search places..."
          className="flex-1 px-4 py-2 bg-white rounded-full shadow-lg border"
        />
        <Button size="icon" className="rounded-full shadow-lg">
          <Navigation size={20} />
        </Button>
      </div>

      {/* Filter Chips */}
      <div className="absolute top-20 left-4 right-4 z-10 flex gap-2 overflow-x-auto pb-2">
        {['All', 'Food', 'Cafes', 'Parks', 'Art', 'Shopping'].map((filter) => (
          <button
            key={filter}
            className="px-4 py-1.5 bg-white rounded-full shadow text-sm font-medium whitespace-nowrap"
          >
            {filter}
          </button>
        ))}
      </div>

      {/* Selected Post Card */}
      {selectedPost && (
        <div className="absolute bottom-4 left-4 right-4 z-10">
          <Card className="overflow-hidden shadow-xl">
            {(() => {
              const post = postsWithLocation.find(p => p.id === selectedPost);
              if (!post) return null;

              return (
                <Link to={`/post/${post.id}`} onClick={() => setSelectedPost(null)}>
                  <div className="flex gap-3 p-3">
                    <img
                      src={post.image}
                      alt={post.title}
                      className="w-24 h-24 object-cover rounded-lg"
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <p className="text-sm font-medium truncate">{post.username}</p>
                        <UserBadge karma={post.userKarma} isSuperUser={post.isSuperUser} size="sm" />
                      </div>
                      <h3 className="font-semibold text-sm mb-1 line-clamp-1">{post.title}</h3>
                      <div className="flex items-center gap-1 text-xs text-muted-foreground mb-2">
                        <MapPin size={12} />
                        <span className="truncate">{post.location}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="flex items-center gap-1 text-xs bg-orange-100 text-orange-600 px-2 py-1 rounded-full">
                          <span>↑ {post.upvotes - post.downvotes}</span>
                        </div>
                        <span className="text-xs text-muted-foreground">
                          {post.commentCount} comments
                        </span>
                      </div>
                    </div>
                  </div>
                </Link>
              );
            })()}
          </Card>
        </div>
      )}

      {/* Legend */}
      <div className="absolute bottom-4 left-4 z-10 bg-white rounded-lg shadow-lg p-3">
        <div className="space-y-2">
          <div className="flex items-center gap-2 text-xs">
            <MapPin size={16} className="text-orange-500 fill-orange-500" />
            <span>Regular Post</span>
          </div>
          <div className="flex items-center gap-2 text-xs">
            <div className="relative">
              <MapPin size={16} className="text-amber-500 fill-amber-500" />
              <Star size={8} className="absolute -top-1 -right-1 text-yellow-300 fill-yellow-300" />
            </div>
            <span>Super User Post</span>
          </div>
        </div>
      </div>
    </div>
  );
}

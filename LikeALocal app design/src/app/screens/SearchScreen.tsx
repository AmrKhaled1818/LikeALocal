import { useState } from 'react';
import { Search, TrendingUp, MapPin, Star, Clock } from 'lucide-react';
import { Link } from 'react-router';
import { mockPosts } from '../data/mockData';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Badge } from '../components/ui/badge';

export function SearchScreen() {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState('all');

  const categories = [
    { id: 'all', label: 'All', icon: Star },
    { id: 'food', label: 'Food', icon: UtensilsCrossed },
    { id: 'cafes', label: 'Cafes', icon: Coffee },
    { id: 'culture', label: 'Culture', icon: Palette },
    { id: 'nature', label: 'Nature', icon: Trees },
  ];

  const trendingSearches = [
    'Hidden rooftop bars',
    'Local bakeries',
    'Secret gardens',
    'Vintage bookstores',
    'Street art spots',
    'Jazz clubs',
  ];

  const filteredPosts = mockPosts.filter(post =>
    post.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    post.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
    post.location.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="pb-20">
      {/* Search Header */}
      <div className="sticky top-0 bg-background border-b z-10 p-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground" size={20} />
          <Input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search hidden gems..."
            className="pl-10 pr-4 py-2 rounded-full"
          />
        </div>
      </div>

      {/* Category Filters */}
      <div className="px-4 py-3 border-b overflow-x-auto">
        <div className="flex gap-2">
          {categories.map((category) => {
            const Icon = category.icon;
            return (
              <button
                key={category.id}
                onClick={() => setActiveFilter(category.id)}
                className={`flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
                  activeFilter === category.id
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-secondary hover:bg-secondary/80'
                }`}
              >
                <Icon size={16} />
                <span>{category.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="p-4">
        {searchQuery === '' ? (
          <>
            {/* Trending Searches */}
            <section className="mb-6">
              <div className="flex items-center gap-2 mb-3">
                <TrendingUp size={20} className="text-orange-500" />
                <h3 className="font-bold">Trending Searches</h3>
              </div>
              <div className="flex flex-wrap gap-2">
                {trendingSearches.map((search, index) => (
                  <button
                    key={index}
                    onClick={() => setSearchQuery(search)}
                    className="px-3 py-1.5 bg-secondary hover:bg-secondary/80 rounded-full text-sm transition-colors"
                  >
                    {search}
                  </button>
                ))}
              </div>
            </section>

            {/* Recent Searches */}
            <section className="mb-6">
              <div className="flex items-center gap-2 mb-3">
                <Clock size={20} />
                <h3 className="font-bold">Recent</h3>
              </div>
              <div className="space-y-2">
                {['Coffee shops with wifi', 'Quiet parks', 'Rooftop views'].map((search, index) => (
                  <button
                    key={index}
                    onClick={() => setSearchQuery(search)}
                    className="flex items-center gap-3 w-full p-3 rounded-lg hover:bg-muted transition-colors text-left"
                  >
                    <Clock size={16} className="text-muted-foreground" />
                    <span className="flex-1">{search}</span>
                  </button>
                ))}
              </div>
            </section>

            {/* Recommended Places */}
            <section>
              <div className="flex items-center gap-2 mb-3">
                <Star size={20} className="text-amber-500" />
                <h3 className="font-bold">Recommended for You</h3>
              </div>
              <div className="space-y-3">
                {mockPosts.slice(0, 3).map((post) => (
                  <Link key={post.id} to={`/post/${post.id}`}>
                    <Card className="overflow-hidden hover:shadow-md transition-shadow">
                      <div className="flex gap-3 p-3">
                        <img
                          src={post.image}
                          alt={post.title}
                          className="w-20 h-20 object-cover rounded-lg"
                        />
                        <div className="flex-1 min-w-0">
                          <h4 className="font-semibold text-sm mb-1 line-clamp-1">{post.title}</h4>
                          <div className="flex items-center gap-1 text-xs text-muted-foreground mb-2">
                            <MapPin size={12} />
                            <span className="truncate">{post.location}</span>
                          </div>
                          <div className="flex items-center gap-2">
                            <Badge variant="secondary" className="text-xs">
                              ↑ {post.upvotes - post.downvotes}
                            </Badge>
                            {post.isSuperUser && (
                              <Badge className="text-xs bg-gradient-to-r from-amber-500 to-orange-500 border-0">
                                Super User
                              </Badge>
                            )}
                          </div>
                        </div>
                      </div>
                    </Card>
                  </Link>
                ))}
              </div>
            </section>
          </>
        ) : (
          <>
            {/* Search Results */}
            <div className="mb-3">
              <p className="text-sm text-muted-foreground">
                {filteredPosts.length} results for "{searchQuery}"
              </p>
            </div>
            <div className="space-y-3">
              {filteredPosts.map((post) => (
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
                        <p className="text-xs text-muted-foreground line-clamp-2 mb-2">
                          {post.description}
                        </p>
                        <div className="flex items-center gap-2">
                          <Badge variant="secondary" className="text-xs">
                            ↑ {post.upvotes - post.downvotes}
                          </Badge>
                          <span className="text-xs text-muted-foreground">
                            {post.commentCount} comments
                          </span>
                        </div>
                      </div>
                    </div>
                  </Card>
                </Link>
              ))}

              {filteredPosts.length === 0 && (
                <div className="text-center py-12">
                  <Search size={48} className="mx-auto mb-4 text-muted-foreground" />
                  <p className="text-muted-foreground">No results found</p>
                  <p className="text-sm text-muted-foreground">Try different keywords</p>
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// Additional icon components for categories
function UtensilsCrossed({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2" />
      <path d="M7 2v20" />
      <path d="M21 15V2v0a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7" />
    </svg>
  );
}

function Coffee({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 8h1a4 4 0 1 1 0 8h-1" />
      <path d="M3 8h14v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4Z" />
      <line x1="6" x2="6" y1="2" y2="4" />
      <line x1="10" x2="10" y1="2" y2="4" />
      <line x1="14" x2="14" y1="2" y2="4" />
    </svg>
  );
}

function Palette({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="13.5" cy="6.5" r=".5" />
      <circle cx="17.5" cy="10.5" r=".5" />
      <circle cx="8.5" cy="7.5" r=".5" />
      <circle cx="6.5" cy="12.5" r=".5" />
      <path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z" />
    </svg>
  );
}

function Trees({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10 10v.2A3 3 0 0 1 8.9 16v0H5v0h0a3 3 0 0 1-1-5.8V10a3 3 0 0 1 6 0Z" />
      <path d="M7 16v6" />
      <path d="M13 19v3" />
      <path d="M12 19h8.3a1 1 0 0 0 .7-1.7L18 14h.3a1 1 0 0 0 .7-1.7L16 9h.2a1 1 0 0 0 .8-1.7L13 3l-1.4 1.5" />
    </svg>
  );
}

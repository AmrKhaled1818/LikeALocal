export interface User {
  id: string;
  username: string;
  avatar: string;
  karma: number;
  isSuperUser: boolean;
  contributionScore: number;
}

export interface Post {
  id: string;
  userId: string;
  username: string;
  userAvatar: string;
  userKarma: number;
  isSuperUser: boolean;
  location: string;
  title: string;
  description: string;
  image: string;
  upvotes: number;
  downvotes: number;
  commentCount: number;
  timestamp: string;
  saved: boolean;
  lat?: number;
  lng?: number;
}

export interface Comment {
  id: string;
  postId: string;
  userId: string;
  username: string;
  userAvatar: string;
  userKarma: number;
  isSuperUser: boolean;
  content: string;
  upvotes: number;
  downvotes: number;
  replies: Comment[];
  timestamp: string;
}

export const mockUsers: User[] = [
  {
    id: '1',
    username: 'AlexTheExplorer',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',
    karma: 2847,
    isSuperUser: true,
    contributionScore: 89,
  },
  {
    id: '2',
    username: 'SarahLocal',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
    karma: 1523,
    isSuperUser: false,
    contributionScore: 72,
  },
  {
    id: '3',
    username: 'MikeDiscovers',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mike',
    karma: 3421,
    isSuperUser: true,
    contributionScore: 92,
  },
  {
    id: '4',
    username: 'EmilyWanders',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Emily',
    karma: 876,
    isSuperUser: false,
    contributionScore: 65,
  },
];

export const mockPosts: Post[] = [
  {
    id: '1',
    userId: '1',
    username: 'AlexTheExplorer',
    userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',
    userKarma: 2847,
    isSuperUser: true,
    location: 'East Village, NYC',
    title: 'Hidden Rooftop Garden with Amazing Sunset Views',
    description: 'Found this incredible rooftop garden tucked away in the East Village. Completely free, quiet, and has the best sunset views in Manhattan. Perfect spot for reading or just unwinding after work.',
    image: 'https://images.unsplash.com/photo-1689239719024-8f0866438b46?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxyb29mdG9wJTIwYmFyJTIwc3Vuc2V0fGVufDF8fHx8MTc3NTc1MDI5OHww&ixlib=rb-4.1.0&q=80&w=1080',
    upvotes: 347,
    downvotes: 12,
    commentCount: 28,
    timestamp: '2026-04-09T14:23:00Z',
    saved: false,
    lat: 40.7282,
    lng: -73.9842,
  },
  {
    id: '2',
    userId: '2',
    username: 'SarahLocal',
    userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
    userKarma: 1523,
    isSuperUser: false,
    location: 'Chinatown, SF',
    title: 'Authentic Dumpling Spot – No Tourists!',
    description: 'This tiny dumpling place in an alley has been run by the same family for 40 years. $8 for a huge plate of handmade dumplings. Cash only, no English menu, absolutely worth it.',
    image: 'https://images.unsplash.com/photo-1758346974199-f3c803e1b83e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxzdHJlZXQlMjBmb29kJTIwbWFya2V0JTIwbG9jYWx8ZW58MXx8fHwxNzc1ODI2NjQwfDA&ixlib=rb-4.1.0&q=80&w=1080',
    upvotes: 892,
    downvotes: 23,
    commentCount: 64,
    timestamp: '2026-04-08T09:15:00Z',
    saved: true,
    lat: 37.7949,
    lng: -122.4094,
  },
  {
    id: '3',
    userId: '3',
    username: 'MikeDiscovers',
    userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mike',
    userKarma: 3421,
    isSuperUser: true,
    location: 'Kreuzberg, Berlin',
    title: 'Secret Urban Garden Behind Old Factory',
    description: 'Stumbled upon this community garden hidden behind an abandoned factory. Local artists have transformed it into a peaceful oasis. They host free concerts on weekends!',
    image: 'https://images.unsplash.com/photo-1766187797316-c1906f4d568f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxzZWNyZXQlMjBnYXJkZW4lMjB1cmJhbnxlbnwxfHx8fDE3NzU4MjY2NDB8MA&ixlib=rb-4.1.0&q=80&w=1080',
    upvotes: 567,
    downvotes: 8,
    commentCount: 42,
    timestamp: '2026-04-07T16:42:00Z',
    saved: false,
    lat: 52.4988,
    lng: 13.4292,
  },
  {
    id: '4',
    userId: '4',
    username: 'EmilyWanders',
    userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Emily',
    userKarma: 876,
    isSuperUser: false,
    location: 'Shoreditch, London',
    title: 'Cozy Bookshop with Cat & Free Coffee',
    description: 'Found the cutest independent bookstore with a resident cat named Muffin. They serve free coffee to anyone browsing. Owner curates the most interesting collection of rare books.',
    image: 'https://images.unsplash.com/photo-1639545969221-db8f02a3f3b0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx2aW50YWdlJTIwYm9va3N0b3JlfGVufDF8fHx8MTc3NTcxOTcyOHww&ixlib=rb-4.1.0&q=80&w=1080',
    upvotes: 234,
    downvotes: 5,
    commentCount: 19,
    timestamp: '2026-04-06T11:30:00Z',
    saved: false,
    lat: 51.5264,
    lng: -0.0783,
  },
  {
    id: '5',
    userId: '1',
    username: 'AlexTheExplorer',
    userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',
    userKarma: 2847,
    isSuperUser: true,
    location: 'Le Marais, Paris',
    title: 'Family-Run Bakery Since 1892',
    description: 'This place is a time capsule. Original ovens, recipes passed down through generations. Their croissants are criminally underrated. Get there before 8am or they sell out.',
    image: 'https://images.unsplash.com/photo-1765980161513-8dc16b396634?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxsb2NhbCUyMGJha2VyeSUyMGZyZXNofGVufDF8fHx8MTc3NTgyNjY0Mnww&ixlib=rb-4.1.0&q=80&w=1080',
    upvotes: 1024,
    downvotes: 15,
    commentCount: 87,
    timestamp: '2026-04-05T07:20:00Z',
    saved: true,
    lat: 48.8589,
    lng: 2.3620,
  },
  {
    id: '6',
    userId: '3',
    username: 'MikeDiscovers',
    userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mike',
    userKarma: 3421,
    isSuperUser: true,
    location: 'Wynwood, Miami',
    title: 'Street Art Alley – Changes Every Month',
    description: 'Local artists repaint this alley every month. It\'s like a living gallery. Best time to visit is during First Fridays when artists are actually working on new pieces.',
    image: 'https://images.unsplash.com/photo-1758030306457-e54f25fe4384?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxzdHJlZXQlMjBhcnQlMjBtdXJhbHxlbnwxfHx8fDE3NzU3Mzg2MzB8MA&ixlib=rb-4.1.0&q=80&w=1080',
    upvotes: 423,
    downvotes: 7,
    commentCount: 35,
    timestamp: '2026-04-04T13:10:00Z',
    saved: false,
    lat: 25.8010,
    lng: -80.1995,
  },
];

export const mockComments: { [postId: string]: Comment[] } = {
  '1': [
    {
      id: 'c1',
      postId: '1',
      userId: '2',
      username: 'SarahLocal',
      userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
      userKarma: 1523,
      isSuperUser: false,
      content: 'Just visited based on this post! Absolutely stunning at golden hour. Thanks for sharing!',
      upvotes: 45,
      downvotes: 1,
      replies: [
        {
          id: 'c1-r1',
          postId: '1',
          userId: '1',
          username: 'AlexTheExplorer',
          userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',
          userKarma: 2847,
          isSuperUser: true,
          content: 'Glad you enjoyed it! Try going on a weekday evening for fewer people.',
          upvotes: 12,
          downvotes: 0,
          replies: [],
          timestamp: '2026-04-09T18:30:00Z',
        },
      ],
      timestamp: '2026-04-09T17:45:00Z',
    },
    {
      id: 'c2',
      postId: '1',
      userId: '3',
      username: 'MikeDiscovers',
      userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mike',
      userKarma: 3421,
      isSuperUser: true,
      content: 'Pro tip: There\'s a small cafe on the ground floor that stays open late. Perfect for grabbing a drink before heading up.',
      upvotes: 67,
      downvotes: 2,
      replies: [],
      timestamp: '2026-04-09T16:20:00Z',
    },
  ],
  '2': [
    {
      id: 'c3',
      postId: '2',
      userId: '1',
      username: 'AlexTheExplorer',
      userAvatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',
      userKarma: 2847,
      isSuperUser: true,
      content: 'Been going here for years! The pork and chive dumplings are life-changing.',
      upvotes: 89,
      downvotes: 3,
      replies: [],
      timestamp: '2026-04-08T10:30:00Z',
    },
  ],
};

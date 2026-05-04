import { createBrowserRouter, Navigate } from 'react-router';
import { Layout } from './components/Layout';
import { SplashScreen } from './screens/SplashScreen';
import { LoginScreen } from './screens/LoginScreen';
import { PostsScreen } from './screens/PostsScreen';
import { PostDetailScreen } from './screens/PostDetailScreen';
import { CreatePostScreen } from './screens/CreatePostScreen';
import { MapScreen } from './screens/MapScreen';
import { ChatScreen } from './screens/ChatScreen';
import { ConversationScreen } from './screens/ConversationScreen';
import { SearchScreen } from './screens/SearchScreen';
import { NotificationsScreen } from './screens/NotificationsScreen';
import { ProfileScreen } from './screens/ProfileScreen';
import { SavedPostsScreen } from './screens/SavedPostsScreen';
import { SettingsScreen } from './screens/SettingsScreen';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <SplashScreen />,
  },
  {
    path: '/login',
    element: <LoginScreen />,
  },
  {
    element: <Layout />,
    children: [
      {
        path: '/posts',
        element: <PostsScreen />,
      },
      {
        path: '/post/:id',
        element: <PostDetailScreen />,
      },
      {
        path: '/create-post',
        element: <CreatePostScreen />,
      },
      {
        path: '/map',
        element: <MapScreen />,
      },
      {
        path: '/chat',
        element: <ChatScreen />,
      },
      {
        path: '/conversation/:conversationId',
        element: <ConversationScreen />,
      },
      {
        path: '/search',
        element: <SearchScreen />,
      },
      {
        path: '/notifications',
        element: <NotificationsScreen />,
      },
      {
        path: '/profile',
        element: <ProfileScreen />,
      },
      {
        path: '/saved',
        element: <SavedPostsScreen />,
      },
      {
        path: '/settings',
        element: <SettingsScreen />,
      },
    ],
  },
]);

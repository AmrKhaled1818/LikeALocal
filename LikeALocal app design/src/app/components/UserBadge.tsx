import { Crown, TrendingUp } from 'lucide-react';
import { Badge } from './ui/badge';

interface UserBadgeProps {
  karma: number;
  isSuperUser: boolean;
  size?: 'sm' | 'md';
}

export function UserBadge({ karma, isSuperUser, size = 'md' }: UserBadgeProps) {
  const badgeSize = size === 'sm' ? 'text-xs px-1.5 py-0.5' : 'text-xs px-2 py-1';
  const iconSize = size === 'sm' ? 12 : 14;

  if (isSuperUser) {
    return (
      <Badge className={`${badgeSize} bg-gradient-to-r from-amber-500 to-orange-500 text-white border-0 gap-1`}>
        <Crown size={iconSize} />
        <span>Super User</span>
      </Badge>
    );
  }

  return (
    <Badge variant="secondary" className={`${badgeSize} gap-1`}>
      <TrendingUp size={iconSize} />
      <span>{karma.toLocaleString()} karma</span>
    </Badge>
  );
}

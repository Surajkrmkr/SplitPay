import { ForbiddenError } from '../../utils/app-error';
import * as activityRepository from './activity.repository';
import { ActivityWithUser } from './activity.repository';
import * as groupsRepository from '../groups/groups.repository';

export async function getGroupActivity(
  groupId: string,
  userId: string
): Promise<ActivityWithUser[]> {
  // Verify membership
  const isMember = await groupsRepository.isMember(groupId, userId);
  if (!isMember) {
    throw new ForbiddenError('You are not a member of this group');
  }

  return activityRepository.findGroupActivities(groupId, 50);
}

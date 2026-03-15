import logger from '../utils/logger';
import { Response } from 'express';
import mongoose from 'mongoose';
import { AuthRequest } from '../middleware/auth';
import User from '../models/userModel';
import Interaction from '../models/interactionModel';
import Match from '../models/matchModel';
import Message from '../models/messageModel';
import Block from '../models/blockModel';
import { emitToUser } from '../socket';
import { sendPushNotification } from '../utils/apns';

const DAILY_LIKE_LIMIT = 20;

function calculateDistance(coord1: [number, number], coord2: [number, number]): number {
  const R = 6371e3;
  const lat1 = coord1[1] * (Math.PI / 180);
  const lat2 = coord2[1] * (Math.PI / 180);
  const dLat = (coord2[1] - coord1[1]) * (Math.PI / 180);
  const dLon = (coord2[0] - coord1[0]) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

/** 1日のいいね上限チェック＆インクリメント。上限超えたら false を返す */
async function checkAndIncrementDailyLike(userId: string): Promise<boolean> {
  const user = await User.findById(userId).select('dailyLikeCount dailyLikeResetAt');
  if (!user) return false;

  const now = new Date();
  const resetAt = user.dailyLikeResetAt;

  // リセット日時を過ぎていたらカウントリセット
  if (!resetAt || now >= resetAt) {
    const nextReset = new Date(now);
    nextReset.setHours(24, 0, 0, 0); // 翌日0時
    await User.findByIdAndUpdate(userId, { dailyLikeCount: 1, dailyLikeResetAt: nextReset });
    return true;
  }

  if (user.dailyLikeCount >= DAILY_LIKE_LIMIT) return false;

  await User.findByIdAndUpdate(userId, { $inc: { dailyLikeCount: 1 } });
  return true;
}

/**
 * 近くのユーザー取得
 */
export async function getNearbyUsers(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const limit = Math.min(parseInt(req.query.limit as string) || 10, 50);
    const radiusMeters = parseInt(req.query.radius as string) || 5000;
    const minAge = parseInt(req.query.minAge as string) || 18;
    const maxAge = parseInt(req.query.maxAge as string) || 120;

    const currentUser = await User.findById(req.userId).select('location dailyLikeCount dailyLikeResetAt');
    if (!currentUser) return res.status(404).json({ error: 'User not found' });

    const coords = currentUser.location?.coordinates;
    if (!coords || (coords[0] === 0 && coords[1] === 0)) {
      return res.status(400).json({ error: 'Location not set. Please update your location first.' });
    }

    const interactions = await Interaction.find({ fromUser: req.userId }).select('toUser');
    const userObjectId = new mongoose.Types.ObjectId(req.userId);
    const blocks = await Block.find({
      $or: [{ blocker: userObjectId }, { blocked: userObjectId }],
    }).select('blocker blocked');
    const blockedIds = blocks.map((b) =>
      b.blocker.toString() === req.userId ? b.blocked : b.blocker
    );

    const excludedIds = [
      userObjectId,
      ...interactions.map((i) => i.toUser),
      ...blockedIds,
    ];

    const nearbyUsers = await User.find({
      _id: { $nin: excludedIds },
      age: { $gte: minAge, $lte: maxAge },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: coords },
          $maxDistance: radiusMeters,
        },
      },
    })
      .limit(limit)
      .select('-password');

    // 自分をスーパーライクしたユーザーのIDセット
    const superlikedMeIds = new Set(
      (await Interaction.find({ toUser: req.userId, type: 'superlike' }).select('fromUser'))
        .map((i) => i.fromUser.toString())
    );

    // 残いいね数
    const now = new Date();
    const resetAt = currentUser.dailyLikeResetAt;
    const likesUsed = resetAt && now < resetAt ? currentUser.dailyLikeCount : 0;
    const likesRemaining = Math.max(0, DAILY_LIKE_LIMIT - likesUsed);

    const usersWithDistance = nearbyUsers.map((user) => ({
      _id: user._id,
      name: user.name,
      age: user.age,
      bio: user.bio || '',
      interests: user.interests || [],
      avatar: user.avatar,
      distance: calculateDistance(
        coords as [number, number],
        user.location!.coordinates as [number, number]
      ),
      lastActiveAt: user.lastActiveAt,
      superlikedMe: superlikedMeIds.has(user._id.toString()),
    }));

    res.json({ users: usersWithDistance, likesRemaining });
  } catch (error) {
    logger.error('Get nearby users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * マップ表示用：近くのユーザー取得（ファジー座標付き）
 * GET /api/matches/nearby-map
 */
export async function getNearbyUsersForMap(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const radiusMeters = 1000; // 1km固定
    const userObjectId = new mongoose.Types.ObjectId(req.userId);

    const currentUser = await User.findById(req.userId).select('location');
    if (!currentUser) return res.status(404).json({ error: 'User not found' });

    const coords = currentUser.location?.coordinates;
    if (!coords || (coords[0] === 0 && coords[1] === 0)) {
      return res.status(400).json({ error: 'Location not set' });
    }

    const blocks = await Block.find({
      $or: [{ blocker: userObjectId }, { blocked: userObjectId }],
    }).select('blocker blocked');
    const blockedIds = blocks.map((b) =>
      b.blocker.toString() === req.userId ? b.blocked : b.blocker
    );

    const nearbyUsers = await User.find({
      _id: { $nin: [userObjectId, ...blockedIds] },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: coords },
          $maxDistance: radiusMeters,
        },
      },
    })
      .limit(30)
      .select('_id name age bio avatar');

    // ユーザーIDをシードにした決定論的オフセット（リロードしても位置が変わらない）
    // 緯度/経度 1度 ≈ 111km なので 200m ≈ 0.0018度
    const FUZZY_RANGE = 0.0018;
    const seededFuzz = (id: string, salt: string): number => {
      let hash = 0;
      const str = id + salt;
      for (let i = 0; i < str.length; i++) {
        hash = ((hash << 5) - hash + str.charCodeAt(i)) | 0;
      }
      // -1〜1 の範囲に正規化してFUZZY_RANGEをかける
      return ((hash % 1000) / 1000) * FUZZY_RANGE;
    };

    const usersWithFuzzyCoords = nearbyUsers.map((user) => ({
      id: user._id,
      name: user.name,
      age: user.age,
      bio: user.bio,
      avatar: user.avatar,
      latitude: (coords[1] as number) + seededFuzz(user._id.toString(), 'lat'),
      longitude: (coords[0] as number) + seededFuzz(user._id.toString(), 'lng'),
    }));

    res.json({
      users: usersWithFuzzyCoords,
      center: { latitude: coords[1], longitude: coords[0] },
    });
  } catch (error) {
    logger.error('Get nearby users for map error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/** マッチング成立処理（like/superlikeで共通） */
async function processMatch(
  fromUserId: string,
  targetUserId: string,
  targetUser: InstanceType<typeof User>,
  res: Response
) {
  const [u1, u2] = [fromUserId, targetUserId].sort();
  const match = await Match.findOneAndUpdate(
    { user1: u1, user2: u2 },
    { matchedAt: new Date(), expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) },
    { upsert: true, new: true }
  );

  const currentUser = await User.findById(fromUserId).select('name age bio avatar');
  if (currentUser) {
    const matchData = {
      matchId: match._id,
      matchedUser: {
        _id: currentUser._id,
        name: currentUser.name,
        age: currentUser.age,
        bio: currentUser.bio,
        avatar: currentUser.avatar,
      },
      timestamp: new Date(),
    };
    emitToUser(targetUserId, 'match:new', matchData);

    if (targetUser.deviceToken) {
      await sendPushNotification(
        targetUser.deviceToken,
        'マッチング成立！',
        `${currentUser.name}さんとマッチしました`,
        { matchId: match._id.toString() }
      );
    }
  }

  return res.json({
    message: "It's a match!",
    matched: true,
    match: { _id: match._id, matchedAt: match.matchedAt },
  });
}

/**
 * いいね
 */
export async function likeUser(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { targetUserId } = req.body;
    if (!targetUserId) return res.status(400).json({ error: 'targetUserId is required' });
    if (targetUserId === req.userId) return res.status(400).json({ error: 'Cannot like yourself' });

    const targetUser = await User.findById(targetUserId);
    if (!targetUser) return res.status(404).json({ error: 'Target user not found' });

    const canLike = await checkAndIncrementDailyLike(req.userId);
    if (!canLike) {
      return res.status(429).json({ error: `1日${DAILY_LIKE_LIMIT}件のいいね上限に達しました`, limitReached: true });
    }

    await Interaction.findOneAndUpdate(
      { fromUser: req.userId, toUser: targetUserId },
      { type: 'like' },
      { upsert: true }
    );

    const mutualLike = await Interaction.findOne({
      fromUser: targetUserId,
      toUser: req.userId,
      type: { $in: ['like', 'superlike'] },
    });

    if (mutualLike) return processMatch(req.userId, targetUserId, targetUser, res);

    res.json({ message: 'Like sent', matched: false });
  } catch (error) {
    logger.error('Like user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * スーパーいいね
 */
export async function superlikeUser(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { targetUserId } = req.body;
    if (!targetUserId) return res.status(400).json({ error: 'targetUserId is required' });
    if (targetUserId === req.userId) return res.status(400).json({ error: 'Cannot superlike yourself' });

    const targetUser = await User.findById(targetUserId);
    if (!targetUser) return res.status(404).json({ error: 'Target user not found' });

    const canLike = await checkAndIncrementDailyLike(req.userId);
    if (!canLike) {
      return res.status(429).json({ error: `1日${DAILY_LIKE_LIMIT}件のいいね上限に達しました`, limitReached: true });
    }

    await Interaction.findOneAndUpdate(
      { fromUser: req.userId, toUser: targetUserId },
      { type: 'superlike' },
      { upsert: true }
    );

    // 相手に通知（まだマッチしていなくてもスーパーいいねを通知）
    emitToUser(targetUserId, 'superlike:received', { fromUserId: req.userId });
    if (targetUser.deviceToken) {
      const me = await User.findById(req.userId).select('name');
      await sendPushNotification(
        targetUser.deviceToken,
        'スーパーいいねが届きました！',
        `${me?.name ?? ''}さんがあなたにスーパーいいねしました`,
        {}
      );
    }

    const mutualLike = await Interaction.findOne({
      fromUser: targetUserId,
      toUser: req.userId,
      type: { $in: ['like', 'superlike'] },
    });

    if (mutualLike) return processMatch(req.userId, targetUserId, targetUser, res);

    res.json({ message: 'Superlike sent', matched: false });
  } catch (error) {
    logger.error('Superlike user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * スキップ
 */
export async function dislikeUser(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { targetUserId } = req.body;
    if (!targetUserId) return res.status(400).json({ error: 'targetUserId is required' });

    await Interaction.findOneAndUpdate(
      { fromUser: req.userId, toUser: targetUserId },
      { type: 'dislike' },
      { upsert: true }
    );

    res.json({ message: 'User skipped' });
  } catch (error) {
    logger.error('Dislike user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * 直前のスキップを取り消す
 */
export async function undoDislike(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const currentUser = await User.findById(req.userId);
    if (!currentUser) return res.status(404).json({ error: 'User not found' });

    const lastDislike = await Interaction.findOneAndDelete(
      { fromUser: req.userId, type: 'dislike' },
      { sort: { createdAt: -1 } }
    );

    if (!lastDislike) return res.status(404).json({ error: 'No recent skip to undo' });

    const restoredUser = await User.findById(lastDislike.toUser).select('-password');
    if (!restoredUser) return res.status(404).json({ error: 'User no longer exists' });

    const coords = currentUser.location?.coordinates;
    const distance =
      coords && restoredUser.location?.coordinates
        ? calculateDistance(coords as [number, number], restoredUser.location.coordinates as [number, number])
        : 0;

    res.json({
      user: {
        _id: restoredUser._id,
        name: restoredUser.name,
        age: restoredUser.age,
        bio: restoredUser.bio || '',
        interests: restoredUser.interests || [],
        avatar: restoredUser.avatar,
        distance,
        lastActiveAt: restoredUser.lastActiveAt,
        superlikedMe: false,
      },
    });
  } catch (error) {
    logger.error('Undo dislike error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * 自分にいいね/スーパーいいねしたユーザー一覧
 */
export async function getLikedMe(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const userObjectId = new mongoose.Types.ObjectId(req.userId);

    // 自分へのlike/superlike（自分がまだ返していないもの）
    const myInteractions = await Interaction.find({ fromUser: userObjectId }).select('toUser');
    const myInteractionIds = myInteractions.map((i) => i.toUser);

    const likesReceived = await Interaction.find({
      toUser: userObjectId,
      type: { $in: ['like', 'superlike'] },
      fromUser: { $nin: myInteractionIds },
    }).select('fromUser type createdAt');

    const users = await Promise.all(
      likesReceived.map(async (interaction) => {
        const user = await User.findById(interaction.fromUser).select('-password');
        if (!user) return null;
        return {
          _id: user._id,
          name: user.name,
          age: user.age,
          bio: user.bio || '',
          interests: user.interests || [],
          avatar: user.avatar,
          isSuperLike: interaction.type === 'superlike',
          likedAt: interaction.createdAt,
        };
      })
    );

    res.json({ users: users.filter((u) => u !== null) });
  } catch (error) {
    logger.error('Get liked me error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * マッチング一覧取得
 */
export async function getMatches(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const userObjectId = new mongoose.Types.ObjectId(req.userId);
    const now = new Date();
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, parseInt(req.query.limit as string) || 20);
    const skip = (page - 1) * limit;

    const total = await Match.countDocuments({
      $or: [{ user1: userObjectId }, { user2: userObjectId }],
      expiresAt: { $gt: now },
    });

    const matches = await Match.find({
      $or: [{ user1: userObjectId }, { user2: userObjectId }],
      expiresAt: { $gt: now }, // 期限切れを除外
    }).sort({ matchedAt: -1 }).skip(skip).limit(limit);

    const matchesWithUsers = await Promise.all(
      matches.map(async (match) => {
        const matchedUserId = match.user1.toString() === req.userId ? match.user2 : match.user1;
        const matchedUser = await User.findById(matchedUserId).select('-password');
        if (!matchedUser) return null;

        const unreadCount = await Message.countDocuments({
          matchId: match._id,
          senderId: { $ne: userObjectId },
          read: false,
        });

        const lastMsg = await Message.findOne({ matchId: match._id })
          .sort({ createdAt: -1 })
          .select('content senderId createdAt');

        return {
          _id: match._id,
          matchedUser: {
            _id: matchedUser._id,
            name: matchedUser.name,
            age: matchedUser.age,
            bio: matchedUser.bio,
            interests: matchedUser.interests || [],
            avatar: matchedUser.avatar,
          },
          matchedAt: match.matchedAt,
          expiresAt: match.expiresAt,
          unreadCount,
          lastMessage: lastMsg
            ? { content: lastMsg.content, senderId: lastMsg.senderId.toString(), createdAt: lastMsg.createdAt }
            : null,
        };
      })
    );

    const validMatches = matchesWithUsers.filter((m) => m !== null);
    res.json({
      matches: validMatches,
      total,
      page,
      pages: Math.ceil(total / limit),
      hasMore: page * limit < total,
    });
  } catch (error) {
    logger.error('Get matches error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export default { getNearbyUsers, likeUser, superlikeUser, dislikeUser, undoDislike, getLikedMe, getMatches };

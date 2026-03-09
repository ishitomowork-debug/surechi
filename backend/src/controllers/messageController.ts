import { Response } from 'express';
import mongoose from 'mongoose';
import { AuthRequest } from '../middleware/auth';
import Message from '../models/messageModel';
import Match from '../models/matchModel';
import { emitToUser } from '../socket';

/**
 * メッセージ一覧取得
 * GET /api/messages/:matchId
 */
export async function getMessages(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { matchId } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const offset = parseInt(req.query.offset as string) || 0;

    // 自分がマッチングのメンバーか確認
    const userObjectId = new mongoose.Types.ObjectId(req.userId);
    const match = await Match.findOne({
      _id: matchId,
      $or: [{ user1: userObjectId }, { user2: userObjectId }],
    });

    if (!match) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const messages = await Message.find({ matchId })
      .sort({ createdAt: 1 })
      .skip(offset)
      .limit(limit);

    res.json({ messages });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * 既読にする
 * PUT /api/messages/:matchId/read
 */
export async function markAsRead(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { matchId } = req.params;

    // 自分がマッチのメンバーか確認し、相手ユーザーIDを取得
    const userObjectId = new mongoose.Types.ObjectId(req.userId);
    const match = await Match.findOne({
      _id: matchId,
      $or: [{ user1: userObjectId }, { user2: userObjectId }],
    });
    if (!match) return res.status(403).json({ error: 'Access denied' });

    const result = await Message.updateMany(
      { matchId, senderId: { $ne: req.userId }, read: false },
      { read: true }
    );

    // 相手ユーザーに既読通知（Socket.IO）
    if (result.modifiedCount > 0) {
      const otherUserId =
        match.user1.toString() === req.userId
          ? match.user2.toString()
          : match.user1.toString();
      emitToUser(otherUserId, 'message:read', { matchId });
    }

    res.json({ updated: result.modifiedCount });
  } catch (error) {
    console.error('Mark as read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export default { getMessages, markAsRead };

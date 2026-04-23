import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';
import User from '../models/userModel';

/**
 * 年齢確認（本人確認）が承認済みのユーザーのみアクセス可能なミドルウェア
 * 出会い系サイト規制法に基づく年齢確認ゲーティング
 */
export async function requireVerification(
  req: AuthRequest,
  res: Response,
  next: NextFunction
) {
  try {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const user = await User.findById(req.userId).select('verificationStatus');
    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    if (user.verificationStatus !== 'approved') {
      return res.status(403).json({
        error: 'Age verification required',
        verificationStatus: user.verificationStatus,
      });
    }

    next();
  } catch (error) {
    console.error('requireVerification error:', error);
    res.status(500).json({ error: 'Verification check failed' });
  }
}

/**
 * Socket.IO 用の年齢確認チェック
 * 承認済みなら true を返す
 */
export async function isUserVerified(userId: string): Promise<boolean> {
  try {
    const user = await User.findById(userId).select('verificationStatus');
    return user?.verificationStatus === 'approved';
  } catch {
    return false;
  }
}

export default requireVerification;

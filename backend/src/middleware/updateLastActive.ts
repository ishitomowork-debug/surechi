import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';
import User from '../models/userModel';

/** 認証済みリクエスト毎に lastActiveAt を更新（最大1分に1回） */
export async function updateLastActive(req: AuthRequest, res: Response, next: NextFunction) {
  if (req.userId) {
    // 非同期で更新、レスポンスをブロックしない
    User.findByIdAndUpdate(req.userId, { lastActiveAt: new Date() }).catch(() => {});
  }
  next();
}

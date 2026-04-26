import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';

/**
 * 管理者のみアクセス可能なミドルウェア
 * Phase 1 では DEV_USER_ID による単純な管理者判定を使用する
 * 将来的には User.role === 'admin' などに置き換える
 */
export function requireAdmin(req: AuthRequest, res: Response, next: NextFunction) {
  const allowedId = process.env.DEV_USER_ID;
  if (!allowedId || req.userId !== allowedId) {
    return res.status(403).json({ error: 'Forbidden: admin only' });
  }
  next();
}

export default requireAdmin;

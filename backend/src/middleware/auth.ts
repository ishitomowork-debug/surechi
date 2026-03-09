import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import User from '../models/userModel';

export interface JWTPayload {
  userId: string;
}

export interface AuthRequest extends Request {
  userId?: string;
}

/**
 * JWT 認証ミドルウェア
 */
export function authMiddleware(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret') as JWTPayload;
    req.userId = decoded.userId;
    // lastActiveAt を非同期で更新（リクエストをブロックしない）
    User.findByIdAndUpdate(decoded.userId, { lastActiveAt: new Date() }).exec().catch(() => {});
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

/**
 * JWT トークン生成
 */
export function generateToken(userId: string): string {
  return jwt.sign({ userId }, process.env.JWT_SECRET || 'secret', {
    expiresIn: '7d',
  } as jwt.SignOptions);
}

export default authMiddleware;

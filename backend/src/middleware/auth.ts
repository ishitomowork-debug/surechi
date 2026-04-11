import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import User from '../models/userModel';

export interface JWTPayload {
  userId: string;
}

export interface AuthRequest extends Request {
  userId?: string;
}

function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET environment variable must be set');
  return secret;
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

    const decoded = jwt.verify(token, getJwtSecret()) as JWTPayload;
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
  return jwt.sign({ userId }, getJwtSecret(), {
    expiresIn: '7d',
  } as jwt.SignOptions);
}

export default authMiddleware;

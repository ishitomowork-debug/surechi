import { Request, Response } from 'express';
import crypto from 'crypto';
import User from '../models/userModel';
import Match from '../models/matchModel';
import Interaction from '../models/interactionModel';
import Block from '../models/blockModel';
import Report from '../models/reportModel';
import Message from '../models/messageModel';
import RefreshToken from '../models/refreshTokenModel';
import { generateToken } from '../middleware/auth';
import { sendVerificationEmail, sendPasswordResetEmail } from '../utils/mailer';
import logger from '../utils/logger';

const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;

async function issueRefreshToken(userId: string): Promise<string> {
  const token = crypto.randomBytes(40).toString('hex');
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30日
  await RefreshToken.create({ userId, token, expiresAt });
  return token;
}

/**
 * ユーザー登録
 * POST /api/auth/register
 */
export async function register(req: Request, res: Response) {
  try {
    const { name, email, password, age, bio } = req.body;

    if (!name || !email || !password || !age) {
      return res.status(400).json({ error: 'Missing required fields: name, email, password, age' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    if (!PASSWORD_REGEX.test(password)) {
      return res.status(400).json({
        error: 'Password must be at least 8 characters and include uppercase, lowercase, and a number',
      });
    }

    if (age < 18 || age > 120) {
      return res.status(400).json({ error: 'Age must be between 18 and 120' });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ error: 'Email already in use' });
    }

    const verificationToken = crypto.randomBytes(32).toString('hex');
    const verificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const newUser = new User({
      name,
      email,
      password,
      age,
      bio: bio || '',
      emailVerificationToken: verificationToken,
      emailVerificationExpires: verificationExpires,
    });

    await newUser.save();

    // メール確認送信（失敗しても登録は成功扱い）
    sendVerificationEmail(email, verificationToken).catch((err) =>
      logger.error('Failed to send verification email:', err)
    );

    const token = generateToken(newUser._id.toString());
    const refreshToken = await issueRefreshToken(newUser._id.toString());

    res.status(201).json({
      message: 'User registered successfully. Please verify your email.',
      token,
      refreshToken,
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        age: newUser.age,
        emailVerified: newUser.emailVerified,
      },
    });
  } catch (error) {
    logger.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * ユーザーログイン
 * POST /api/auth/login
 */
export async function login(req: Request, res: Response) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Missing required fields: email, password' });
    }

    const user = await User.findOne({ email }).select('+password');

    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = generateToken(user._id.toString());
    const refreshToken = await issueRefreshToken(user._id.toString());

    res.json({
      message: 'Login successful',
      token,
      refreshToken,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        age: user.age,
        emailVerified: user.emailVerified,
      },
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * プロフィール取得
 * GET /api/auth/me
 */
export async function getProfile(req: Request & { userId?: string }, res: Response) {
  try {
    if (!req.userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const user = await User.findById(req.userId).select('-password');

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        age: user.age,
        bio: user.bio,
        avatar: user.avatar,
        emailVerified: user.emailVerified,
      },
    });
  } catch (error) {
    logger.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * メールアドレス確認
 * GET /api/auth/verify-email?token=xxx
 */
export async function verifyEmail(req: Request, res: Response) {
  try {
    const { token } = req.query;

    if (!token || typeof token !== 'string') {
      return res.status(400).json({ error: 'Invalid token' });
    }

    const user = await User.findOne({
      emailVerificationToken: token,
      emailVerificationExpires: { $gt: new Date() },
    }).select('+emailVerificationToken +emailVerificationExpires');

    if (!user) {
      return res.status(400).json({ error: 'Invalid or expired verification token' });
    }

    user.emailVerified = true;
    user.emailVerificationToken = undefined;
    user.emailVerificationExpires = undefined;
    await user.save();

    res.json({ message: 'Email verified successfully' });
  } catch (error) {
    logger.error('Email verification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * パスワードリセットメール送信
 * POST /api/auth/forgot-password
 */
export async function forgotPassword(req: Request, res: Response) {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const user = await User.findOne({ email }).select('+passwordResetToken +passwordResetExpires');

    // ユーザーが存在しない場合も同じレスポンス（ユーザー列挙攻撃対策）
    if (!user) {
      return res.json({ message: 'If that email exists, a reset link has been sent' });
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    user.passwordResetToken = resetToken;
    user.passwordResetExpires = new Date(Date.now() + 60 * 60 * 1000); // 1時間
    await user.save();

    sendPasswordResetEmail(email, resetToken).catch((err) =>
      logger.error('Failed to send password reset email:', err)
    );

    res.json({ message: 'If that email exists, a reset link has been sent' });
  } catch (error) {
    logger.error('Forgot password error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * パスワードリセット
 * POST /api/auth/reset-password
 */
export async function resetPassword(req: Request, res: Response) {
  try {
    const { token, password } = req.body;

    if (!token || !password) {
      return res.status(400).json({ error: 'Token and password are required' });
    }

    if (!PASSWORD_REGEX.test(password)) {
      return res.status(400).json({
        error: 'Password must be at least 8 characters and include uppercase, lowercase, and a number',
      });
    }

    const user = await User.findOne({
      passwordResetToken: token,
      passwordResetExpires: { $gt: new Date() },
    }).select('+password +passwordResetToken +passwordResetExpires');

    if (!user) {
      return res.status(400).json({ error: 'Invalid or expired reset token' });
    }

    user.password = password;
    user.passwordResetToken = undefined;
    user.passwordResetExpires = undefined;
    await user.save();

    res.json({ message: 'Password reset successfully' });
  } catch (error) {
    logger.error('Reset password error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * アカウント削除（Apple審査要件）
 * DELETE /api/auth/account
 */
export async function deleteAccount(req: Request & { userId?: string }, res: Response) {
  try {
    if (!req.userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const userId = req.userId;

    // 関連データを全て削除
    await Promise.all([
      Match.deleteMany({ $or: [{ user1: userId }, { user2: userId }] }),
      Interaction.deleteMany({ $or: [{ from: userId }, { to: userId }] }),
      Block.deleteMany({ $or: [{ blocker: userId }, { blocked: userId }] }),
      Report.deleteMany({ reporter: userId }),
      Message.deleteMany({ senderId: userId }),
    ]);

    await User.findByIdAndDelete(userId);

    res.json({ message: 'Account deleted successfully' });
  } catch (error) {
    logger.error('Delete account error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * アクセストークンをリフレッシュ
 * POST /api/auth/refresh
 */
export async function refreshAccessToken(req: Request, res: Response) {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token is required' });
    }

    const stored = await RefreshToken.findOne({
      token: refreshToken,
      expiresAt: { $gt: new Date() },
    });

    if (!stored) {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    const newAccessToken = generateToken(stored.userId.toString());
    res.json({ token: newAccessToken });
  } catch (error) {
    logger.error('Refresh token error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * ログアウト（リフレッシュトークン無効化）
 * POST /api/auth/logout
 */
export async function logout(req: Request, res: Response) {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await RefreshToken.deleteOne({ token: refreshToken });
    }
    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    logger.error('Logout error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export default { register, login, getProfile, verifyEmail, forgotPassword, resetPassword, deleteAccount, refreshAccessToken, logout };

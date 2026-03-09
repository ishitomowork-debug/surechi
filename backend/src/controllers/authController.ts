import { Request, Response } from 'express';
import User from '../models/userModel';
import { generateToken } from '../middleware/auth';

/**
 * ユーザー登録
 * POST /api/auth/register
 */
export async function register(req: Request, res: Response) {
  try {
    const { name, email, password, age, bio } = req.body;

    // バリデーション
    if (!name || !email || !password || !age) {
      return res.status(400).json({
        error: 'Missing required fields: name, email, password, age',
      });
    }

    // メール形式チェック
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    // 年齢チェック
    if (age < 18 || age > 120) {
      return res.status(400).json({ error: 'Age must be between 18 and 120' });
    }

    // メール重複チェック
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ error: 'Email already in use' });
    }

    // ユーザー作成
    const newUser = new User({
      name,
      email,
      password,
      age,
      bio: bio || '',
    });

    await newUser.save();

    // トークン生成
    const token = generateToken(newUser._id.toString());

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        age: newUser.age,
      },
    });
  } catch (error) {
    console.error('Registration error:', error);
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

    // バリデーション
    if (!email || !password) {
      return res.status(400).json({
        error: 'Missing required fields: email, password',
      });
    }

    // ユーザー取得（パスワード含める）
    const user = await User.findOne({ email }).select('+password');

    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // パスワード検証
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // トークン生成
    const token = generateToken(user._id.toString());

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        age: user.age,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
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
      },
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export default { register, login, getProfile };

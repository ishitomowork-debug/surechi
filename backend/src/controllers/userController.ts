import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import User from '../models/userModel';
import Block from '../models/blockModel';
import Report from '../models/reportModel';
import mongoose from 'mongoose';

/**
 * プロフィール取得
 * GET /api/users/profile
 */
export async function getProfile(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const user = await User.findById(req.userId).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });

    res.json({
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        age: user.age,
        bio: user.bio,
        interests: user.interests || [],
        avatar: user.avatar,
        coins: user.coins ?? 0,
        location: user.location,
      },
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * プロフィール更新
 * PUT /api/users/profile
 */
export async function updateProfile(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { name, age, bio, interests, avatar } = req.body;
    const updates: Record<string, string | number | string[]> = {};

    if (name !== undefined) updates.name = name;
    if (age !== undefined) {
      if (age < 18 || age > 120) {
        return res.status(400).json({ error: 'Age must be between 18 and 120' });
      }
      updates.age = age;
    }
    if (bio !== undefined) updates.bio = bio;
    if (interests !== undefined) updates.interests = interests;
    if (avatar !== undefined) updates.avatar = avatar;

    const user = await User.findByIdAndUpdate(req.userId, updates, {
      new: true,
      runValidators: true,
    }).select('-password');

    if (!user) return res.status(404).json({ error: 'User not found' });

    res.json({
      message: 'Profile updated',
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        age: user.age,
        bio: user.bio,
        interests: user.interests || [],
        avatar: user.avatar,
      },
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * 位置情報更新
 * PUT /api/users/location
 */
export async function updateLocation(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { latitude, longitude } = req.body;

    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({ error: 'latitude and longitude are required' });
    }

    await User.findByIdAndUpdate(req.userId, {
      location: {
        type: 'Point',
        coordinates: [longitude, latitude], // MongoDB: [longitude, latitude]
      },
    });

    res.json({ message: 'Location updated' });
  } catch (error) {
    console.error('Update location error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * ユーザーブロック
 * POST /api/users/block/:userId
 */
export async function blockUser(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { userId: targetId } = req.params;
    if (targetId === req.userId) {
      return res.status(400).json({ error: 'Cannot block yourself' });
    }

    const blocker = new mongoose.Types.ObjectId(req.userId);
    const blocked = new mongoose.Types.ObjectId(targetId);

    await Block.findOneAndUpdate(
      { blocker, blocked },
      { blocker, blocked },
      { upsert: true }
    );

    res.json({ message: 'User blocked' });
  } catch (error) {
    console.error('Block user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * ユーザー報告
 * POST /api/users/report/:userId
 */
export async function reportUser(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { userId: targetId } = req.params;
    const { reason } = req.body;

    if (!reason) return res.status(400).json({ error: 'reason is required' });
    if (targetId === req.userId) {
      return res.status(400).json({ error: 'Cannot report yourself' });
    }

    await Report.create({
      reporter: new mongoose.Types.ObjectId(req.userId),
      reported: new mongoose.Types.ObjectId(targetId),
      reason,
    });

    res.json({ message: 'User reported' });
  } catch (error) {
    console.error('Report user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * デバイストークン更新（プッシュ通知用）
 * PUT /api/users/device-token
 */
export async function updateDeviceToken(req: AuthRequest, res: Response) {
  try {
    if (!req.userId) return res.status(401).json({ error: 'Not authenticated' });

    const { deviceToken } = req.body;
    if (!deviceToken) return res.status(400).json({ error: 'deviceToken is required' });

    await User.findByIdAndUpdate(req.userId, { deviceToken });
    res.json({ message: 'Device token updated' });
  } catch (error) {
    console.error('Update device token error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export default { getProfile, updateProfile, updateLocation, blockUser, reportUser, updateDeviceToken };

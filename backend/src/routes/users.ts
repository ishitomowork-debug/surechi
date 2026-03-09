import { Router } from 'express';
import authMiddleware from '../middleware/auth';
import {
  getProfile,
  updateProfile,
  updateLocation,
  blockUser,
  reportUser,
  updateDeviceToken,
} from '../controllers/userController';

const router = Router();

/**
 * GET /api/users/profile
 * プロフィール取得
 */
router.get('/profile', authMiddleware, getProfile);

/**
 * PUT /api/users/profile
 * プロフィール更新
 */
router.put('/profile', authMiddleware, updateProfile);

/**
 * PUT /api/users/location
 * 位置情報更新
 */
router.put('/location', authMiddleware, updateLocation);

/**
 * POST /api/users/block/:userId
 * ユーザーブロック
 */
router.post('/block/:userId', authMiddleware, blockUser);

/**
 * POST /api/users/report/:userId
 * ユーザー報告
 */
router.post('/report/:userId', authMiddleware, reportUser);

/**
 * PUT /api/users/device-token
 * APNs デバイストークン更新
 */
router.put('/device-token', authMiddleware, updateDeviceToken);

export default router;

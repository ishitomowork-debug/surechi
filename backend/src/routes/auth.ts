import { Router } from 'express';
import { register, login, getProfile } from '../controllers/authController';
import authMiddleware from '../middleware/auth';

const router = Router();

/**
 * POST /api/auth/register
 * ユーザー登録
 */
router.post('/register', register);

/**
 * POST /api/auth/login
 * ユーザーログイン
 */
router.post('/login', login);

/**
 * GET /api/auth/me
 * 認証済みユーザーのプロフィール取得
 */
router.get('/me', authMiddleware, getProfile);

export default router;

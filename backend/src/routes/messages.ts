import { Router } from 'express';
import authMiddleware from '../middleware/auth';
import requireVerification from '../middleware/requireVerification';
import { getMessages, markAsRead } from '../controllers/messageController';

const router = Router();

/**
 * GET /api/messages/:matchId
 * メッセージ一覧取得
 */
router.get('/:matchId', authMiddleware, requireVerification, getMessages);

/**
 * PUT /api/messages/:matchId/read
 * 既読にする
 */
router.put('/:matchId/read', authMiddleware, requireVerification, markAsRead);

export default router;

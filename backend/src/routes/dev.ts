import express from 'express';
import { seedNearbyUsers } from '../controllers/devController';
import authMiddleware from '../middleware/auth';
import { AuthRequest } from '../middleware/auth';
import { Response } from 'express';
import { getIO, userSocketMap } from '../socket';

const router = express.Router();

router.post('/seed', authMiddleware, seedNearbyUsers);

// すれ違いシミュレート: 自分のSocketにモックの encounter:nearby を送信
router.post('/simulate-encounter', authMiddleware, (req: AuthRequest, res: Response) => {
  const userId = req.userId!;
  const socketId = userSocketMap.get(userId);

  if (!socketId) {
    return res.status(400).json({ error: 'Not connected via Socket.IO' });
  }

  const mockUser = {
    id: 'mock-encounter-user',
    name: 'テスト太郎',
    age: 26,
    bio: 'すれ違いテスト用ユーザーです',
    avatar: null,
  };

  getIO().to(socketId).emit('encounter:nearby', { user: mockUser });
  res.json({ message: 'Encounter simulated', user: mockUser });
});

export default router;

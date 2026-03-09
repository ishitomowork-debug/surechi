import { Router } from 'express';
import authMiddleware from '../middleware/auth';
import {
  getNearbyUsers,
  getNearbyUsersForMap,
  likeUser,
  superlikeUser,
  dislikeUser,
  undoDislike,
  getLikedMe,
  getMatches,
} from '../controllers/matchController';

const router = Router();

router.get('/nearby', authMiddleware, getNearbyUsers);
router.get('/nearby-map', authMiddleware, getNearbyUsersForMap);
router.post('/like', authMiddleware, likeUser);
router.post('/superlike', authMiddleware, superlikeUser);
router.post('/dislike', authMiddleware, dislikeUser);
router.post('/undo', authMiddleware, undoDislike);
router.get('/liked-me', authMiddleware, getLikedMe);
router.get('/matched', authMiddleware, getMatches);

export default router;

import { Router } from 'express';
import authMiddleware from '../middleware/auth';
import { updateLastActive } from '../middleware/updateLastActive';
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

router.get('/nearby', authMiddleware, updateLastActive, getNearbyUsers);
router.get('/nearby-map', authMiddleware, getNearbyUsersForMap);
router.post('/like', authMiddleware, likeUser);
router.post('/superlike', authMiddleware, superlikeUser);
router.post('/dislike', authMiddleware, dislikeUser);
router.post('/undo', authMiddleware, undoDislike);
router.get('/liked-me', authMiddleware, getLikedMe);
router.get('/matched', authMiddleware, updateLastActive, getMatches);

export default router;

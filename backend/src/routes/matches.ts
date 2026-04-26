import { Router } from 'express';
import authMiddleware from '../middleware/auth';
import requireVerification from '../middleware/requireVerification';
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
router.post('/like', authMiddleware, requireVerification, likeUser);
router.post('/superlike', authMiddleware, requireVerification, superlikeUser);
router.post('/dislike', authMiddleware, requireVerification, dislikeUser);
router.post('/undo', authMiddleware, requireVerification, undoDislike);
router.get('/liked-me', authMiddleware, getLikedMe);
router.get('/matched', authMiddleware, updateLastActive, getMatches);

export default router;

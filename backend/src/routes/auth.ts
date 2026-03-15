import { Router } from 'express';
import {
  register,
  login,
  getProfile,
  verifyEmail,
  forgotPassword,
  resetPassword,
  deleteAccount,
  refreshAccessToken,
  logout,
} from '../controllers/authController';
import authMiddleware from '../middleware/auth';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.post('/logout', logout);
router.post('/refresh', refreshAccessToken);
router.get('/me', authMiddleware, getProfile);
router.get('/verify-email', verifyEmail);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.delete('/account', authMiddleware, deleteAccount);

export default router;

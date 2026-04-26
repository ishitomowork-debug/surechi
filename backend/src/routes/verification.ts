import { Router, Response } from 'express';
import rateLimit from 'express-rate-limit';
import authMiddleware, { AuthRequest } from '../middleware/auth';
import requireAdmin from '../middleware/requireAdmin';
import User from '../models/userModel';

const router = Router();

// ─── ユーザー向けエンドポイント ──────────────────────────────────────────────

/**
 * 提出回数レート制限: 1日3回まで
 */
const submitLimiter = rateLimit({
  windowMs: 24 * 60 * 60 * 1000, // 24h
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many verification submissions, please try again tomorrow' },
  // テスト環境ではレート制限を無効化
  skip: () => process.env.NODE_ENV === 'test',
});

/**
 * base64 文字列を検証する
 * - data URL 形式 (data:image/...;base64,xxx) または raw base64 を許容
 * - 最低限のサイズと文字種チェック
 */
function validateBase64Image(input: unknown): { ok: true; normalized: string } | { ok: false; error: string } {
  if (typeof input !== 'string') {
    return { ok: false, error: 'idImageBase64 must be a string' };
  }

  let raw = input.trim();
  if (raw.length === 0) {
    return { ok: false, error: 'idImageBase64 is empty' };
  }

  // data URL プレフィックスを許容
  const dataUrlMatch = raw.match(/^data:image\/(png|jpe?g|webp|heic|heif);base64,(.+)$/i);
  if (dataUrlMatch) {
    raw = dataUrlMatch[2];
  }

  // base64 文字種チェック
  if (!/^[A-Za-z0-9+/=\s]+$/.test(raw)) {
    return { ok: false, error: 'idImageBase64 contains invalid characters' };
  }

  // 最低サイズ: 100bytes 程度の base64 文字列が必要
  const cleaned = raw.replace(/\s/g, '');
  if (cleaned.length < 100) {
    return { ok: false, error: 'idImageBase64 is too small' };
  }

  // 最大サイズ: 約 7MB の画像 (base64 で ~10MB)
  if (cleaned.length > 10 * 1024 * 1024) {
    return { ok: false, error: 'idImageBase64 is too large (max ~7MB)' };
  }

  return { ok: true, normalized: cleaned };
}

/**
 * POST /api/verification/submit
 * 年齢確認書類を提出する
 */
router.post('/submit', authMiddleware, submitLimiter, async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId!;
    const { idImageBase64 } = req.body as { idImageBase64?: unknown };

    const result = validateBase64Image(idImageBase64);
    if (!result.ok) {
      return res.status(400).json({ error: result.error });
    }

    const user = await User.findById(userId).select('verificationStatus');
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.verificationStatus === 'approved') {
      return res.status(400).json({ error: 'Already verified' });
    }
    if (user.verificationStatus === 'pending') {
      return res.status(400).json({ error: 'Verification already pending' });
    }

    await User.findByIdAndUpdate(userId, {
      verificationStatus: 'pending',
      idImageBase64: result.normalized,
      verificationSubmittedAt: new Date(),
      verificationNote: undefined,
    });

    res.json({ status: 'pending', message: 'Submitted for review' });
  } catch (error) {
    console.error('verification submit error:', error);
    res.status(500).json({ error: 'Failed to submit verification' });
  }
});

/**
 * GET /api/verification/status
 * 自分の年齢確認ステータスを取得する
 */
router.get('/status', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const user = await User.findById(req.userId).select(
      'verificationStatus verifiedAt verificationNote verificationSubmittedAt'
    );
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({
      status: user.verificationStatus,
      verifiedAt: user.verifiedAt ?? null,
      verificationNote: user.verificationNote ?? null,
      submittedAt: user.verificationSubmittedAt ?? null,
    });
  } catch (error) {
    console.error('verification status error:', error);
    res.status(500).json({ error: 'Failed to fetch status' });
  }
});

// ─── 管理者向けエンドポイント ────────────────────────────────────────────────

/**
 * GET /api/verification/admin/pending
 * 承認待ちユーザー一覧
 */
router.get(
  '/admin/pending',
  authMiddleware,
  requireAdmin,
  async (_req: AuthRequest, res: Response) => {
    try {
      const users = await User.find({ verificationStatus: 'pending' })
        .select('+idImageBase64')
        .select('_id name verificationSubmittedAt idImageBase64')
        .sort({ verificationSubmittedAt: 1 })
        .limit(100);

      res.json({
        users: users.map((u) => ({
          id: u._id,
          displayName: u.name,
          submittedAt: u.verificationSubmittedAt,
          idImageBase64: u.idImageBase64,
        })),
      });
    } catch (error) {
      console.error('admin pending error:', error);
      res.status(500).json({ error: 'Failed to fetch pending users' });
    }
  }
);

/**
 * POST /api/verification/admin/:userId/approve
 */
router.post(
  '/admin/:userId/approve',
  authMiddleware,
  requireAdmin,
  async (req: AuthRequest, res: Response) => {
    try {
      const { userId } = req.params;
      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      if (user.verificationStatus !== 'pending') {
        return res.status(400).json({ error: 'User is not pending verification' });
      }

      user.verificationStatus = 'approved';
      user.verifiedAt = new Date();
      user.idImageBase64 = undefined; // 承認後は ID 画像を保持しない（個人情報保護）
      user.verificationNote = undefined;
      await user.save();

      res.json({ status: 'approved', userId: user._id });
    } catch (error) {
      console.error('admin approve error:', error);
      res.status(500).json({ error: 'Failed to approve user' });
    }
  }
);

/**
 * POST /api/verification/admin/:userId/reject
 */
router.post(
  '/admin/:userId/reject',
  authMiddleware,
  requireAdmin,
  async (req: AuthRequest, res: Response) => {
    try {
      const { userId } = req.params;
      const { note } = req.body as { note?: string };

      if (!note || typeof note !== 'string' || note.trim().length === 0) {
        return res.status(400).json({ error: 'Rejection note is required' });
      }
      if (note.length > 1000) {
        return res.status(400).json({ error: 'Rejection note too long' });
      }

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      if (user.verificationStatus !== 'pending') {
        return res.status(400).json({ error: 'User is not pending verification' });
      }

      user.verificationStatus = 'rejected';
      user.verificationNote = note.trim();
      user.idImageBase64 = undefined; // 却下時も ID 画像を保持しない
      await user.save();

      res.json({ status: 'rejected', userId: user._id });
    } catch (error) {
      console.error('admin reject error:', error);
      res.status(500).json({ error: 'Failed to reject user' });
    }
  }
);

export default router;

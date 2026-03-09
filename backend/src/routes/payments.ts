import { Router } from 'express';
import { Response } from 'express';
import authMiddleware, { AuthRequest } from '../middleware/auth';
import User from '../models/userModel';

const router = Router();

// コインパッケージ定義
const COIN_PACKAGES = [
  { id: 'coins_10',  coins: 10,  price: 120,  label: '10コイン' },
  { id: 'coins_60',  coins: 60,  price: 610,  label: '60コイン (おすすめ)' },
  { id: 'coins_130', coins: 130, price: 1220, label: '130コイン (お得)' },
];

// パッケージ一覧取得
router.get('/packages', (_req, res) => {
  res.json({ packages: COIN_PACKAGES });
});

// コイン残高取得
router.get('/balance', authMiddleware, async (req: AuthRequest, res: Response) => {
  const user = await User.findById(req.userId).select('coins');
  res.json({ coins: user?.coins ?? 0 });
});

// 購入処理（レシート検証はStoreKit連携時に実装）
router.post('/purchase', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { packageId, receiptData } = req.body;
    const pkg = COIN_PACKAGES.find(p => p.id === packageId);
    if (!pkg) return res.status(400).json({ error: 'Invalid package' });

    // TODO: receiptData を Apple に送って検証
    // 開発中はスキップしてコインを付与
    const user = await User.findByIdAndUpdate(
      req.userId,
      { $inc: { coins: pkg.coins } },
      { new: true }
    ).select('coins');

    res.json({ coins: user?.coins ?? 0, added: pkg.coins });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;

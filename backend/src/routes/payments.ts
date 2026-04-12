import { Router } from 'express';
import { Response } from 'express';
import rateLimit from 'express-rate-limit';
import authMiddleware, { AuthRequest } from '../middleware/auth';
import User from '../models/userModel';
import ProcessedTransaction from '../models/processedTransactionModel';
import { verifyAppleJWS, AppleVerificationError } from '../utils/appleStoreKit';
import logger from '../utils/logger';

const router = Router();

// 購入エンドポイント用レート制限（1時間に10回まで）
const purchaseRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1時間
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many purchase attempts, please try again later' },
});

// コインパッケージ定義 (レガシー: /packages エンドポイント用)
const COIN_PACKAGES = [
  { id: 'coins_10',  coins: 10,  price: 120,  label: '10コイン' },
  { id: 'coins_60',  coins: 60,  price: 610,  label: '60コイン (おすすめ)' },
  { id: 'coins_130', coins: 130, price: 1220, label: '130コイン (お得)' },
];

/**
 * StoreKit 2 の productId とコイン数の対応マップ
 * App Store Connect で設定した Product ID に合わせること
 */
const PRODUCT_COIN_MAP: Record<string, number> = {
  'jp.app.surechi.coins.50':  50,
  'jp.app.surechi.coins.150': 150,
  'jp.app.surechi.coins.500': 500,
};

// パッケージ一覧取得
router.get('/packages', (_req, res) => {
  res.json({ packages: COIN_PACKAGES });
});

// コイン残高取得
router.get('/balance', authMiddleware, async (req: AuthRequest, res: Response) => {
  const user = await User.findById(req.userId).select('coins');
  res.json({ coins: user?.coins ?? 0 });
});

/**
 * StoreKit 2 IAP 購入検証エンドポイント
 *
 * リクエストボディ:
 *   signedTransaction: string - Apple から受け取った JWS 形式のトランザクション
 *
 * 処理フロー:
 *   1. JWS を Apple の公開鍵で検証 (証明書チェーン検証含む)
 *   2. transactionId で重複チェック (べき等性保証、MongoDB に永続化)
 *   3. productId からコイン数をマッピング
 *   4. コイン付与 + ProcessedTransaction 記録
 */
router.post('/iap', purchaseRateLimiter, authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { signedTransaction } = req.body;

    if (!signedTransaction || typeof signedTransaction !== 'string') {
      return res.status(400).json({ error: 'signedTransaction is required' });
    }

    // 1. JWS を検証してペイロードを取得
    let txPayload;
    try {
      txPayload = await verifyAppleJWS(signedTransaction);
    } catch (err) {
      if (err instanceof AppleVerificationError) {
        logger.warn(`Apple JWS verification failed: ${err.message}`, {
          userId: req.userId,
        });
        return res.status(400).json({ error: `Verification failed: ${err.message}` });
      }
      throw err;
    }

    const { transactionId, productId } = txPayload;

    // 2. transactionId で重複チェック (べき等性、MongoDB に永続化)
    const existing = await ProcessedTransaction.findOne({ transactionId });
    if (existing) {
      const user = await User.findById(req.userId).select('coins');
      return res.json({
        coins: user?.coins ?? 0,
        alreadyProcessed: true,
        transactionId,
      });
    }

    // 3. productId からコイン数をマッピング
    const coins = PRODUCT_COIN_MAP[productId];
    if (coins === undefined) {
      logger.warn(`Unknown productId in verified transaction: ${productId}`, {
        userId: req.userId,
        transactionId,
      });
      return res.status(400).json({ error: `Unknown product: ${productId}` });
    }

    // 4. コイン付与 + ProcessedTransaction 記録
    const [user] = await Promise.all([
      User.findByIdAndUpdate(
        req.userId,
        { $inc: { coins } },
        { new: true }
      ).select('coins'),
      ProcessedTransaction.create({
        transactionId,
        userId: req.userId,
        productId,
        coins,
      }),
    ]);

    logger.info(`IAP processed: ${productId} (${coins} coins)`, {
      userId: req.userId,
      transactionId,
      productId,
      coins,
    });

    res.json({
      coins: user?.coins ?? 0,
      added: coins,
      transactionId,
    });
  } catch (error) {
    logger.error('IAP processing error', { error, userId: req.userId });
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * レガシー: コイン購入処理
 * StoreKit 2 移行完了後に削除予定
 * 本番環境では /iap エンドポイントを使用すること
 */
router.post('/purchase', purchaseRateLimiter, authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { packageId } = req.body;
    const pkg = COIN_PACKAGES.find(p => p.id === packageId);
    if (!pkg) return res.status(400).json({ error: 'Invalid package' });

    // 本番環境では StoreKit 2 の /iap エンドポイントを使用
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({
        error: 'Use /iap endpoint with StoreKit 2 verification in production',
      });
    }

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

// 購入履歴取得
router.get('/history', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const transactions = await ProcessedTransaction.find({ userId: req.userId })
      .sort({ processedAt: -1 })
      .limit(50)
      .select('transactionId productId coins processedAt');

    res.json({ transactions });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;

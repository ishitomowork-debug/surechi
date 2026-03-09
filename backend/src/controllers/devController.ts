import { Request, Response } from 'express';
import bcryptjs from 'bcryptjs';
import User from '../models/userModel';
import Interaction from '../models/interactionModel';

const SEED_USERS = [
  { name: 'あいか', email: 'seed_aika@dev.test', age: 24, bio: '旅行と美食が大好きです✈️', latOffset: 0.001, lonOffset: 0.001 },
  { name: 'はな',   email: 'seed_hana@dev.test',  age: 26, bio: 'カフェ巡りと読書が趣味です☕', latOffset: -0.001, lonOffset: 0.002 },
  { name: 'みか',   email: 'seed_mika@dev.test',  age: 22, bio: '映画と音楽が好きです🎬', latOffset: 0.002, lonOffset: -0.001 },
];

// デフォルト位置（東京）
const DEFAULT_LAT = 35.689487;
const DEFAULT_LON = 139.691711;

/**
 * テストユーザーを3人作成し、認証ユーザーをいいね済みにする（開発用）
 * POST /api/dev/seed
 */
export async function seedNearbyUsers(req: Request & { userId?: string }, res: Response) {
  try {
    const myUser = await User.findById(req.userId);
    if (!myUser) return res.status(404).json({ error: 'User not found. バックエンド再起動後はアプリからログアウトして再ログインしてください。' });

    // 座標が [0,0]（未設定）の場合は東京をデフォルトに使用
    const coords = myUser.location?.coordinates;
    const isDefault = !coords || (coords[0] === 0 && coords[1] === 0);
    const baseLat = isDefault ? DEFAULT_LAT : coords[1];
    const baseLon = isDefault ? DEFAULT_LON : coords[0];

    // パスワードは一度だけハッシュ化
    const hashedPassword = await bcryptjs.hash('seed_dev_pass', 10);

    const testUserIds: string[] = [];

    for (const u of SEED_USERS) {
      // ユーザーがなければ作成、あれば位置情報だけ更新
      const testUser = await User.findOneAndUpdate(
        { email: u.email },
        {
          $set: {
            location: { type: 'Point', coordinates: [baseLon + u.lonOffset, baseLat + u.latOffset] },
          },
          $setOnInsert: {
            name: u.name,
            password: hashedPassword,
            age: u.age,
            bio: u.bio,
          },
        },
        { upsert: true, new: true }
      );

      if (testUser) testUserIds.push(String(testUser._id));
    }

    // 既存のいいねを削除してから再作成（シンプルで確実）
    await Interaction.deleteMany({ fromUser: { $in: testUserIds }, toUser: req.userId });
    await Interaction.insertMany(
      testUserIds.map((id) => ({ fromUser: id, toUser: req.userId, type: 'like' }))
    );

    res.json({ message: `${testUserIds.length}人のテストユーザーを追加しました！Discovery を更新してください。` });
  } catch (err) {
    console.error('[DEV] seedNearbyUsers error:', err);
    res.status(500).json({ error: err instanceof Error ? err.message : 'Seed failed' });
  }
}

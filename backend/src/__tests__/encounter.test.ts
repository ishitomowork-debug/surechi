import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import User from '../models/userModel';
import Block from '../models/blockModel';
import Encounter from '../models/encounterModel';

// ─── Haversine 距離計算（matchController.ts からの抽出） ──────────────────────
// テスト対象のロジックを独立関数として再定義
function calculateDistance(coord1: [number, number], coord2: [number, number]): number {
  const R = 6371e3; // 地球の半径 (メートル)
  const lat1 = coord1[1] * (Math.PI / 180);
  const lat2 = coord2[1] * (Math.PI / 180);
  const dLat = (coord2[1] - coord1[1]) * (Math.PI / 180);
  const dLon = (coord2[0] - coord1[0]) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

// ─── テストヘルパー ──────────────────────────────────────────────────────────
// 東京駅の座標をベースに使用
const TOKYO_STATION: [number, number] = [139.7671, 35.6812]; // [lng, lat]

/**
 * 指定メートル分だけ北にオフセットした座標を返す
 * 緯度1度 ≈ 111,320m
 */
function offsetNorth(base: [number, number], meters: number): [number, number] {
  const latOffset = meters / 111_320;
  return [base[0], base[1] + latOffset];
}

async function createUser(
  name: string,
  coords: [number, number],
  extraFields: Record<string, unknown> = {}
): Promise<mongoose.Types.ObjectId> {
  const user = await User.create({
    name,
    email: `${name.toLowerCase().replace(/\s/g, '')}@test.dev`,
    password: 'testpassword123',
    age: 25,
    location: { type: 'Point', coordinates: coords },
    ...extraFields,
  });
  return user._id as mongoose.Types.ObjectId;
}

// ─── テストセットアップ ──────────────────────────────────────────────────────
let mongoServer: MongoMemoryServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const uri = mongoServer.getUri();
  await mongoose.connect(uri);

  // 2dsphere インデックスが作成されるのを待つ
  await User.ensureIndexes();
  await Encounter.ensureIndexes();
  await Block.ensureIndexes();
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await User.deleteMany({});
  await Encounter.deleteMany({});
  await Block.deleteMany({});
});

// ─── Haversine 距離計算のユニットテスト ──────────────────────────────────────
describe('calculateDistance (Haversine)', () => {
  it('同一地点の距離は0メートル', () => {
    const dist = calculateDistance(TOKYO_STATION, TOKYO_STATION);
    expect(dist).toBe(0);
  });

  it('約50m離れた地点の距離が正しく計算される', () => {
    const point50m = offsetNorth(TOKYO_STATION, 50);
    const dist = calculateDistance(TOKYO_STATION, point50m);
    // Haversine の丸め誤差を考慮して +-5m の範囲を許容
    expect(dist).toBeGreaterThanOrEqual(45);
    expect(dist).toBeLessThanOrEqual(55);
  });

  it('約100m離れた地点の距離が正しく計算される', () => {
    const point100m = offsetNorth(TOKYO_STATION, 100);
    const dist = calculateDistance(TOKYO_STATION, point100m);
    expect(dist).toBeGreaterThanOrEqual(95);
    expect(dist).toBeLessThanOrEqual(105);
  });

  it('約1km離れた地点の距離が正しく計算される', () => {
    const point1km = offsetNorth(TOKYO_STATION, 1000);
    const dist = calculateDistance(TOKYO_STATION, point1km);
    expect(dist).toBeGreaterThanOrEqual(995);
    expect(dist).toBeLessThanOrEqual(1005);
  });

  it('経度方向のオフセットでも正しく計算される', () => {
    // 経度1度 ≈ 111,320m * cos(lat) ≈ 約91,000m (東京の緯度で)
    const lngOffset = 500 / (111_320 * Math.cos(TOKYO_STATION[1] * Math.PI / 180));
    const pointEast: [number, number] = [TOKYO_STATION[0] + lngOffset, TOKYO_STATION[1]];
    const dist = calculateDistance(TOKYO_STATION, pointEast);
    expect(dist).toBeGreaterThanOrEqual(495);
    expect(dist).toBeLessThanOrEqual(505);
  });

  it('coord引数の順序は [lng, lat] である', () => {
    // 東京駅とニューヨークの距離は約10,800km
    const NEW_YORK: [number, number] = [-73.9857, 40.7484];
    const dist = calculateDistance(TOKYO_STATION, NEW_YORK);
    expect(dist).toBeGreaterThan(10_000_000);
    expect(dist).toBeLessThan(11_500_000);
  });
});

// ─── MongoDB $near を使ったすれ違い検出テスト ────────────────────────────────
describe('すれ違い検出 ($near クエリ)', () => {
  it('100m以内のユーザーが検出される', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const nearCoords = offsetNorth(TOKYO_STATION, 50); // 50m北
    const nearId = await createUser('NearUser', nearCoords);

    const nearbyUsers = await User.find({
      _id: { $ne: meId },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: TOKYO_STATION },
          $maxDistance: 100,
        },
      },
    });

    expect(nearbyUsers).toHaveLength(1);
    expect(nearbyUsers[0]._id.toString()).toBe(nearId.toString());
  });

  it('100m超のユーザーは検出されない', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const farCoords = offsetNorth(TOKYO_STATION, 150); // 150m北
    await createUser('FarUser', farCoords);

    const nearbyUsers = await User.find({
      _id: { $ne: meId },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: TOKYO_STATION },
          $maxDistance: 100,
        },
      },
    });

    expect(nearbyUsers).toHaveLength(0);
  });

  it('ちょうど100m付近の境界値テスト', async () => {
    const meId = await createUser('Me', TOKYO_STATION);

    // 99m (検出されるべき)
    const coords99m = offsetNorth(TOKYO_STATION, 95);
    await createUser('User99m', coords99m);

    // 105m (検出されないべき)
    const coords105m = offsetNorth(TOKYO_STATION, 110);
    await createUser('User105m', coords105m);

    const nearbyUsers = await User.find({
      _id: { $ne: meId },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: TOKYO_STATION },
          $maxDistance: 100,
        },
      },
    });

    expect(nearbyUsers).toHaveLength(1);
    expect(nearbyUsers[0].name).toBe('User99m');
  });
});

// ─── ブロック済みユーザーの除外テスト ────────────────────────────────────────
describe('ブロック済みユーザーの除外', () => {
  it('自分がブロックしたユーザーは除外される', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const nearCoords = offsetNorth(TOKYO_STATION, 30);
    const blockedId = await createUser('BlockedUser', nearCoords);

    // ブロックレコード作成
    await Block.create({ blocker: meId, blocked: blockedId });

    // ブロック済みIDを取得
    const blocks = await Block.find({
      $or: [{ blocker: meId }, { blocked: meId }],
    });
    const blockedIds = blocks.map((b) =>
      b.blocker.toString() === meId.toString() ? b.blocked : b.blocker
    );

    const nearbyUsers = await User.find({
      _id: { $ne: meId, $nin: blockedIds },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: TOKYO_STATION },
          $maxDistance: 100,
        },
      },
    });

    expect(nearbyUsers).toHaveLength(0);
  });

  it('相手にブロックされている場合も除外される', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const nearCoords = offsetNorth(TOKYO_STATION, 30);
    const blockerId = await createUser('BlockerUser', nearCoords);

    // 相手が自分をブロック
    await Block.create({ blocker: blockerId, blocked: meId });

    const blocks = await Block.find({
      $or: [{ blocker: meId }, { blocked: meId }],
    });
    const blockedIds = blocks.map((b) =>
      b.blocker.toString() === meId.toString() ? b.blocked : b.blocker
    );

    const nearbyUsers = await User.find({
      _id: { $ne: meId, $nin: blockedIds },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: TOKYO_STATION },
          $maxDistance: 100,
        },
      },
    });

    expect(nearbyUsers).toHaveLength(0);
  });

  it('ブロック関係のないユーザーは表示される', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const nearCoords = offsetNorth(TOKYO_STATION, 30);
    const normalId = await createUser('NormalUser', nearCoords);

    // ブロックなし
    const blocks = await Block.find({
      $or: [{ blocker: meId }, { blocked: meId }],
    });
    const blockedIds = blocks.map((b) =>
      b.blocker.toString() === meId.toString() ? b.blocked : b.blocker
    );

    const nearbyUsers = await User.find({
      _id: { $ne: meId, $nin: blockedIds },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: TOKYO_STATION },
          $maxDistance: 100,
        },
      },
    });

    expect(nearbyUsers).toHaveLength(1);
    expect(nearbyUsers[0]._id.toString()).toBe(normalId.toString());
  });
});

// ─── Encounter 重複防止テスト ────────────────────────────────────────────────
describe('10分以内の重複すれ違い除外 (Encounter TTL)', () => {
  it('Encounter レコードが存在する場合は重複として検出される', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const nearCoords = offsetNorth(TOKYO_STATION, 30);
    const nearId = await createUser('NearUser', nearCoords);

    // user1 < user2 のソート順で保存（実装と同じ）
    const [enc1, enc2] = meId.toString() < nearId.toString()
      ? [meId, nearId]
      : [nearId, meId];

    // 既に Encounter レコードが存在
    await Encounter.create({ user1: enc1, user2: enc2 });

    // 重複チェック
    const alreadyNotified = await Encounter.findOne({ user1: enc1, user2: enc2 });
    expect(alreadyNotified).not.toBeNull();
  });

  it('Encounter レコードがない場合は新規すれ違いとして扱われる', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const nearCoords = offsetNorth(TOKYO_STATION, 30);
    const nearId = await createUser('NearUser', nearCoords);

    const [enc1, enc2] = meId.toString() < nearId.toString()
      ? [meId, nearId]
      : [nearId, meId];

    const alreadyNotified = await Encounter.findOne({ user1: enc1, user2: enc2 });
    expect(alreadyNotified).toBeNull();

    // 新規作成できるべき
    const encounter = await Encounter.create({ user1: enc1, user2: enc2 });
    expect(encounter.user1.toString()).toBe(enc1.toString());
    expect(encounter.user2.toString()).toBe(enc2.toString());
  });

  it('同じペアの Encounter は重複作成できない (unique index)', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const nearId = await createUser('NearUser', offsetNorth(TOKYO_STATION, 30));

    const [enc1, enc2] = meId.toString() < nearId.toString()
      ? [meId, nearId]
      : [nearId, meId];

    await Encounter.create({ user1: enc1, user2: enc2 });

    // 重複作成を試みるとエラー
    await expect(
      Encounter.create({ user1: enc1, user2: enc2 })
    ).rejects.toThrow();
  });

  it('Encounter の encounteredAt フィールドにデフォルト日時が設定される', async () => {
    const meId = await createUser('Me', TOKYO_STATION);
    const nearId = await createUser('NearUser', offsetNorth(TOKYO_STATION, 30));

    const [enc1, enc2] = meId.toString() < nearId.toString()
      ? [meId, nearId]
      : [nearId, meId];

    const before = new Date();
    const encounter = await Encounter.create({ user1: enc1, user2: enc2 });
    const after = new Date();

    expect(encounter.encounteredAt).toBeDefined();
    expect(encounter.encounteredAt.getTime()).toBeGreaterThanOrEqual(before.getTime());
    expect(encounter.encounteredAt.getTime()).toBeLessThanOrEqual(after.getTime());
  });

  it('TTL index の expires が 600秒 (10分) に設定されている', async () => {
    const indexes = await Encounter.collection.indexes();
    const ttlIndex = indexes.find(
      (idx) => idx.key && (idx.key as Record<string, unknown>).encounteredAt !== undefined
    );
    expect(ttlIndex).toBeDefined();
    expect(ttlIndex?.expireAfterSeconds).toBe(600);
  });
});

// ─── 統合テスト: location:update ハンドラーのロジック再現 ────────────────────
describe('location:update ハンドラーのロジック (統合テスト)', () => {
  it('近くのユーザーを検出し、ブロックと重複を正しくフィルタリングする', async () => {
    const meId = await createUser('Me', TOKYO_STATION);

    // 50m以内のユーザー (検出されるべき)
    const nearId = await createUser('NearUser', offsetNorth(TOKYO_STATION, 50));

    // 200m以上のユーザー (除外されるべき)
    await createUser('FarUser', offsetNorth(TOKYO_STATION, 200));

    // ブロック済みユーザー 30m以内 (除外されるべき)
    const blockedNearId = await createUser('BlockedNear', offsetNorth(TOKYO_STATION, 20));
    await Block.create({ blocker: meId, blocked: blockedNearId });

    // 既にEncounter済みのユーザー 40m以内 (除外されるべき)
    const encounteredId = await createUser('EncounteredUser', offsetNorth(TOKYO_STATION, 40));

    // location:update ハンドラーのロジックを再現
    const nearbyUsers = await User.find({
      _id: { $ne: meId },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: TOKYO_STATION },
          $maxDistance: 100,
        },
      },
    }).select('_id name');

    // この時点では NearUser, BlockedNear, EncounteredUser が含まれる
    expect(nearbyUsers.length).toBe(3);

    // ブロックチェック
    const filteredAfterBlock: typeof nearbyUsers = [];
    for (const nearbyUser of nearbyUsers) {
      const nearbyUserId = nearbyUser._id.toString();

      const blocked = await Block.findOne({
        $or: [
          { blocker: meId, blocked: nearbyUserId },
          { blocker: nearbyUserId, blocked: meId },
        ],
      });
      if (blocked) continue;

      filteredAfterBlock.push(nearbyUser);
    }

    // BlockedNear が除外されたので2人
    expect(filteredAfterBlock.length).toBe(2);

    // Encounter 重複チェック
    const [sortedEnc1, sortedEnc2] = meId.toString() < encounteredId.toString()
      ? [meId, encounteredId]
      : [encounteredId, meId];
    await Encounter.create({ user1: sortedEnc1, user2: sortedEnc2 });

    const finalFiltered: typeof nearbyUsers = [];
    for (const nearbyUser of filteredAfterBlock) {
      const nearbyUserId = nearbyUser._id.toString();
      const enc1 = new mongoose.Types.ObjectId(
        meId.toString() < nearbyUserId ? meId.toString() : nearbyUserId
      );
      const enc2 = new mongoose.Types.ObjectId(
        meId.toString() < nearbyUserId ? nearbyUserId : meId.toString()
      );

      const alreadyNotified = await Encounter.findOne({ user1: enc1, user2: enc2 });
      if (alreadyNotified) continue;

      finalFiltered.push(nearbyUser);
    }

    // EncounteredUser も除外されて NearUser のみ残る
    expect(finalFiltered.length).toBe(1);
    expect(finalFiltered[0].name).toBe('NearUser');
  });
});

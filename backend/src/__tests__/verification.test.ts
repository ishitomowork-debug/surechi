import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import express, { Express } from 'express';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import User from '../models/userModel';

// JWT_SECRET を先にセット（認証ミドルウェアが読む）
process.env.JWT_SECRET = 'test-secret-for-verification';
process.env.NODE_ENV = 'test';

// ルート読み込みは JWT_SECRET セット後
// eslint-disable-next-line @typescript-eslint/no-var-requires
const verificationRoutes = require('../routes/verification').default;

let mongoServer: MongoMemoryServer;
let app: Express;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());

  app = express();
  app.use(express.json({ limit: '15mb' }));
  app.use('/api/verification', verificationRoutes);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await User.deleteMany({});
});

async function createTestUser(overrides: Record<string, unknown> = {}) {
  const user = await User.create({
    name: 'テストユーザー',
    email: `test${Date.now()}${Math.random()}@example.com`,
    password: 'password123',
    age: 25,
    ...overrides,
  });
  return user;
}

function tokenFor(userId: string): string {
  return jwt.sign({ userId }, process.env.JWT_SECRET!, { expiresIn: '1h' });
}

// 有効な base64 画像のモック (十分な長さの画像風データ)
const FAKE_IMAGE_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=' +
  'A'.repeat(200);
const FAKE_DATA_URL = `data:image/png;base64,${FAKE_IMAGE_BASE64}`;

describe('POST /api/verification/submit', () => {
  it('未提出ユーザーが画像を提出すると pending になる', async () => {
    const user = await createTestUser();
    const token = tokenFor(user._id.toString());

    const res = await request(app)
      .post('/api/verification/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ idImageBase64: FAKE_IMAGE_BASE64 });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('pending');

    const updated = await User.findById(user._id).select('+idImageBase64');
    expect(updated?.verificationStatus).toBe('pending');
    expect(updated?.idImageBase64).toBeTruthy();
    expect(updated?.verificationSubmittedAt).toBeDefined();
  });

  it('data URL 形式の base64 も受理する', async () => {
    const user = await createTestUser();
    const token = tokenFor(user._id.toString());

    const res = await request(app)
      .post('/api/verification/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ idImageBase64: FAKE_DATA_URL });

    expect(res.status).toBe(200);
  });

  it('無効な base64 は 400 を返す', async () => {
    const user = await createTestUser();
    const token = tokenFor(user._id.toString());

    const res = await request(app)
      .post('/api/verification/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ idImageBase64: '!!!invalid!!!' });

    expect(res.status).toBe(400);
  });

  it('空文字列は 400 を返す', async () => {
    const user = await createTestUser();
    const token = tokenFor(user._id.toString());

    const res = await request(app)
      .post('/api/verification/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ idImageBase64: '' });

    expect(res.status).toBe(400);
  });

  it('既に pending の場合は 400 を返す', async () => {
    const user = await createTestUser({ verificationStatus: 'pending' });
    const token = tokenFor(user._id.toString());

    const res = await request(app)
      .post('/api/verification/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ idImageBase64: FAKE_IMAGE_BASE64 });

    expect(res.status).toBe(400);
  });

  it('既に approved の場合は 400 を返す', async () => {
    const user = await createTestUser({ verificationStatus: 'approved' });
    const token = tokenFor(user._id.toString());

    const res = await request(app)
      .post('/api/verification/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ idImageBase64: FAKE_IMAGE_BASE64 });

    expect(res.status).toBe(400);
  });

  it('認証なしは 401 を返す', async () => {
    const res = await request(app)
      .post('/api/verification/submit')
      .send({ idImageBase64: FAKE_IMAGE_BASE64 });
    expect(res.status).toBe(401);
  });
});

describe('GET /api/verification/status', () => {
  it('現在のステータスを返す', async () => {
    const user = await createTestUser({ verificationStatus: 'rejected', verificationNote: '書類が不鮮明' });
    const token = tokenFor(user._id.toString());

    const res = await request(app)
      .get('/api/verification/status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('rejected');
    expect(res.body.verificationNote).toBe('書類が不鮮明');
  });
});

describe('管理者エンドポイント', () => {
  it('非管理者は /admin/pending にアクセスできない', async () => {
    const user = await createTestUser();
    const token = tokenFor(user._id.toString());

    const res = await request(app)
      .get('/api/verification/admin/pending')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });

  it('管理者は pending ユーザー一覧を取得できる', async () => {
    const admin = await createTestUser();
    process.env.DEV_USER_ID = admin._id.toString();
    const adminToken = tokenFor(admin._id.toString());

    const pendingUser = await createTestUser({
      verificationStatus: 'pending',
      idImageBase64: FAKE_IMAGE_BASE64,
      verificationSubmittedAt: new Date(),
    });

    const res = await request(app)
      .get('/api/verification/admin/pending')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.users).toHaveLength(1);
    expect(res.body.users[0].id.toString()).toBe(pendingUser._id.toString());
    expect(res.body.users[0].idImageBase64).toBeTruthy();

    delete process.env.DEV_USER_ID;
  });

  it('管理者は approve でステータスを approved に変更し、画像を削除する', async () => {
    const admin = await createTestUser();
    process.env.DEV_USER_ID = admin._id.toString();
    const adminToken = tokenFor(admin._id.toString());

    const target = await createTestUser({
      verificationStatus: 'pending',
      idImageBase64: FAKE_IMAGE_BASE64,
    });

    const res = await request(app)
      .post(`/api/verification/admin/${target._id}/approve`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('approved');

    const updated = await User.findById(target._id).select('+idImageBase64');
    expect(updated?.verificationStatus).toBe('approved');
    expect(updated?.verifiedAt).toBeDefined();
    expect(updated?.idImageBase64).toBeFalsy(); // 画像が削除されている

    delete process.env.DEV_USER_ID;
  });

  it('管理者は reject で理由付きで却下できる', async () => {
    const admin = await createTestUser();
    process.env.DEV_USER_ID = admin._id.toString();
    const adminToken = tokenFor(admin._id.toString());

    const target = await createTestUser({
      verificationStatus: 'pending',
      idImageBase64: FAKE_IMAGE_BASE64,
    });

    const res = await request(app)
      .post(`/api/verification/admin/${target._id}/reject`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ note: '書類が読み取れません' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('rejected');

    const updated = await User.findById(target._id).select('+idImageBase64');
    expect(updated?.verificationStatus).toBe('rejected');
    expect(updated?.verificationNote).toBe('書類が読み取れません');
    expect(updated?.idImageBase64).toBeFalsy();

    delete process.env.DEV_USER_ID;
  });

  it('reject に note がないと 400', async () => {
    const admin = await createTestUser();
    process.env.DEV_USER_ID = admin._id.toString();
    const adminToken = tokenFor(admin._id.toString());

    const target = await createTestUser({ verificationStatus: 'pending' });

    const res = await request(app)
      .post(`/api/verification/admin/${target._id}/reject`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});

    expect(res.status).toBe(400);
    delete process.env.DEV_USER_ID;
  });

  it('pending でないユーザーを approve しようとすると 400', async () => {
    const admin = await createTestUser();
    process.env.DEV_USER_ID = admin._id.toString();
    const adminToken = tokenFor(admin._id.toString());

    const target = await createTestUser({ verificationStatus: 'unsubmitted' });

    const res = await request(app)
      .post(`/api/verification/admin/${target._id}/approve`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(400);
    delete process.env.DEV_USER_ID;
  });
});

import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import logger from './utils/logger';
import { sanitizeRequest } from './middleware/sanitize';
import { Server as SocketIOServer } from 'socket.io';
import http from 'http';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import connectDatabase from './config/database';
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import matchRoutes from './routes/matches';
import messageRoutes from './routes/messages';
import devRoutes from './routes/dev';
import paymentRoutes from './routes/payments';
import { setIO, userSocketMap } from './socket';
import Message from './models/messageModel';
import Match from './models/matchModel';
import User from './models/userModel';
import Interaction from './models/interactionModel';
import Encounter from './models/encounterModel';
import { sendPushNotification } from './utils/apns';

dotenv.config();

const app: Express = express();
const server = http.createServer(app);
const io = new SocketIOServer(server, {
  cors: {
    origin: process.env.SOCKET_IO_CORS || '*',
    methods: ['GET', 'POST'],
  },
});

setIO(io);

const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true,
}));
app.use(express.json({ limit: '5mb' }));
app.use(sanitizeRequest);

// Rate limiting
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' },
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 10, // 認証エンドポイントは厳しく
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication attempts, please try again later' },
});

app.use('/api', generalLimiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/auth/forgot-password', authLimiter);

// Database connection
connectDatabase().catch((error) => {
  console.error('Failed to connect to database:', error);
  process.exit(1);
});

// Routes
app.get('/', (_req: Request, res: Response) => {
  res.json({ message: 'スレチ Backend API', version: '1.0.0', status: 'running' });
});

app.get('/health', (_req: Request, res: Response) => {
  const dbState = mongoose.connection.readyState;
  const dbStatus = dbState === 1 ? 'connected' : 'connecting';
  res.status(200).json({
    status: 'ok',
    db: dbStatus,
    uptime: Math.floor(process.uptime()),
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/matches', matchRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/dev', devRoutes);
app.use('/api/payments', paymentRoutes);

// ─── Socket.IO ──────────────────────────────────────────────────────────────

// JWT認証ミドルウェア（接続時に検証）
io.use((socket, next) => {
  const token =
    (socket.handshake.headers.authorization as string | undefined)?.split(' ')[1] ||
    (socket.handshake.auth as { token?: string }).token;

  if (!token) {
    return next(new Error('No token provided'));
  }

  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || 'secret'
    ) as { userId: string };
    socket.data.userId = decoded.userId;
    next();
  } catch {
    next(new Error('Invalid token'));
  }
});

io.on('connection', (socket) => {
  const userId: string = socket.data.userId;
  userSocketMap.set(userId, socket.id);
  console.log(`User connected: ${socket.id} (userId: ${userId})`);

  // ─── チャットメッセージ送信 ─────────────────────────────────────────────
  socket.on(
    'message:send',
    async (data: { matchId: string; content: string }) => {
      try {
        const { matchId, content } = data;
        if (!content?.trim()) return;

        // 送信者がマッチングメンバーか確認
        const userObjectId = new mongoose.Types.ObjectId(userId);
        const match = await Match.findOne({
          _id: matchId,
          $or: [{ user1: userObjectId }, { user2: userObjectId }],
        });

        if (!match) {
          socket.emit('error', { message: 'Access denied' });
          return;
        }

        // コイン残高チェック＆消費（1メッセージ = 1コイン = 10円）
        const sender = await User.findById(userId).select('coins');
        if (!sender || sender.coins <= 0) {
          socket.emit('coins:insufficient', { coins: sender?.coins ?? 0 });
          return;
        }
        await User.findByIdAndUpdate(userId, { $inc: { coins: -1 } });
        const newCoins = (sender.coins ?? 1) - 1;
        socket.emit('coins:updated', { coins: newCoins });

        // メッセージ保存
        const message = await Message.create({
          matchId,
          senderId: userId,
          content: content.trim(),
        });

        const messageData = {
          _id: message._id,
          matchId: message.matchId,
          senderId: message.senderId,
          content: message.content,
          read: message.read,
          createdAt: message.createdAt,
        };

        // 送信者に送信確認
        socket.emit('message:sent', messageData);

        // 相手ユーザーに転送
        const otherUserId =
          match.user1.toString() === userId
            ? match.user2.toString()
            : match.user1.toString();

        const otherSocketId = userSocketMap.get(otherUserId);
        if (otherSocketId) {
          io.to(otherSocketId).emit('message:receive', messageData);
        } else {
          // 相手がオフラインならプッシュ通知
          const otherUser = await User.findById(otherUserId).select('deviceToken name');
          if (otherUser?.deviceToken) {
            const sender = await User.findById(userId).select('name');
            await sendPushNotification(
              otherUser.deviceToken,
              sender?.name ?? 'メッセージが届きました',
              content.trim(),
              { matchId }
            );
          }
        }
      } catch (error) {
        console.error('Message send error:', error);
        socket.emit('error', { message: 'Failed to send message' });
      }
    }
  );

  // ─── 既読通知 ───────────────────────────────────────────────────────────
  socket.on('message:read', (data: { matchId: string }) => {
    // REST API の markAsRead が Socket emit するので、
    // クライアントから直接 emit された場合も相手に転送する
    const { matchId } = data;
    if (!matchId) return;
    // matchId から相手を特定するのはコストが高いため、
    // REST API 経由の emit を主とし、ここでは何もしない
    // (markAsRead API が emitToUser で送信済み)
  });

  // ─── すれ違い：位置情報更新 ────────────────────────────────────────────
  socket.on(
    'location:update',
    async (data: { latitude: number; longitude: number }) => {
      try {
        const { latitude, longitude } = data;
        if (latitude === undefined || longitude === undefined) return;

        // DBの位置情報を更新
        await User.findByIdAndUpdate(userId, {
          location: { type: 'Point', coordinates: [longitude, latitude] },
        });

        // 半径100m以内でオンラインのユーザーを検索
        const nearbyUsers = await User.find({
          _id: { $ne: new mongoose.Types.ObjectId(userId) },
          location: {
            $near: {
              $geometry: { type: 'Point', coordinates: [longitude, latitude] },
              $maxDistance: 100,
            },
          },
        }).select('_id name age bio avatar');

        for (const nearbyUser of nearbyUsers) {
          const nearbyId = nearbyUser._id.toString();

          // オンラインでないならスキップ
          if (!userSocketMap.has(nearbyId)) continue;

          // 既にブロックしているか確認
          const Block = (await import('./models/blockModel')).default;
          const blocked = await Block.findOne({
            $or: [
              { blocker: userId, blocked: nearbyId },
              { blocker: nearbyId, blocked: userId },
            ],
          });
          if (blocked) continue;

          // 既にマッチ済みかチェック
          const u1 = userId < nearbyId ? userId : nearbyId;
          const u2 = userId < nearbyId ? nearbyId : userId;
          const existingMatch = await Match.findOne({
            user1: new mongoose.Types.ObjectId(u1),
            user2: new mongoose.Types.ObjectId(u2),
          });
          if (existingMatch) continue;

          // 10分以内に通知済みかチェック（重複防止）
          const enc1 = new mongoose.Types.ObjectId(userId < nearbyId ? userId : nearbyId);
          const enc2 = new mongoose.Types.ObjectId(userId < nearbyId ? nearbyId : userId);
          const alreadyNotified = await Encounter.findOne({ user1: enc1, user2: enc2 });
          if (alreadyNotified) continue;

          // Encounter レコードを作成（10分TTL）
          await Encounter.create({ user1: enc1, user2: enc2 });

          // 自分のプロフィールを取得
          const me = await User.findById(userId).select('_id name age bio avatar');

          // 両者に通知
          const mySocketId = userSocketMap.get(userId);
          const theirSocketId = userSocketMap.get(nearbyId);

          const nearbyPayload = {
            user: {
              id: nearbyUser._id,
              name: nearbyUser.name,
              age: nearbyUser.age,
              bio: nearbyUser.bio,
              avatar: nearbyUser.avatar,
            },
          };
          const mePayload = {
            user: {
              id: me?._id,
              name: me?.name,
              age: me?.age,
              bio: me?.bio,
              avatar: me?.avatar,
            },
          };

          if (mySocketId) io.to(mySocketId).emit('encounter:nearby', nearbyPayload);
          if (theirSocketId) io.to(theirSocketId).emit('encounter:nearby', mePayload);

          console.log(`👥 Encounter: ${userId} <-> ${nearbyId}`);
        }
      } catch (error) {
        console.error('location:update error:', error);
      }
    }
  );

  // ─── すれ違い：スワイプ ─────────────────────────────────────────────────
  socket.on(
    'encounter:swipe',
    async (data: { targetUserId: string; liked: boolean }) => {
      try {
        const { targetUserId, liked } = data;
        if (!targetUserId) return;

        const actorId = new mongoose.Types.ObjectId(userId);
        const targetId = new mongoose.Types.ObjectId(targetUserId);

        if (!liked) return; // スキップは何もしない

        // いいね記録
        await Interaction.findOneAndUpdate(
          { from: actorId, to: targetId },
          { from: actorId, to: targetId, type: 'like' },
          { upsert: true }
        );

        // 相手もいいねしているか確認
        const mutual = await Interaction.findOne({ from: targetId, to: actorId, type: 'like' });
        if (!mutual) return;

        // マッチング成立
        const u1id = userId < targetUserId ? userId : targetUserId;
        const u2id = userId < targetUserId ? targetUserId : userId;
        const existingMatch = await Match.findOne({
          user1: new mongoose.Types.ObjectId(u1id),
          user2: new mongoose.Types.ObjectId(u2id),
        });
        if (existingMatch) return;

        const match = await Match.create({
          user1: new mongoose.Types.ObjectId(u1id),
          user2: new mongoose.Types.ObjectId(u2id),
        });

        const me = await User.findById(userId).select('_id name age bio avatar');
        const them = await User.findById(targetUserId).select('_id name age bio avatar');

        const matchPayload = (otherUser: typeof me) => ({
          matchId: match._id,
          user: {
            id: otherUser?._id,
            name: otherUser?.name,
            age: otherUser?.age,
            bio: otherUser?.bio,
            avatar: otherUser?.avatar,
          },
        });

        const mySocketId = userSocketMap.get(userId);
        const theirSocketId = userSocketMap.get(targetUserId);

        if (mySocketId) io.to(mySocketId).emit('encounter:matched', matchPayload(them));
        if (theirSocketId) io.to(theirSocketId).emit('encounter:matched', matchPayload(me));

        console.log(`💕 Encounter Match: ${userId} <-> ${targetUserId}`);
      } catch (error) {
        console.error('encounter:swipe error:', error);
      }
    }
  );

  // ─── 切断 ──────────────────────────────────────────────────────────────
  socket.on('disconnect', () => {
    userSocketMap.delete(userId);
    console.log(`User disconnected: ${socket.id} (userId: ${userId})`);
  });
});

server.listen(Number(PORT), '0.0.0.0', () => {
  logger.info(`Server is running on http://0.0.0.0:${PORT}`);
});

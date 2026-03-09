import { Server } from 'socket.io';

/**
 * Socket.IO インスタンスと接続中ユーザーの管理
 * userId -> socketId のマッピング（インメモリ、本番はRedis推奨）
 */
let io: Server;
export const userSocketMap = new Map<string, string>();

export function setIO(instance: Server) {
  io = instance;
}

export function getIO(): Server {
  return io;
}

/**
 * 指定ユーザーがオンラインかチェックしてイベントを送信
 */
export function emitToUser(userId: string, event: string, data: unknown) {
  const socketId = userSocketMap.get(userId);
  if (socketId) {
    io.to(socketId).emit(event, data);
    return true;
  }
  return false;
}

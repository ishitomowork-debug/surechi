# アーキテクチャ設計 - スレチ (Surechi)

## 📐 システムアーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                      iOS Client (SwiftUI)                       │
│  ┌─────────────┬──────────────┬──────────────┬──────────────┐   │
│  │Auth View    │Discovery View│ Matches View │ Chat View    │   │
│  └─────────────┴──────────────┴──────────────┴──────────────┘   │
│                              │                                   │
│         ┌────────────────────┼────────────────────┐              │
│         │                    │                    │              │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│   │LocationMgr   │    │WebSocket     │    │APIClient     │      │
│   │(Core Loc.)   │    │(Socket.IO)   │    │(URLSession)  │      │
│   └──────────────┘    └──────────────┘    └──────────────┘      │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         │ GPS Data           │ Real-time Events   │ HTTP Requests
         └────────────────────┼────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   Firewall/LB     │
                    └─────────┬─────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────────┐
│                    Backend API (Node.js / TypeScript)              │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                   Express Server                           │   │
│  │  ┌──────────┬──────────┬──────────┬──────────┬──────────┐ │   │
│  │  │Auth      │Users     │Matches   │Messages  │Payments  │ │   │
│  │  │Routes    │Routes    │Routes    │Routes    │Routes    │ │   │
│  │  └──────────┴──────────┴──────────┴──────────┴──────────┘ │   │
│  └────────────────────────────────────────────────────────────┘   │
│                              │                                     │
│  ┌────────────────────────────▼────────────────────────────┐      │
│  │          Socket.IO Server (Real-time, JWT認証)          │      │
│  │  • すれ違い検出 (100m以内)                              │      │
│  │  • マッチング通知                                       │      │
│  │  • チャット（コイン消費）                               │      │
│  │  • プッシュ通知 (APNs) - オフライン時フォールバック     │      │
│  └────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────┬──────────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │                                   │
            ┌───────▼────────┐                ┌────────▼─────┐
            │   MongoDB      │                │  APNs        │
            │   (Data Store) │                │  (Push通知)  │
            └────────────────┘                └───────────────┘
```

## 🔄 通信フロー

### 1. ユーザー登録フロー
```
iOS Client                Backend              Database
    │                       │                      │
    ├──POST /register──────>│                      │
    │                       ├──validate────────────┤
    │                       ├──hash password       │
    │                       ├──save user──────────>│
    │                       ├──send verify email   │
    │<──token + refreshToken│                      │
    │   (10コイン付与済)    │                      │
```

### 2. すれ違いフロー（コア機能）
```
User A (iOS)             Backend              User B (iOS)
    │                       │                      │
    │ (CoreLocation)         │                      │
    ├──emit location:update──>│                      │
    │  (Socket.IO)           ├──100m以内検索        │
    │                        ├──Encounter記録 (10分TTL)
    │<──encounter:nearby─────┤                      │
    │  (Userのプロフィール)   ├──encounter:nearby───>│
    │                        │  (こちらのプロフィール)
    │                        │                      │
    ├──encounter:swipe────────│ (liked: true)        │
    │                        ├──Interaction記録      │
    │                        ├──相互チェック        │
    │                        ├──Match作成            │
    │<──encounter:matched─────┤                      │
    │                        ├──encounter:matched───>│
```

### 3. マッチングフロー（スワイプ）
```
User A                  Backend            User B
  │                       │                  │
  ├──POST /like────────────>│                  │
  │  {targetUserId}        ├──dailyLike check │
  │                        ├──Interaction保存 │
  │                        ├──相互like確認    │
  │                        ├──Match作成        │
  │<──matched: true─────────┤                  │
  │                        ├──match:new emit──>│ (Socket)
  │                        ├──APNs push──────>│ (オフライン時)
```

### 4. チャットフロー（コイン消費）
```
User A                  Backend              User B
  │                       │                    │
  ├──message:send──────────>│                    │
  │  (Socket.IO)           ├──コイン残高確認    │
  │                        ├──coins -1          │
  │                        ├──Message保存       │
  │<──message:sent──────────┤ (送信確認)         │
  │<──coins:updated─────────┤ (新残高)           │
  │                        ├──message:receive──>│ (オンライン時)
  │                        ├──APNs push────────>│ (オフライン時)
```

## 📊 データモデル

### User
```typescript
interface IUser {
  _id: ObjectId;
  name: string;
  email: string;                    // unique, lowercase
  password: string;                 // bcrypt, select: false
  age: number;                      // min: 18
  bio?: string;                     // maxlength: 500
  interests?: string[];
  avatar?: string;                  // 画像URL
  deviceToken?: string;             // APNs トークン
  lastActiveAt?: Date;
  coins: number;                    // デフォルト: 10
  dailyLikeCount: number;           // 1日のいいね数
  dailyLikeResetAt?: Date;          // 翌日0時にリセット
  emailVerified: boolean;
  emailVerificationToken?: string;  // select: false, 有効期限: 24h
  passwordResetToken?: string;      // select: false, 有効期限: 1h
  location?: {
    type: 'Point';
    coordinates: [longitude, latitude];  // 2dsphere インデックス
  };
  createdAt: Date;
  updatedAt: Date;
}
```

### Match
```typescript
interface IMatch {
  _id: ObjectId;
  user1: ObjectId;       // userId の辞書順で小さい方
  user2: ObjectId;       // userId の辞書順で大きい方
  matchedAt: Date;
  expiresAt: Date;       // matchedAt + 7日
}
```

### Interaction
```typescript
interface IInteraction {
  _id: ObjectId;
  fromUser: ObjectId;
  toUser: ObjectId;
  type: 'like' | 'superlike' | 'dislike';
  createdAt: Date;
}
```

### Message
```typescript
interface IMessage {
  _id: ObjectId;
  matchId: ObjectId;
  senderId: ObjectId;
  content: string;
  read: boolean;
  createdAt: Date;
}
```

### Encounter（すれ違い記録）
```typescript
interface IEncounter {
  _id: ObjectId;
  user1: ObjectId;   // userId の辞書順で小さい方（unique ペア）
  user2: ObjectId;
  encounteredAt: Date;   // TTL: 600秒（10分）で自動削除
}
```

### RefreshToken
```typescript
interface IRefreshToken {
  _id: ObjectId;
  userId: ObjectId;
  token: string;     // crypto.randomBytes(40)
  expiresAt: Date;   // 30日
  createdAt: Date;
}
```

### Block / Report
```typescript
interface IBlock {
  blocker: ObjectId;
  blocked: ObjectId;
  createdAt: Date;
}

interface IReport {
  reporter: ObjectId;
  reported: ObjectId;
  reason?: string;
  createdAt: Date;
}
```

## 🔑 キー機能の実装

### Geospatial Indexing (2dsphere)
```javascript
// 半径5km以内のユーザーを検索（スワイプ用）
db.users.find({
  "location": {
    $near: {
      $geometry: { type: "Point", coordinates: [lng, lat] },
      $maxDistance: 5000
    }
  }
});

// 半径100m以内（すれ違い検出）
$maxDistance: 100
```

### コインシステム
- 新規登録: 10コイン付与
- メッセージ送信: 1コイン消費
- 課金: StoreKit 2 経由（`/api/payments/iap`）
- べき等性: `transactionID` による重複処理防止

### すれ違い通知の重複防止
- `Encounter` コレクションに同一ペアを記録
- MongoDB TTL インデックスで10分後に自動削除
- 10分以内の再通知をスキップ

### 1日いいね上限
- 上限: 20件/日
- 翌日0時（JST）にリセット
- `dailyLikeCount` / `dailyLikeResetAt` で管理

## 🔐 セキュリティ

1. **JWT認証**
   - アクセストークン有効期限: 7日
   - リフレッシュトークン有効期限: 30日
   - Socket.IO接続時にもJWT検証

2. **パスワードポリシー**
   - 8文字以上、大文字・小文字・数字を含む
   - bcrypt (salt rounds: 10)

3. **リクエストサニタイズ**
   - `sanitize` ミドルウェアで全リクエストのXSS対策

4. **レート制限**
   - 一般API: 15分100件
   - 認証エンドポイント: 15分10件

5. **ユーザー列挙攻撃対策**
   - `forgot-password` は存在しないメールでも同じレスポンス

6. **Helmet**
   - HTTPセキュリティヘッダーを自動設定

## ⚡ パフォーマンス

- **MongoDB インデックス**
  - `location`: 2dsphere（地理検索）
  - `email`: unique インデックス
  - `Encounter.{user1,user2}`: unique 複合インデックス
  - `Encounter.encounteredAt`: TTL インデックス（10分）

- **Socket.IO**
  - `userSocketMap` (Map) でオンラインユーザーのsocket IDをメモリキャッシュ
  - オフライン時はAPNsプッシュ通知にフォールバック

## 📁 バックエンドディレクトリ構造

```
backend/src/
├── index.ts                    # エントリーポイント、Socket.IOハンドラ
├── socket.ts                   # userSocketMap, emitToUser
├── dev-server.ts               # 開発用サーバー
├── config/
│   └── database.ts             # MongoDB接続設定
├── models/
│   ├── userModel.ts
│   ├── matchModel.ts
│   ├── messageModel.ts
│   ├── interactionModel.ts     # like/superlike/dislike
│   ├── encounterModel.ts       # すれ違い記録（TTL: 10分）
│   ├── refreshTokenModel.ts
│   ├── blockModel.ts
│   └── reportModel.ts
├── routes/
│   ├── auth.ts
│   ├── users.ts
│   ├── matches.ts
│   ├── messages.ts
│   ├── payments.ts             # コイン課金
│   └── dev.ts                  # 開発用エンドポイント
├── controllers/
│   ├── authController.ts
│   ├── userController.ts
│   ├── matchController.ts
│   ├── messageController.ts
│   └── devController.ts
├── middleware/
│   ├── auth.ts                 # JWT検証
│   ├── sanitize.ts             # XSS対策
│   ├── updateLastActive.ts     # lastActiveAt更新
│   └── errorHandler.ts
└── utils/
    ├── logger.ts               # Winston/Pinoロガー
    ├── mailer.ts               # メール送信（確認・リセット）
    └── apns.ts                 # Apple Push Notifications
```

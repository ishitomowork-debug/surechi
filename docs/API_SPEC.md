# API仕様書 - スレチ (Surechi) バックエンド

## Base URL
```
開発: http://localhost:3000
本番: https://api.surechi.jp
```

## 認証
すべての保護されたエンドポイントは Bearer トークン認証が必要です。

```
Authorization: Bearer <ACCESS_TOKEN>
```

---

## レート制限

| 対象 | 上限 | ウィンドウ |
|------|------|------------|
| 全 API | 100 リクエスト | 15分 |
| 認証エンドポイント (`/register`, `/login`, `/forgot-password`) | 10 リクエスト | 15分 |

---

## 🔐 認証エンドポイント (`/api/auth`)

### ユーザー登録
```http
POST /api/auth/register
Content-Type: application/json

{
  "name": "山田太郎",
  "email": "user@example.com",
  "password": "SecurePass1",
  "age": 25,
  "bio": "趣味は旅行です"  // 任意
}
```
パスワード要件: 8文字以上、大文字・小文字・数字を含む

レスポンス: `201`
```json
{
  "message": "User registered successfully. Please verify your email.",
  "token": "eyJhbGc...",
  "refreshToken": "abc123...",
  "user": {
    "id": "user_id",
    "name": "山田太郎",
    "email": "user@example.com",
    "age": 25,
    "emailVerified": false
  }
}
```
> 新規登録で10コインが付与されます。登録後、確認メールが送信されます。

---

### ログイン
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass1"
}
```

レスポンス: `200`
```json
{
  "message": "Login successful",
  "token": "eyJhbGc...",
  "refreshToken": "abc123...",
  "user": {
    "id": "user_id",
    "name": "山田太郎",
    "email": "user@example.com",
    "age": 25,
    "emailVerified": true
  }
}
```

---

### アクセストークンのリフレッシュ
```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refreshToken": "abc123..."
}
```

レスポンス: `200`
```json
{
  "token": "eyJhbGc..."
}
```
> リフレッシュトークンの有効期限は30日です。

---

### ログアウト
```http
POST /api/auth/logout
Content-Type: application/json

{
  "refreshToken": "abc123..."
}
```

レスポンス: `200`
```json
{
  "message": "Logged out successfully"
}
```

---

### 自分のプロフィール取得
```http
GET /api/auth/me
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "user": {
    "id": "user_id",
    "name": "山田太郎",
    "email": "user@example.com",
    "age": 25,
    "bio": "趣味は旅行です",
    "avatar": "https://...",
    "emailVerified": true
  }
}
```

---

### メールアドレス確認
```http
GET /api/auth/verify-email?token=<VERIFICATION_TOKEN>
```

レスポンス: `200`
```json
{
  "message": "Email verified successfully"
}
```

---

### パスワードリセットメール送信
```http
POST /api/auth/forgot-password
Content-Type: application/json

{
  "email": "user@example.com"
}
```

レスポンス: `200`（ユーザーが存在しない場合も同じレスポンス）
```json
{
  "message": "If that email exists, a reset link has been sent"
}
```

---

### パスワードリセット
```http
POST /api/auth/reset-password
Content-Type: application/json

{
  "token": "<RESET_TOKEN>",
  "password": "NewSecurePass1"
}
```

レスポンス: `200`
```json
{
  "message": "Password reset successfully"
}
```
> リセットトークンの有効期限は1時間です。

---

### アカウント削除
```http
DELETE /api/auth/account
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "message": "Account deleted successfully"
}
```
> 関連する全データ（マッチ、インタラクション、ブロック、メッセージ）が削除されます。Apple審査要件対応。

---

## 👤 ユーザーエンドポイント (`/api/users`)

### プロフィール取得
```http
GET /api/users/profile
Authorization: Bearer <TOKEN>
```

### プロフィール更新
```http
PUT /api/users/profile
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "name": "新しい名前",
  "age": 26,
  "bio": "新しい自己紹介",
  "interests": ["旅行", "カフェ", "音楽"]
}
```

### 位置情報更新
```http
PUT /api/users/location
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "latitude": 35.6762,
  "longitude": 139.6503
}
```

### ユーザーブロック
```http
POST /api/users/block/:userId
Authorization: Bearer <TOKEN>
```

### ユーザー通報
```http
POST /api/users/report/:userId
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "reason": "通報理由"
}
```

### APNsデバイストークン更新
```http
PUT /api/users/device-token
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "deviceToken": "apns_device_token"
}
```

---

## ❤️ マッチングエンドポイント (`/api/matches`)

### 近くのユーザー取得（スワイプ用）
```http
GET /api/matches/nearby?limit=10&radius=5000&minAge=18&maxAge=120
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "users": [
    {
      "_id": "user_id_2",
      "name": "佐藤花子",
      "age": 23,
      "bio": "カフェ巡りが好き",
      "interests": ["カフェ", "読書"],
      "avatar": "https://...",
      "distance": 245,
      "lastActiveAt": "2026-03-15T10:00:00Z",
      "superlikedMe": false
    }
  ],
  "likesRemaining": 15
}
```
> `superlikedMe: true` の場合、相手が自分をスーパーいいねしています。
> 1日のいいね上限は20件です。

### 近くのユーザー取得（マップ表示用）
```http
GET /api/matches/nearby-map
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "users": [
    {
      "id": "user_id_2",
      "name": "佐藤花子",
      "age": 23,
      "bio": "カフェ巡りが好き",
      "avatar": "https://...",
      "latitude": 35.6763,
      "longitude": 139.6505
    }
  ],
  "center": { "latitude": 35.6762, "longitude": 139.6503 }
}
```
> 半径1km固定。プライバシー保護のため座標にファジーオフセット（約±200m）が付加されます。

### いいね
```http
POST /api/matches/like
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "targetUserId": "user_id_2"
}
```

レスポンス: `200`（マッチなし）
```json
{
  "message": "Like sent",
  "matched": false
}
```

レスポンス: `200`（マッチ成立）
```json
{
  "message": "It's a match!",
  "matched": true,
  "match": {
    "_id": "match_id",
    "matchedAt": "2026-03-15T10:30:00Z"
  }
}
```
> 1日20件の上限あり。上限超過時は `429` + `{ "limitReached": true }`

### スーパーいいね
```http
POST /api/matches/superlike
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "targetUserId": "user_id_2"
}
```
> 相手にリアルタイム通知（`superlike:received`）とプッシュ通知が届きます。

### スキップ（dislike）
```http
POST /api/matches/dislike
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "targetUserId": "user_id_2"
}
```

### スキップ取り消し
```http
POST /api/matches/undo
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "user": { "_id": "...", "name": "...", "age": 23, ... }
}
```
> 直前のスキップを1件取り消します。

### 自分にいいねしたユーザー一覧
```http
GET /api/matches/liked-me
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "users": [
    {
      "_id": "user_id_3",
      "name": "田中次郎",
      "age": 27,
      "isSuperLike": true,
      "likedAt": "2026-03-15T09:00:00Z"
    }
  ]
}
```

### マッチング一覧
```http
GET /api/matches/matched?page=1&limit=20
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "matches": [
    {
      "_id": "match_id",
      "matchedUser": {
        "_id": "user_id_2",
        "name": "佐藤花子",
        "age": 23,
        "bio": "カフェ巡りが好き",
        "interests": ["カフェ"],
        "avatar": "https://..."
      },
      "matchedAt": "2026-03-15T10:30:00Z",
      "expiresAt": "2026-03-22T10:30:00Z",
      "unreadCount": 2,
      "lastMessage": {
        "content": "こんにちは！",
        "senderId": "user_id_2",
        "createdAt": "2026-03-15T11:00:00Z"
      }
    }
  ],
  "total": 5,
  "page": 1,
  "pages": 1,
  "hasMore": false
}
```
> マッチの有効期限は7日間です。期限切れのマッチは返却されません。

---

## 💬 メッセージエンドポイント (`/api/messages`)

### メッセージ一覧取得
```http
GET /api/messages/:matchId?limit=50&offset=0
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "messages": [
    {
      "_id": "msg_id",
      "matchId": "match_id",
      "senderId": "user_id",
      "content": "こんにちは！",
      "read": true,
      "createdAt": "2026-03-15T10:30:00Z"
    }
  ]
}
```

### 既読にする
```http
PUT /api/messages/:matchId/read
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "updated": 3
}
```
> 既読処理後、相手に `message:read` イベントがSocket.IO経由で通知されます。

---

## 💰 コイン・課金エンドポイント (`/api/payments`)

> コインは1メッセージ送信ごとに1枚消費されます（1コイン = 10円相当）。
> 新規登録時に10コインが付与されます。

### コインパッケージ一覧
```http
GET /api/payments/packages
```

レスポンス: `200`
```json
{
  "packages": [
    { "id": "coins_10",  "coins": 10,  "price": 120,  "label": "10コイン" },
    { "id": "coins_60",  "coins": 60,  "price": 610,  "label": "60コイン (おすすめ)" },
    { "id": "coins_130", "coins": 130, "price": 1220, "label": "130コイン (お得)" }
  ]
}
```

### コイン残高取得
```http
GET /api/payments/balance
Authorization: Bearer <TOKEN>
```

レスポンス: `200`
```json
{
  "coins": 42
}
```

### コイン購入（レガシー）
```http
POST /api/payments/purchase
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "packageId": "coins_60",
  "receiptData": "..."
}
```

### StoreKit 2 IAP購入報告
```http
POST /api/payments/iap
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "productID": "jp.app.surechi.coins.50",
  "transactionID": "unique_transaction_id",
  "coins": 50
}
```

有効なproductID:
- `jp.app.surechi.coins.50`
- `jp.app.surechi.coins.150`
- `jp.app.surechi.coins.500`

レスポンス: `200`
```json
{
  "coins": 92,
  "added": 50
}
```
> 同一 `transactionID` はべき等処理（2回目以降は `alreadyProcessed: true`）。

---

## 🔔 Socket.IO イベント

### 接続認証

Socket.IO の接続時に JWT トークンが必要です。

```javascript
const socket = io('http://localhost:3000', {
  auth: { token: 'eyJhbGc...' }
  // または
  // extraHeaders: { Authorization: 'Bearer eyJhbGc...' }
});
```

---

### クライアント → サーバー

#### 位置情報更新（すれ違い検出）
```javascript
socket.emit('location:update', {
  latitude: 35.6762,
  longitude: 139.6503
});
```
> 100m以内のオンラインユーザーを検索し、`encounter:nearby` を両者に通知します。

#### すれ違いスワイプ
```javascript
socket.emit('encounter:swipe', {
  targetUserId: "user_id_2",
  liked: true   // false の場合は何もしない
});
```
> 相互いいねが成立するとマッチング成立（`encounter:matched` を送信）。

#### メッセージ送信
```javascript
socket.emit('message:send', {
  matchId: "match_id",
  content: "こんにちは！"
});
```
> 1コイン消費。コイン不足時は `coins:insufficient` が返ります。

---

### サーバー → クライアント

#### すれ違い検出
```javascript
socket.on('encounter:nearby', (data) => {
  // {
  //   user: {
  //     id: "user_id_2",
  //     name: "佐藤花子",
  //     age: 23,
  //     bio: "...",
  //     avatar: "..."
  //   }
  // }
});
```
> 同じペアへの通知は10分間は重複しません（EncounterモデルのTTL制御）。

#### すれ違いマッチング成立
```javascript
socket.on('encounter:matched', (data) => {
  // {
  //   matchId: "match_id",
  //   user: { id, name, age, bio, avatar }
  // }
});
```

#### 新規マッチング通知（いいね経由）
```javascript
socket.on('match:new', (data) => {
  // {
  //   matchId: "match_id",
  //   matchedUser: { _id, name, age, bio, avatar },
  //   timestamp: Date
  // }
});
```

#### スーパーいいね受信
```javascript
socket.on('superlike:received', (data) => {
  // { fromUserId: "user_id_2" }
});
```

#### メッセージ受信
```javascript
socket.on('message:receive', (data) => {
  // {
  //   _id: "msg_id",
  //   matchId: "match_id",
  //   senderId: "user_id_2",
  //   content: "こんにちは！",
  //   read: false,
  //   createdAt: Date
  // }
});
```

#### メッセージ送信確認
```javascript
socket.on('message:sent', (data) => {
  // 送信者自身に届く確認イベント（message:receive と同じ構造）
});
```

#### 既読通知
```javascript
socket.on('message:read', (data) => {
  // { matchId: "match_id" }
});
```

#### コイン残高更新
```javascript
socket.on('coins:updated', (data) => {
  // { coins: 9 }
});
```

#### コイン不足
```javascript
socket.on('coins:insufficient', (data) => {
  // { coins: 0 }
});
```

---

## ⚠️ エラーレスポンス

```json
// 400 Bad Request
{ "error": "Missing required fields: name, email, password, age" }

// 401 Unauthorized
{ "error": "Invalid or expired refresh token" }

// 403 Forbidden
{ "error": "Access denied" }

// 404 Not Found
{ "error": "User not found" }

// 409 Conflict
{ "error": "Email already in use" }

// 429 Too Many Requests
{ "error": "1日20件のいいね上限に達しました", "limitReached": true }
// または
{ "error": "Too many requests, please try again later" }

// 500 Internal Server Error
{ "error": "Internal server error" }
```

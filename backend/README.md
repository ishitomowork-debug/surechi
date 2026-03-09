# RealMatching Backend

位置情報ベースの出会いアプリ「RealMatching」のバックエンドAPI

## 🛠️ 技術スタック
- Node.js + Express
- TypeScript
- MongoDB
- Socket.IO (リアルタイム通信)
- JWT認証

## 🚀 セットアップ

### 1. 依存関係のインストール
```bash
cd backend
npm install
```

### 2. 環境変数の設定
```bash
cp .env.example .env
# .env ファイルを編集して必要な値を設定
```

### 3. 開発サーバーの起動
```bash
npm run dev
```

## 📡 API エンドポイント

### 認証系
- `POST /api/auth/register` - ユーザー登録
- `POST /api/auth/login` - ログイン
- `POST /api/auth/logout` - ログアウト

### ユーザー系
- `GET /api/users/profile` - プロフィール取得
- `PUT /api/users/profile` - プロフィール更新
- `PUT /api/users/location` - 位置情報更新

### マッチング系
- `GET /api/matches/nearby` - 近くのユーザー取得
- `POST /api/matches/like` - いいね送信
- `POST /api/matches/dislike` - スキップ
- `GET /api/matches/matched` - マッチング済みユーザー

### チャット系
- `GET /api/messages/:matchId` - メッセージ取得
- `POST /api/messages` - メッセージ送信

## 🔌 Socket.IO イベント

### クライアント → サーバー
- `location:update` - 位置情報更新
- `like:send` - いいね送信
- `message:send` - メッセージ送信

### サーバー → クライアント
- `location:nearby` - 近くのユーザー情報
- `match:new` - 新しいマッチング通知
- `message:receive` - メッセージ受信

## 📦 プロジェクト構造
```
src/
├── index.ts           # エントリーポイント
├── routes/            # APIルート
├── controllers/       # ビジネスロジック
├── models/            # データモデル
├── middleware/        # ミドルウェア
└── utils/             # ユーティリティ
```

## 🔐 認証
JWT (JSON Web Token) を使用した認証を実装

## 📍 位置情報処理
- Geohashを使用した効率的な近距離検索
- リアルタイム位置更新

## ⚡ 次のステップ
- [ ] MongoDB接続の実装
- [ ] ユーザー認証ロジック
- [ ] マッチングアルゴリズム
- [ ] チャット機能
- [ ] 通知機能

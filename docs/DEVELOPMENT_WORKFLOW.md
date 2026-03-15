# 開発ワークフロー - スレチ (Surechi)

## 🔄 日々の開発フロー

```bash
# ターミナル 1: MongoDB (Docker使用時)
docker start surechi-mongo

# ターミナル 2: バックエンド開発サーバー
cd backend
npm run dev

# Xcode: iOS アプリ
open ios/Surechi/Surechi.xcodeproj
```

---

## 📝 バックエンド開発ガイド

### プロジェクト構造

```
backend/src/
├── index.ts                    # エントリーポイント + Socket.IOハンドラ
├── socket.ts                   # userSocketMap, emitToUser ユーティリティ
├── dev-server.ts               # 開発用軽量サーバー
├── config/
│   └── database.ts
├── models/
│   ├── userModel.ts            # coins, dailyLikeCount, emailVerified 等
│   ├── matchModel.ts           # expiresAt (7日TTL)
│   ├── messageModel.ts
│   ├── interactionModel.ts     # like / superlike / dislike
│   ├── encounterModel.ts       # すれ違い記録 (MongoDB TTL 10分)
│   ├── refreshTokenModel.ts    # リフレッシュトークン (30日)
│   ├── blockModel.ts
│   └── reportModel.ts
├── routes/
│   ├── auth.ts                 # register, login, refresh, verify-email, ...
│   ├── users.ts                # profile, location, block, report, device-token
│   ├── matches.ts              # nearby, nearby-map, like, superlike, undo, ...
│   ├── messages.ts
│   ├── payments.ts             # packages, balance, purchase, iap
│   └── dev.ts
├── controllers/
│   ├── authController.ts
│   ├── userController.ts
│   ├── matchController.ts      # 1日いいね上限 (20件)、ファジー座標
│   ├── messageController.ts
│   └── devController.ts
├── middleware/
│   ├── auth.ts                 # JWT検証 + generateToken
│   ├── sanitize.ts             # XSSサニタイズ
│   ├── updateLastActive.ts     # lastActiveAt 自動更新
│   └── errorHandler.ts
└── utils/
    ├── logger.ts
    ├── mailer.ts               # 確認メール / パスワードリセットメール
    └── apns.ts                 # APNs プッシュ通知
```

### 新しいAPIエンドポイントを追加する手順

1. **モデル定義** (`backend/src/models/`)
2. **コントローラ実装** (`backend/src/controllers/`)
3. **ルート定義** (`backend/src/routes/`)
4. **index.ts に登録**: `app.use('/api/xxx', xxxRoutes)`
5. **テスト** (curl / Postman)
6. **API仕様書更新** (`docs/API_SPEC.md`)

### コマンド

```bash
npm run dev       # ts-node-dev で開発サーバー起動
npm run build     # TypeScript コンパイル
npm run start     # ビルド済みサーバー起動
```

---

## 💰 コインシステム開発時の注意

- メッセージ送信はSocket.IO経由のみ（REST APIなし）
- 1メッセージ = 1コイン消費
- コイン不足時は `coins:insufficient` イベントを emit してメッセージは送信しない
- IAP購入は `transactionID` でべき等処理（`processedTransactions` Set）
  - ※現在はメモリ上のSetのためサーバー再起動でリセットされる。本番前にDB管理に移行推奨

---

## 🌍 すれ違い機能開発時の注意

- `location:update` Socket.IOイベントで位置情報を受信
- 100m以内のオンラインユーザーのみ対象（`userSocketMap` に存在するユーザー）
- ブロックユーザーは除外
- マッチ済みペアは除外
- `Encounter` コレクション（TTL 10分）で重複通知を防止
- 通知後は `encounter:swipe` でいいね/スキップを受け付ける
- 相互いいねで `Match` 作成 → `encounter:matched` を両者に emit

---

## 📱 iOS 開発ガイド

### プロジェクト構成

```
ios/Surechi/
├── Surechi.xcodeproj
├── Surechi/
│   ├── Views/
│   │   ├── Auth/           # ログイン・登録
│   │   ├── Discovery/      # スワイプUI
│   │   ├── Matches/        # マッチング一覧
│   │   ├── Chat/           # チャット
│   │   └── Profile/        # プロフィール
│   ├── ViewModels/
│   ├── Models/
│   ├── Services/
│   │   ├── APIClient       # HTTP通信
│   │   ├── SocketService   # Socket.IO
│   │   └── LocationManager # CoreLocation
│   └── Utils/
```

### iOS 開発チェックリスト

#### 認証
- [ ] ログイン / 登録フォーム
- [ ] アクセストークン + リフレッシュトークンの管理（Keychain保存）
- [ ] トークン期限切れ時の自動リフレッシュ（`/api/auth/refresh`）
- [ ] メール確認フロー
- [ ] アカウント削除（Apple審査要件）

#### すれ違い
- [ ] CoreLocation でバックグラウンド位置情報取得
- [ ] `location:update` イベント送信（30秒間隔推奨）
- [ ] `encounter:nearby` 受信 → カード表示UI
- [ ] `encounter:swipe` でいいね/スキップ送信
- [ ] `encounter:matched` 受信 → マッチング演出

#### スワイプ・マッチング
- [ ] `/api/matches/nearby` でユーザー取得
- [ ] スワイプUI（カードデッキ）
- [ ] `/api/matches/like`, `/api/matches/superlike`, `/api/matches/dislike`
- [ ] `/api/matches/undo` でスキップ取り消し
- [ ] `match:new` Socket.IOイベント受信

#### チャット
- [ ] Socket.IO JWT認証接続
- [ ] `message:send` でメッセージ送信
- [ ] `coins:insufficient` 時の課金導線
- [ ] `message:receive` / `message:sent` 受信
- [ ] `message:read` 既読表示

#### コイン・課金
- [ ] コイン残高表示
- [ ] StoreKit 2 IAP実装
- [ ] `/api/payments/iap` でバックエンドに購入報告

#### APNs
- [ ] デバイストークン取得
- [ ] `/api/users/device-token` に送信
- [ ] プッシュ通知ハンドリング

---

## ⚙️ 環境変数一覧

| 変数名 | 説明 | デフォルト |
|--------|------|-----------|
| `PORT` | サーバーポート | `3000` |
| `NODE_ENV` | 環境 (`development` / `production`) | `development` |
| `MONGODB_URI` | MongoDB接続URI | `mongodb://localhost:27017/surechi` |
| `JWT_SECRET` | JWT署名シークレット | **本番では必ず変更** |
| `JWT_EXPIRE` | アクセストークン有効期限 | `7d` |
| `SOCKET_IO_CORS` | Socket.IO CORSオリジン | `*` |
| `FRONTEND_URL` | Express CORS許可オリジン | `http://localhost:3000` |
| `SMTP_HOST` | メールサーバーホスト | - |
| `SMTP_PORT` | メールサーバーポート | - |
| `SMTP_USER` | SMTPユーザー | - |
| `SMTP_PASS` | SMTPパスワード | - |
| `EMAIL_FROM` | 送信元メールアドレス | - |
| `APNS_KEY_ID` | APNs認証キーID | - |
| `APNS_TEAM_ID` | Apple Team ID | - |
| `APNS_BUNDLE_ID` | アプリBundle ID | `jp.app.surechi` |
| `APNS_KEY_PATH` | APNs p8キーファイルパス | - |

---

## 🧪 テストコマンド

```bash
# ユーザー登録
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"テスト","email":"test@example.com","password":"Test123!","age":25}'

# ログイン → TOKEN取得
TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}' | jq -r .token)

# 近くのユーザー取得
curl "http://localhost:3000/api/matches/nearby?limit=5" \
  -H "Authorization: Bearer $TOKEN"

# コイン残高確認
curl http://localhost:3000/api/payments/balance \
  -H "Authorization: Bearer $TOKEN"

# トークンリフレッシュ
curl -X POST http://localhost:3000/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"YOUR_REFRESH_TOKEN"}'
```

---

## 📦 ビルド & デプロイ

### バックエンド

```bash
npm run build   # dist/ へコンパイル
npm run start   # 本番起動
```

本番環境での設定変更:
- `NODE_ENV=production`
- `JWT_SECRET` を強力なランダム値に変更
- `SOCKET_IO_CORS` を本番ドメインに制限
- `FRONTEND_URL` を本番ドメインに変更
- MongoDB Atlas などクラウドDBに接続
- HTTPS/WSS対応
- `IAP processedTransactions` をDB管理に移行

### iOS

1. `Product → Archive`
2. Organizer で署名・配布設定
3. TestFlight でテスト配信
4. App Store Connect でレビュー申請

---

## 📊 ロギング

```typescript
import logger from './utils/logger';

logger.info('User login', { userId });
logger.error('Database error', { error });
logger.warn('Rate limit reached', { ip });
```

---

## 💡 ベストプラクティス

### API設計
- RESTful エンドポイント + 適切なHTTPステータスコード
- エラーレスポンスは `{ error: string }` に統一
- 認証不要なエラーも `{ error: ... }` に統一（`success` フラグは使わない）

### セキュリティ
- パスワードは bcrypt (salt 10)
- JWT + RefreshToken の2トークン方式
- Socket.IO接続時もJWT必須
- ユーザー列挙攻撃対策（forgot-password は常に同じレスポンス）

### iOS
- MVVM アーキテクチャ
- アクセストークン + リフレッシュトークンはKeychainに保存
- `@Published` で状態管理
- Socket.IO切断時の再接続処理

---

**Happy developing! 🎉**

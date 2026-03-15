# Getting Started - スレチ (Surechi) 開発環境構築

## 🎯 プロジェクト立ち上げの手順

### Step 1: 開発環境の確認

```bash
node --version   # v18以上推奨
npm --version
xcode-select --install
```

### Step 2: バックエンド開発環境の構築

#### 2-1. MongoDB セットアップ

**Docker を使用（推奨）**
```bash
docker run -d \
  --name surechi-mongo \
  -p 27017:27017 \
  mongo:latest

docker ps | grep surechi-mongo
```

**ローカルインストール (macOS)**
```bash
brew tap mongodb/brew
brew install mongodb-community
mongod --config /usr/local/etc/mongod.conf
```

#### 2-2. 依存関係インストール
```bash
cd backend
npm install
```

#### 2-3. 環境変数設定
```bash
cp .env.example .env
```

`.env` の設定例：
```
PORT=3000
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/surechi
JWT_SECRET=your-local-dev-secret-key-change-in-production
JWT_EXPIRE=7d
SOCKET_IO_CORS=http://localhost:3000
FRONTEND_URL=http://localhost:3000

# メール送信（任意 - 未設定でもログに出力）
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASS=password
EMAIL_FROM=noreply@surechi.jp

# APNs プッシュ通知（任意）
APNS_KEY_ID=XXXXXXXXXX
APNS_TEAM_ID=XXXXXXXXXX
APNS_BUNDLE_ID=jp.app.surechi
APNS_KEY_PATH=./apns_key.p8
```

#### 2-4. バックエンド起動
```bash
npm run dev
```

ヘルスチェック：
```bash
curl http://localhost:3000/health
# {"status":"ok"}

curl http://localhost:3000/
# {"message":"スレチ Backend API","version":"1.0.0","status":"running"}
```

### Step 3: iOS アプリ開発環境の構築

iOSプロジェクトは `ios/Surechi/` にあります。

#### 3-1. Xcodeプロジェクトを開く
```bash
open ios/Surechi/Surechi.xcodeproj
# または .xcworkspace がある場合
open ios/Surechi/Surechi.xcworkspace
```

#### 3-2. Info.plist の設定（位置情報パーミッション）

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>近くのユーザーを見つけるために位置情報が必要です</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>すれ違い機能のため、バックグラウンドでも位置情報が必要です</string>
```

#### 3-3. バックエンドURL設定

iOS側でバックエンドのURLを設定してください（シミュレータからはlocalhostへアクセス可能）：

```swift
struct Constants {
    static let API_BASE_URL = "http://localhost:3000"
    static let SOCKET_IO_URL = "http://localhost:3000"
}
```

#### 3-4. ビルド＆実行
```
Xcode: ⌘R
```

位置情報シミュレーション：
```
Xcode → Debug → Simulate Location → Apple, San Francisco など
```

---

## 🔗 接続確認

### API テスト（curl）

```bash
# ユーザー登録
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"テストユーザー","email":"test@example.com","password":"Test123!","age":25}'

# ログイン
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}'

# プロフィール取得
curl http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN"

# コイン残高
curl http://localhost:3000/api/payments/balance \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### WebSocket テスト
```bash
npm install -g wscat
wscat -c "ws://localhost:3000" --header "Authorization: Bearer YOUR_TOKEN"
```

---

## 📊 開発用エンドポイント (`/api/dev`)

開発時のみ使用可能なエンドポイントです。本番環境では無効にしてください。

```bash
# テストユーザー一括作成など
curl http://localhost:3000/api/dev/...
```

---

## 🐛 トラブルシューティング

### バックエンド

**Port 3000 が使用中**
```bash
lsof -i :3000
kill -9 <PID>
# または
PORT=3001 npm run dev
```

**MongoDB接続失敗**
```bash
docker start surechi-mongo
# または
mongosh  # 接続確認
```

**Socket.IO 接続エラー**
- JWTトークンが正しいか確認
- `auth: { token: '...' }` または `Authorization: Bearer ...` ヘッダーが必要

### iOS

**シミュレータからlocalhostに接続できない**
- HTTP接続の場合、`NSAppTransportSecurity` の設定が必要（開発時のみ）
- シミュレータは `localhost` / `127.0.0.1` へのアクセス可能

---

## ✅ チェックリスト

- [ ] Node.js v18+ インストール済み
- [ ] MongoDB 起動済み（Docker or ローカル）
- [ ] `backend/.env` 作成済み
- [ ] `npm install` 完了
- [ ] `npm run dev` でサーバー起動確認
- [ ] `/health` ヘルスチェック成功
- [ ] Xcode インストール済み
- [ ] `ios/Surechi/` プロジェクトをビルド可能
- [ ] シミュレータでAPIへの疎通確認

---

## 📚 参考資料

- [Node.js ドキュメント](https://nodejs.org/docs)
- [Express.js ガイド](https://expressjs.com)
- [MongoDB マニュアル](https://docs.mongodb.com)
- [Socket.IO ドキュメント](https://socket.io)
- [Swift / SwiftUI ドキュメント](https://developer.apple.com/swift)
- [Apple Push Notification service](https://developer.apple.com/documentation/usernotifications)
- [StoreKit 2](https://developer.apple.com/storekit/)

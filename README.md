# RealMatching - 位置情報ベース出会いアプリ

> すれ違ったユーザーが表示され、お互いにいいね！でマッチング できる出会いアプリ

## 📱 プロジェクト概要

**RealMatching** は、リアルタイム位置情報を活用した、若者向けの出会いアプリです。

### 🎯 主要機能
- 🎯 **リアルタイムすれ違い検出** - GPSで近くのユーザーを自動検出
- ❤️ **いいね/スキップ** - カード形式で直感的にマッチング
- 🔄 **相互マッチング** - 両者がいいね！でマッチング成立
- 💬 **リアルタイムチャット** - マッチングユーザーとメッセージ交換
- 👤 **プロフィール管理** - 写真・自己紹介の登録・編集

## 🏗️ プロジェクト構成

```
realmatching/
├── backend/              # Node.js + Express API
│   ├── src/
│   ├── package.json
│   └── README.md
│
├── ios/                  # SwiftUI アプリ
│   ├── RealMatching/     # Xcode プロジェクト
│   └── README.md
│
├── docs/                 # ドキュメント
│   ├── ARCHITECTURE.md   # システム設計
│   ├── API_SPEC.md       # API仕様
│   └── DATABASE.md       # DB設計
│
└── README.md
```

## 🛠️ 技術スタック

### Backend
- **Runtime**: Node.js
- **Framework**: Express.js
- **Language**: TypeScript
- **Database**: MongoDB
- **Real-time**: Socket.IO
- **Authentication**: JWT

### iOS App
- **Language**: Swift
- **UI**: SwiftUI
- **Location**: Core Location
- **Networking**: Socket.IO Client, Alamofire

## 🚀 クイックスタート

### バックエンド セットアップ

```bash
cd backend
npm install
npm run dev
```

### iOS アプリ セットアップ

```bash
cd ios
# Xcode でプロジェクトを開く
open RealMatching.xcworkspace
```

詳細は各フォルダの README.md を参照してください。

## 📋 開発ロードマップ

### Phase 1: 基本機能
- [x] プロジェクト構造
- [ ] 認証システム（登録・ログイン）
- [ ] ユーザープロフィール管理
- [ ] 位置情報同期

### Phase 2: マッチング機能
- [ ] 近くのユーザー検出
- [ ] カード形式UI（Discovery）
- [ ] いいね/スキップ機能
- [ ] マッチング成立ロジック

### Phase 3: チャット & 通知
- [ ] リアルタイムチャット
- [ ] プッシュ通知
- [ ] マッチング通知

### Phase 4: 本番対応
- [ ] テスト（Unit/E2E）
- [ ] セキュリティ対応
- [ ] パフォーマンス最適化
- [ ] App Store リリース準備

## 🔐 セキュリティ

- JWT トークンベースの認証
- 位置情報の暗号化
- API レート制限
- CORS 設定

## 📊 データベース設計

### User Collection
```javascript
{
  _id: ObjectId,
  email: string,
  password: string (hashed),
  profile: {
    name: string,
    age: number,
    bio: string,
    photos: [string],
    location: {
      latitude: number,
      longitude: number,
      updatedAt: Date
    }
  },
  preferences: {
    minAge: number,
    maxAge: number,
    radius: number
  },
  createdAt: Date
}
```

## 🤝 貢献

このプロジェクトは単一開発者による開発です。

## 📝 ライセンス

MIT License

## 📞 サポート

問題が発生した場合は、各フォルダの README.md を参照してください。

---

**Happy coding! 🚀**

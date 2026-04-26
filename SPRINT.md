# スプリントボード - スレチ

## 現在のスプリント: Sprint 1
**期間**: 2026-03-23 〜 2026-03-29
**ゴール**: TestFlight 配信可能な状態への到達（審査申請の前段階完了）
**ベロシティ目標**: 20pt

---

## 📊 進捗
- TODO: 2pt / IN PROGRESS: 0pt / DONE: 31pt
- 達成率: Sprint 1完了（年齢確認機能を追加実装）

---

## 🔴 IN PROGRESS

_なし_

---

## 📋 TODO

### DevOps
- [ ] **[DevOps 2pt]** MongoDB Atlas バックアップ設定

### iOS
- [ ] **[iOS 3pt]** カード画像の比率確認（実機複数機種）

### PO（人手が必要なもの）
- [ ] **[PO]** Apple Developer Program 登録（$99/年）← TestFlight・APNs の前提
- [ ] **[PO]** Bundle ID 設定（com.yourteam.surechi）
- [ ] **[PO]** App Store 掲載用スクリーンショット準備

---

## ✅ DONE

- [x] **[Backend 5pt + iOS 5pt]** 年齢確認（Phase 1: 目視確認）実装
  - Backend: verificationStatus フィールド追加、/api/verification エンドポイント、管理者承認/却下API、requireVerification ミドルウェア（like/superlike/message/socket gating）、16テスト全パス
  - iOS: VerificationView（カメラ/フォトライブラリ対応）、APIClient拡張、AuthViewModel.verificationStatus、ContentView gating（like/superlike）、プロフィール画面に本人確認行追加、Info.plist カメラ権限
- [x] Railway バックエンドデプロイ
- [x] MongoDB Atlas 接続
- [x] iOS 本番サーバー URL 設定
- [x] JWT_SECRET 本番設定
- [x] dev エンドポイントを開発者のみに制限
- [x] アプリアイコンから文字を削除
- [x] **[Backend]** `encounter:swipe` スキーマ確認済み（fromUser/toUser で正常）
- [x] **[Backend]** APNs を環境変数（APNS_KEY_CONTENT）で渡す方式に実装済み
- [x] **[DevOps 1pt]** railway.toml の healthcheckPath を `/health` に修正
- [x] **[iOS 3pt]** プッシュ通知 UNUserNotificationCenterDelegate 実装（フォアグラウンド表示・タップ遷移）
- [x] **[DevOps 3pt]** GitHub Actions CI/CD 設定（backend-ci.yml: build + lint）
- [x] **[Backend 3pt]** すれ違い検出テスト作成（18テスト全パス: Haversine・100m判定・ブロック除外・重複防止）
- [x] **[Backend 2pt]** encounter:swipe スキーマ不整合修正（from/to → fromUser/toUser）
- [x] **[Backend 2pt]** APNs を APNS_KEY_CONTENT 環境変数方式に変更（Railway対応）

---

## 🚧 障害 (Impediments)

| # | 内容 | 担当 | 優先度 |
|---|------|------|--------|
| 1 | Apple Developer Program 未登録 → TestFlight・APNs 実機テスト不可 | PO | 🔴 High |

---

## 📈 ベロシティ履歴

| スプリント | 目標 | 達成 |
|-----------|------|------|
| Sprint 1  | 20pt | 進行中 |

---

## 📝 スプリント計画メモ（2026-03-23）

**スタンドアップ結果サマリー：**
- Backend: コア実装は完了。バグ2件を発見（encounter:swipe・APNs）→ 本日修正着手
- iOS: UI実装はほぼ完了。プッシュ通知ハンドリングが未実装 → 本日着手
- DevOps: Railway稼働中。healthcheckPath修正・CI/CD構築が残存

**本日の各部署優先タスク：**
- Backend → encounter:swipe バグ修正 + APNs環境変数化
- iOS → UNUserNotificationCenterDelegate 実装
- DevOps → railway.toml healthcheckPath修正

# Railway 環境変数設定リスト

Railwayダッシュボード → サービス → Variables に以下を追加する。

---

## 必須（アプリ動作に必要）

| 変数名 | 値の例 | 説明 |
|--------|--------|------|
| `NODE_ENV` | `production` | 本番モード |
| `PORT` | `3000` | Railwayが自動設定するので不要な場合あり |
| `MONGODB_URI` | `mongodb+srv://...` | Atlas接続文字列（既存のもの） |
| `JWT_SECRET` | （下記コマンドで生成） | アクセストークン署名キー |
| `FRONTEND_URL` | `https://surechi.app` | CORS許可URL（なければ`*`でも可） |

JWT_SECRETの生成コマンド（ターミナルで実行）：
```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

---

## メール送信（パスワードリセット・メール認証に必要）

Gmailを使う場合：
1. Googleアカウント → セキュリティ → 2段階認証を有効化
2. セキュリティ → アプリパスワード → 「スレチ」で16桁パスワードを生成

| 変数名 | 値 |
|--------|-----|
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | `your@gmail.com` |
| `SMTP_PASS` | （16桁のアプリパスワード） |
| `SMTP_FROM` | `スレチ <noreply@gmail.com>` |

---

## プッシュ通知（APNs）

Apple Developerに登録後：
1. developer.apple.com → Certificates → Keys → `+`
2. Apple Push Notifications service (APNs) にチェック
3. .p8ファイルをダウンロード
4. RailwayのVolumesにアップロード or 文字列化して環境変数に

| 変数名 | 取得場所 |
|--------|---------|
| `APNS_KEY_ID` | Keys一覧に表示される10桁のID |
| `APNS_TEAM_ID` | developer.apple.com右上のアカウント情報 |
| `APNS_BUNDLE_ID` | `jp.app.surechi` |
| `APNS_KEY_PATH` | .p8ファイルのパス（Volume使用時） |

---

## 設定後の確認

```bash
# バックエンドのヘルスチェック
curl https://your-railway-url.up.railway.app/api/auth/me
# → 401が返れば正常動作
```

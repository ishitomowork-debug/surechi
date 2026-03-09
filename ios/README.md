# RealMatching iOS App Setup Guide

位置情報ベースの出会いアプリ「RealMatching」のiOSアプリ開発ガイド

## 🛠️ 技術スタック
- **言語**: Swift
- **UI Framework**: SwiftUI
- **Minimum iOS**: iOS 15.0
- **通信**: WebSocket (Socket.IO Client)

## 📋 必要な環境
- macOS 12 以上
- Xcode 14 以上
- CocoaPods (依存関係管理)

## 🚀 プロジェクト作成

### 1. Xcode でプロジェクト作成
```bash
# または Xcode UI から新規プロジェクト作成
# App テンプレート選択
# Interface: SwiftUI
# Life Cycle: SwiftUI App
```

### 2. Podfile 作成
プロジェクトルートで以下を実行：

```bash
pod init
```

### 3. 依存関係をインストール

Podfile に以下を追加：

```ruby
target 'RealMatching' do
  pod 'Socket.IO-Client-Swift', '~> 16.0.0'
  pod 'Alamofire', '~> 5.8.0'
end
```

その後インストール：
```bash
pod install
```

### 4. プロジェクトを開く
```bash
open RealMatching.xcworkspace
```

## 📁 プロジェクト構造

```
RealMatching/
├── RealMatching/
│   ├── App/
│   │   └── RealMatchingApp.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── AuthView.swift           # ログイン・登録
│   │   ├── ProfileView.swift        # プロフィール
│   │   ├── DiscoveryView.swift      # すれ違いユーザー表示
│   │   ├── MatchesView.swift        # マッチング管理
│   │   └── ChatView.swift           # チャット
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── UserViewModel.swift
│   │   └── MatchViewModel.swift
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Match.swift
│   │   └── Message.swift
│   ├── Services/
│   │   ├── APIClient.swift          # HTTP通信
│   │   ├── WebSocketService.swift   # Socket.IO
│   │   └── LocationManager.swift    # 位置情報
│   └── Utils/
│       └── Constants.swift
└── RealMatching.xcodeproj/
```

## 🔐 Info.plist 設定

位置情報パーミッション設定：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>近くのユーザーを見つけるために位置情報が必要です</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>バックグラウンドでユーザーをマッチングするために位置情報が必要です</string>

<key>NSBonjourServiceTypes</key>
<array>
  <string>_http._tcp</string>
  <string>_ws._tcp</string>
</array>
```

## 🎨 主要機能の実装

### 1. 認証フロー
- ユーザー登録（メール/パスワード）
- ログイン
- JWT トークン管理

### 2. 位置情報機能
- CLLocationManager でリアルタイム位置情報取得
- サーバーに定期的に送信

### 3. Discovery（すれ違い表示）
- Socket.IO でサーバーから近くのユーザー情報受信
- カード形式でユーザー表示
- スワイプでいいね/スキップ

### 4. マッチング
- 相互いいね時にマッチング確定
- マッチング一覧表示

### 5. チャット
- マッチ相手とメッセージ交換
- リアルタイムメッセージ同期

## ⚡ サンプルコード

### ContentView.swift
```swift
import SwiftUI

struct ContentView: View {
    @StateObject var authVM = AuthViewModel()
    
    var body: some View {
        if authVM.isLoggedIn {
            TabView {
                DiscoveryView()
                    .tabItem {
                        Label("Discovery", systemImage: "heart")
                    }
                
                MatchesView()
                    .tabItem {
                        Label("Matches", systemImage: "checkmark.circle")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
            }
        } else {
            AuthView(authVM: authVM)
        }
    }
}
```

### LocationManager.swift
```swift
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }
}
```

## 🔗 バックエンド接続

環境に応じてサーバーURL を設定：

```swift
// Constants.swift
struct Constants {
    static let API_BASE_URL = "http://localhost:3000"
    static let SOCKET_IO_URL = "http://localhost:3000"
}
```

## 📦 ビルド & 実行

1. Xcode でプロジェクトを開く
2. シミュレータまたはデバイスを選択
3. ⌘R でビルド・実行

## 🚀 デバッグ

### シミュレータで位置情報テスト
- Xcode Debug → Simulate Location で テスト位置を設定

## 📝 次のステップ
- [ ] 認証画面の実装
- [ ] 位置情報機能の統合
- [ ] Discovery ビューの実装
- [ ] WebSocket 接続テスト
- [ ] チャット機能
- [ ] App Store 提出準備

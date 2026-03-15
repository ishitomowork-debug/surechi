#!/bin/bash

# RealMatching Project Setup Script
# このスクリプトで開発環境をセットアップします

set -e

echo "🚀 RealMatching プロジェクトセットアップを開始します..."
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js がインストールされていません"
    echo "   https://nodejs.org/ からインストールしてください"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm がインストールされていません"
    exit 1
fi

# Check if MongoDB is available
if ! command -v mongo &> /dev/null; then
    echo "⚠️  MongoDB がシステムパス上にありません"
    echo "   Docker または https://www.mongodb.com/try/download/community からインストールしてください"
fi

echo "✅ Node.js $(node --version) が検出されました"
echo "✅ npm $(npm --version) が検出されました"
echo ""

# Setup Backend
echo "📦 バックエンド依存関係をインストール中..."
cd backend
npm install
echo "✅ バックエンド依存関係インストール完了"
echo ""

# Create .env file
if [ ! -f .env ]; then
    echo "📝 .env ファイルを作成中..."
    cp .env.example .env
    echo "✅ .env ファイルを作成しました"
    echo "   backend/.env を編集して設定値を変更してください"
fi

cd ..
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 セットアップが完了しました！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 次のステップ："
echo ""

echo "1️⃣  バックエンドの起動（開発モード）:"
echo "   cd backend"
echo "   npm run dev"
echo ""

echo "2️⃣  iOS アプリの開発："
echo "   • Xcode をインストール: https://developer.apple.com/xcode/"
echo "   • ios/ フォルダの README.md を参照"
echo "   • RealMatching.xcworkspace を開く"
echo ""

echo "3️⃣  MongoDB セットアップ（ローカル開発）:"
echo "   Docker を使用する場合："
echo "   docker run -d -p 27017:27017 --name realmatching-mongo mongo"
echo ""

echo "4️⃣  API テスト:"
echo "   curl http://localhost:3000/health"
echo ""

echo "🔗 ドキュメント:"
echo "   • docs/ARCHITECTURE.md - システムアーキテクチャ"
echo "   • backend/README.md - バックエンド設定"
echo "   • ios/README.md - iOS アプリ設定"
echo ""

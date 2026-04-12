import StoreKit
import Foundation
import Combine

@MainActor
final class StoreManager: ObservableObject {

    // App Store Connect で設定するプロダクトID
    static let productIDs = [
        "jp.app.surechi.coins.50",
        "jp.app.surechi.coins.150",
        "jp.app.surechi.coins.500",
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success(coins: Int)
        case failed(String)
    }

    /// コイン数マッピング
    static func coins(for productID: String) -> Int {
        switch productID {
        case "jp.app.surechi.coins.50":  return 50
        case "jp.app.surechi.coins.150": return 150
        case "jp.app.surechi.coins.500": return 500
        default: return 0
        }
    }

    init() {
        Task { await loadProducts() }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("StoreKit products load error:", error)
        }
    }

    /// StoreKit 2 購入フロー（JWS検証対応）
    func purchase(_ product: Product, token: String) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let coins = Self.coins(for: product.id)
                // JWS署名付きトランザクションをバックエンドに送信して検証・コイン付与
                let jwsRepresentation = verification.jwsRepresentation
                try await APIClient().verifyIAP(signedTransaction: jwsRepresentation, token: token)
                await transaction.finish()
                purchaseState = .success(coins: coins)
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .failed("不明なエラーが発生しました")
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

}

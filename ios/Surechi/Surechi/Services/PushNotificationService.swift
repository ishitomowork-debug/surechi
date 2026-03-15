import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

class PushNotificationService: NSObject {
    static let shared = PushNotificationService()

    private let apiClient = APIClient()

    /// 通知許可をリクエストし、APNs 登録まで行う
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                #if canImport(UIKit)
                UIApplication.shared.registerForRemoteNotifications()
                #endif
            }
        }
    }

    /// AppDelegate から呼ばれる: デバイストークンをバックエンドに送信
    func sendTokenToServer(deviceToken: Data, authToken: String) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            try? await apiClient.updateDeviceToken(deviceToken: tokenString, authToken: authToken)
        }
    }
}

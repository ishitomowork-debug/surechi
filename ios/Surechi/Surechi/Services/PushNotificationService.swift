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
        UNUserNotificationCenter.current().delegate = self
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

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    /// フォアグラウンド時にも通知バナーを表示する
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// 通知タップ時の画面遷移
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String ?? ""

        NotificationCenter.default.post(
            name: .pushNotificationReceived,
            object: nil,
            userInfo: ["type": type, "data": userInfo]
        )

        completionHandler()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
}

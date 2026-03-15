import SwiftUI

@main
struct スレチApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showEmailVerifiedAlert = false

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--skipAuth") {
            KeychainHelper.save(key: "authToken", value: "ui_test_mock_token")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AuthView()
                .onOpenURL { url in handleDeepLink(url) }
                .alert("メールアドレス確認完了", isPresented: $showEmailVerifiedAlert) {
                    Button("OK") {}
                } message: {
                    Text("メールアドレスが確認されました。")
                }
        }
    }

    /// surechi://verify-email?token=xxx を処理
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "realmatching",
              url.host == "verify-email",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value
        else { return }

        Task {
            let urlStr = "\(Config.apiBaseURL)/auth/verify-email?token=\(token)"
            guard let reqURL = URL(string: urlStr) else { return }
            let (_, response) = (try? await URLSession.shared.data(from: reqURL)) ?? (Data(), HTTPURLResponse())
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                await MainActor.run { showEmailVerifiedAlert = true }
            }
        }
    }
}

// MARK: - AppDelegate (APNs)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = KeychainHelper.load(key: "authToken") ?? ""
        guard !token.isEmpty else { return }
        Task { @MainActor in
            PushNotificationService.shared.sendTokenToServer(deviceToken: deviceToken, authToken: token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed:", error.localizedDescription)
    }
}

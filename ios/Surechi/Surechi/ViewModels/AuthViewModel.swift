import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var token: String? = nil
    @Published var currentUser: UserProfile? = nil

    private let apiClient = APIClient()
    private static let tokenKey = "authToken"
    private static let refreshKey = "refreshToken"

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--resetAuth") {
            KeychainHelper.delete(key: Self.tokenKey)
            KeychainHelper.delete(key: Self.refreshKey)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--skipAuth") {
            self.token = "mock-token"
            self.isLoggedIn = true
            self.currentUser = UserProfile(id: "mock", name: "テストユーザー", email: "test@test.com", age: 25, bio: nil, interests: [], avatar: nil, coins: 10, emailVerified: true)
            return
        }
        #endif
        if let savedToken = KeychainHelper.load(key: Self.tokenKey) {
            self.token = savedToken
            self.isLoggedIn = true
            self.loadProfile()
        }
    }

    func register(email: String, password: String, name: String, birthDate: Date) {
        isLoading = true
        errorMessage = nil
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 18

        Task {
            do {
                let response = try await apiClient.register(
                    name: name, email: email, password: password, age: max(18, age)
                )
                self.saveTokens(token: response.token, refreshToken: response.refreshToken)
                self.isLoggedIn = true
                self.loadProfile()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await apiClient.login(email: email, password: password)
                self.saveTokens(token: response.token, refreshToken: response.refreshToken)
                self.isLoggedIn = true
                self.loadProfile()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func logout() {
        if let refreshToken = KeychainHelper.load(key: Self.refreshKey) {
            Task { try? await apiClient.serverLogout(refreshToken: refreshToken) }
        }
        token = nil
        isLoggedIn = false
        currentUser = nil
        KeychainHelper.delete(key: Self.tokenKey)
        KeychainHelper.delete(key: Self.refreshKey)
        errorMessage = nil
    }

    func loadProfile() {
        guard let token = token else { return }
        Task {
            do {
                let response = try await apiClient.getProfile(token: token)
                self.currentUser = response.user
            } catch let apiError as APIError {
                if case .invalidResponse(let code, _) = apiError, code == 401 {
                    await self.tryRefreshToken()
                } else if case .invalidResponse(let code, _) = apiError, code == 404 {
                    self.logout()
                }
            } catch {}
        }
    }

    func tryRefreshToken() async {
        guard let refreshToken = KeychainHelper.load(key: Self.refreshKey) else {
            logout()
            return
        }
        do {
            let newToken = try await apiClient.refreshAccessToken(refreshToken: refreshToken)
            self.token = newToken
            KeychainHelper.save(key: Self.tokenKey, value: newToken)
            self.loadProfile()
        } catch {
            logout()
        }
    }

    func seedNearbyUsers() async -> String {
        guard let token = token else { return "認証エラーが発生しました" }
        do {
            return try await apiClient.seedNearbyUsers(token: token)
        } catch {
            return "エラー: \(error.localizedDescription)"
        }
    }

    func simulateEncounter() async -> String {
        guard let token = token else { return "認証エラーが発生しました" }
        do {
            return try await apiClient.simulateEncounter(token: token)
        } catch {
            return "エラー: \(error.localizedDescription)"
        }
    }

    func deleteAccount() async -> String? {
        guard let token = token else { return "認証エラーが発生しました" }
        do {
            try await apiClient.deleteAccount(token: token)
            logout()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func forgotPassword(email: String) async -> String? {
        do {
            try await apiClient.forgotPassword(email: email)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func updateProfile(name: String, age: Int, bio: String, interests: [String] = [], avatar: String? = nil) async -> String? {
        guard let token = token else { return "認証エラーが発生しました" }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await apiClient.updateProfile(
                name: name, age: age, bio: bio, interests: interests, avatar: avatar, token: token
            )
            self.currentUser = response.user
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Private

    private func saveTokens(token: String, refreshToken: String?) {
        self.token = token
        KeychainHelper.save(key: Self.tokenKey, value: token)
        if let refreshToken = refreshToken {
            KeychainHelper.save(key: Self.refreshKey, value: refreshToken)
        }
    }
}

import Foundation
import Combine

@MainActor
class MatchViewModel: ObservableObject {
    @Published var matches: [MatchedUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var totalUnreadCount: Int { matches.reduce(0) { $0 + $1.unreadCount } }

    private let apiClient = APIClient()
    private var token: String?

    func configure(token: String) {
        self.token = token
    }

    func fetchMatches() {
        guard let token = token else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await apiClient.getMatches(token: token)
                self.matches = response.matches
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func blockUser(userId: String, matchId: String) {
        guard let token = token else { return }
        Task {
            try? await apiClient.blockUser(userId: userId, token: token)
            self.matches.removeAll { $0.id == matchId }
        }
    }
}

import Foundation
import Combine
import CoreLocation

@MainActor
class DiscoveryViewModel: ObservableObject {
    @Published var nearbyUsers: [NearbyUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canUndo = false
    @Published var likesRemaining: Int = 20
    @Published var limitReached = false

    // 検索フィルター
    @Published var filterMinAge: Int = 18
    @Published var filterMaxAge: Int = 60
    @Published var filterRadius: Int = 5000

    private let apiClient = APIClient()
    private var token: String?

    func configure(token: String) {
        self.token = token
    }

    func fetchNearbyUsers() {
        guard let token = token else { return }
        isLoading = true
        errorMessage = nil
        canUndo = false

        Task {
            do {
                let response = try await apiClient.getNearbyUsers(
                    token: token,
                    radius: filterRadius,
                    minAge: filterMinAge,
                    maxAge: filterMaxAge
                )
                self.nearbyUsers = response.users
                if let remaining = response.likesRemaining {
                    self.likesRemaining = remaining
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func likeUser(_ userId: String) {
        guard let token = token else { return }
        canUndo = false
        nearbyUsers.removeAll { $0.id == userId }

        Task {
            do {
                let response = try await apiClient.likeUser(targetUserId: userId, token: token)
                if response.limitReached == true {
                    self.limitReached = true
                    fetchNearbyUsers()
                } else {
                    self.likesRemaining = max(0, self.likesRemaining - 1)
                }
            } catch {
                self.errorMessage = error.localizedDescription
                fetchNearbyUsers()
            }
        }
    }

    func superlikeUser(_ userId: String) {
        guard let token = token else { return }
        canUndo = false
        nearbyUsers.removeAll { $0.id == userId }

        Task {
            do {
                let response = try await apiClient.superlikeUser(targetUserId: userId, token: token)
                if response.limitReached == true {
                    self.limitReached = true
                    fetchNearbyUsers()
                } else {
                    self.likesRemaining = max(0, self.likesRemaining - 1)
                }
            } catch {
                self.errorMessage = error.localizedDescription
                fetchNearbyUsers()
            }
        }
    }

    func dislikeUser(_ userId: String) {
        guard let token = token else { return }
        canUndo = true
        nearbyUsers.removeAll { $0.id == userId }

        Task {
            do {
                try await apiClient.dislikeUser(targetUserId: userId, token: token)
            } catch {
                self.errorMessage = error.localizedDescription
                fetchNearbyUsers()
            }
        }
    }

    func undoDislike() {
        guard let token = token, canUndo else { return }
        canUndo = false

        Task {
            do {
                let restoredUser = try await apiClient.undoDislike(token: token)
                self.nearbyUsers.insert(restoredUser, at: 0)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func blockUser(_ userId: String) {
        guard let token = token else { return }
        canUndo = false
        nearbyUsers.removeAll { $0.id == userId }
        Task { try? await apiClient.blockUser(userId: userId, token: token) }
    }

    func reportUser(_ userId: String, reason: String) {
        guard let token = token else { return }
        Task { try? await apiClient.reportUser(userId: userId, reason: reason, token: token) }
    }

    func updateLocation(_ location: CLLocation, token: String) {
        Task {
            do {
                try await apiClient.updateLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    token: token
                )
                fetchNearbyUsers()
            } catch {
                print("Location update failed:", error.localizedDescription)
            }
        }
    }
}

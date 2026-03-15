import Foundation

struct APIClient {
    private let baseURL = Config.apiBaseURL

    // MARK: - Auth

    func register(name: String, email: String, password: String, age: Int, bio: String = "") async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["name": name, "email": email, "password": password, "age": age, "bio": bio]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func getProfile(token: String) async throws -> ProfileResponse {
        let url = URL(string: "\(baseURL)/auth/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(ProfileResponse.self, from: data)
    }

    // MARK: - User

    func updateProfile(name: String, age: Int, bio: String, interests: [String] = [], avatar: String? = nil, token: String) async throws -> ProfileResponse {
        let url = URL(string: "\(baseURL)/users/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["name": name, "age": age, "bio": bio, "interests": interests]
        if let avatar = avatar { payload["avatar"] = avatar }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(ProfileResponse.self, from: data)
    }

    func updateLocation(latitude: Double, longitude: Double, token: String) async throws {
        let url = URL(string: "\(baseURL)/users/location")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["latitude": latitude, "longitude": longitude]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: nil, response: response)
        }
    }

    func blockUser(userId: String, token: String) async throws {
        let url = URL(string: "\(baseURL)/users/block/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: nil, response: response)
        }
    }

    func reportUser(userId: String, reason: String, token: String) async throws {
        let url = URL(string: "\(baseURL)/users/report/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["reason": reason]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: nil, response: response)
        }
    }

    func updateDeviceToken(deviceToken: String, authToken: String) async throws {
        let url = URL(string: "\(baseURL)/users/device-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["deviceToken": deviceToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: nil, response: response)
        }
    }

    // MARK: - Match

    func getNearbyUsers(token: String, limit: Int = 10, radius: Int = 5000, minAge: Int = 18, maxAge: Int = 60) async throws -> NearbyUsersResponse {
        let url = URL(string: "\(baseURL)/matches/nearby?limit=\(limit)&radius=\(radius)&minAge=\(minAge)&maxAge=\(maxAge)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(NearbyUsersResponse.self, from: data)
    }

    func likeUser(targetUserId: String, token: String) async throws -> LikeResponse {
        let url = URL(string: "\(baseURL)/matches/like")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["targetUserId": targetUserId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(LikeResponse.self, from: data)
    }

    func superlikeUser(targetUserId: String, token: String) async throws -> LikeResponse {
        let url = URL(string: "\(baseURL)/matches/superlike")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["targetUserId": targetUserId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(LikeResponse.self, from: data)
    }

    func dislikeUser(targetUserId: String, token: String) async throws {
        let url = URL(string: "\(baseURL)/matches/dislike")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["targetUserId": targetUserId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: nil, response: response)
        }
    }

    func undoDislike(token: String) async throws -> NearbyUser {
        let url = URL(string: "\(baseURL)/matches/undo")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        struct UndoResponse: Codable { let user: NearbyUser }
        return try JSONDecoder().decode(UndoResponse.self, from: data).user
    }

    func getLikedMe(token: String) async throws -> [LikedMeUser] {
        let url = URL(string: "\(baseURL)/matches/liked-me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        struct LikedMeResponse: Codable { let users: [LikedMeUser] }
        return try JSONDecoder().decode(LikedMeResponse.self, from: data).users
    }

    func getMatches(token: String) async throws -> MatchesResponse {
        let url = URL(string: "\(baseURL)/matches/matched")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(MatchesResponse.self, from: data)
    }

    // MARK: - Messages

    func getMessages(matchId: String, token: String) async throws -> MessagesResponse {
        let url = URL(string: "\(baseURL)/messages/\(matchId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(MessagesResponse.self, from: data)
    }

    func markMessagesAsRead(matchId: String, token: String) async throws {
        let url = URL(string: "\(baseURL)/messages/\(matchId)/read")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: nil, response: response)
        }
    }

    // MARK: - Payments

    func getCoinPackages() async throws -> [CoinPackage] {
        let url = URL(string: "\(baseURL)/payments/packages")!
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        struct Resp: Codable { let packages: [CoinPackage] }
        return try JSONDecoder().decode(Resp.self, from: data).packages
    }

    func purchaseCoins(packageId: String, token: String) async throws -> Int {
        let url = URL(string: "\(baseURL)/payments/purchase")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["packageId": packageId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        struct Resp: Codable { let coins: Int }
        return try JSONDecoder().decode(Resp.self, from: data).coins
    }

    // MARK: - Dev

    func seedNearbyUsers(token: String) async throws -> String {
        let url = URL(string: "\(baseURL)/dev/seed")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return "テストユーザーを追加しました"
    }

    func getNearbyUsersForMap(token: String) async throws -> MapUsersResponse {
        let url = URL(string: "\(baseURL)/matches/nearby-map")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return try JSONDecoder().decode(MapUsersResponse.self, from: data)
    }

    func simulateEncounter(token: String) async throws -> String {
        let url = URL(string: "\(baseURL)/dev/simulate-encounter")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        return "すれ違いをシミュレートしました"
    }

    // MARK: - Account

    func deleteAccount(token: String) async throws {
        let url = URL(string: "\(baseURL)/auth/account")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
    }

    func forgotPassword(email: String) async throws {
        let url = URL(string: "\(baseURL)/auth/forgot-password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
    }

    func refreshAccessToken(refreshToken: String) async throws -> String {
        let url = URL(string: "\(baseURL)/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.fromResponse(data: data, response: response)
        }
        struct RefreshResponse: Codable { let token: String }
        return try JSONDecoder().decode(RefreshResponse.self, from: data).token
    }

    func serverLogout(refreshToken: String) async throws {
        let url = URL(string: "\(baseURL)/auth/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])
        _ = try? await URLSession.shared.data(for: request)
    }
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let message: String
    let token: String
    let refreshToken: String?
    let user: UserInfo
}

struct UserInfo: Codable {
    let id: String
    let name: String
    let email: String
    let age: Int
}

struct ProfileResponse: Codable {
    let user: UserProfile
}

struct UserProfile: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let age: Int
    let bio: String?
    let interests: [String]?
    let avatar: String?
    let coins: Int?
    let emailVerified: Bool?
}

struct MapUser: Codable, Identifiable {
    let id: String
    let name: String
    let age: Int
    let bio: String?
    let avatar: String?
    let latitude: Double
    let longitude: Double
}

struct MapCenter: Codable {
    let latitude: Double
    let longitude: Double
}

struct MapUsersResponse: Codable {
    let users: [MapUser]
    let center: MapCenter
}

struct CoinPackage: Codable, Identifiable {
    let id: String
    let coins: Int
    let price: Int
    let label: String
}

struct NearbyUsersResponse: Codable {
    let users: [NearbyUser]
    let likesRemaining: Int?
}

struct NearbyUser: Codable, Identifiable {
    let id: String
    let name: String
    let age: Int
    let bio: String
    let interests: [String]
    let avatar: String?
    let distance: Int
    let lastActiveAt: String?
    let superlikedMe: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, age, bio, interests, avatar, distance, lastActiveAt, superlikedMe
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        age = try c.decode(Int.self, forKey: .age)
        bio = (try? c.decode(String.self, forKey: .bio)) ?? ""
        interests = (try? c.decode([String].self, forKey: .interests)) ?? []
        avatar = try? c.decode(String.self, forKey: .avatar)
        distance = (try? c.decode(Int.self, forKey: .distance)) ?? 0
        lastActiveAt = try? c.decode(String.self, forKey: .lastActiveAt)
        superlikedMe = (try? c.decode(Bool.self, forKey: .superlikedMe)) ?? false
    }
}

struct LikedMeUser: Codable, Identifiable {
    let id: String
    let name: String
    let age: Int
    let bio: String
    let interests: [String]
    let avatar: String?
    let isSuperLike: Bool
    let likedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, age, bio, interests, avatar, isSuperLike, likedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        age = try c.decode(Int.self, forKey: .age)
        bio = (try? c.decode(String.self, forKey: .bio)) ?? ""
        interests = (try? c.decode([String].self, forKey: .interests)) ?? []
        avatar = try? c.decode(String.self, forKey: .avatar)
        isSuperLike = (try? c.decode(Bool.self, forKey: .isSuperLike)) ?? false
        likedAt = (try? c.decode(String.self, forKey: .likedAt)) ?? ""
    }
}

struct LikeResponse: Codable {
    let message: String
    let matched: Bool
    let match: MatchInfo?
    let limitReached: Bool?
}

struct MatchInfo: Codable {
    let id: String
    let matchedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case matchedAt
    }
}

struct MatchesResponse: Codable {
    let matches: [MatchedUser]
    let total: Int
}

struct LastMessage: Codable {
    let content: String
    let senderId: String
    let createdAt: String
}

struct MatchedUser: Codable, Identifiable {
    let id: String
    let matchedUser: MatchedUserInfo
    let matchedAt: String
    let expiresAt: String?
    let unreadCount: Int
    let lastMessage: LastMessage?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case matchedUser, matchedAt, expiresAt, unreadCount, lastMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        matchedUser = try container.decode(MatchedUserInfo.self, forKey: .matchedUser)
        matchedAt = try container.decode(String.self, forKey: .matchedAt)
        expiresAt = try? container.decode(String.self, forKey: .expiresAt)
        unreadCount = (try? container.decode(Int.self, forKey: .unreadCount)) ?? 0
        lastMessage = try? container.decode(LastMessage.self, forKey: .lastMessage)
    }
}

struct MatchedUserInfo: Codable, Equatable {
    let id: String
    let name: String
    let age: Int
    let bio: String?
    let interests: [String]?
    let avatar: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, age, bio, interests, avatar
    }
}

// MARK: - Error Handling

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int, message: String)
    case decodingError
    case networkError(Error)
    case rateLimited

    static func fromResponse(data: Data?, response: URLResponse) -> APIError {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statusCode == 429 { return .rateLimited }
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = json["error"] as? String {
            return .invalidResponse(statusCode: statusCode, message: msg)
        }
        return .invalidResponse(statusCode: statusCode, message: "Unknown error")
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURLです"
        case .invalidResponse(_, let message): return message
        case .decodingError: return "データの解析に失敗しました"
        case .networkError(let error): return "ネットワークエラー: \(error.localizedDescription)"
        case .rateLimited: return "しばらく時間をおいてから再試行してください（リクエスト制限）"
        }
    }
}

import Foundation
import Combine
import SocketIO

/// リアルタイム通信サービス（Socket.IO）
@MainActor
class SocketService: ObservableObject {
    @Published var isConnected = false
    @Published var newMatchNotification: MatchNotification?
    @Published var coinsInsufficient = false
    @Published var currentCoins: Int = 0
    @Published var pendingEncounter: EncounterUser?   // すれ違い通知
    @Published var encounterMatch: EncounterMatchInfo? // すれ違いマッチ成立

    var onNewMessage: ((MessageData) -> Void)?
    var onMessageSent: ((MessageData) -> Void)?
    var onMessagesRead: ((String) -> Void)?

    private var manager: SocketManager?
    private(set) var socket: SocketIOClient?

    func connect(token: String) {
        guard let url = URL(string: Config.serverURL) else { return }

        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .extraHeaders(["Authorization": "Bearer \(token)"]),
            .reconnects(true),
            .reconnectWait(3),
        ])
        socket = manager?.defaultSocket
        addHandlers()
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        isConnected = false
    }

    func sendMessage(matchId: String, content: String) {
        socket?.emit("message:send", ["matchId": matchId, "content": content])
    }

    func emitMessagesRead(matchId: String) {
        socket?.emit("message:read", ["matchId": matchId])
    }

    func sendLocationUpdate(latitude: Double, longitude: Double) {
        socket?.emit("location:update", ["latitude": latitude, "longitude": longitude])
    }

    func sendEncounterSwipe(targetUserId: String, liked: Bool) {
        socket?.emit("encounter:swipe", ["targetUserId": targetUserId, "liked": liked])
        pendingEncounter = nil
    }

    // MARK: - Private

    private func addHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in self?.isConnected = true }
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.isConnected = false }
        }

        // 受信メッセージ（相手から来た）
        socket?.on("message:receive") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let message = MessageData(from: dict) else { return }
            Task { @MainActor in self?.onNewMessage?(message) }
        }

        // 送信確認（自分が送った）
        socket?.on("message:sent") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let message = MessageData(from: dict) else { return }
            Task { @MainActor in self?.onMessageSent?(message) }
        }

        // マッチング通知
        socket?.on("match:new") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let notification = MatchNotification(from: dict) else { return }
            Task { @MainActor in self?.newMatchNotification = notification }
        }

        // 既読通知（相手が既読にした）
        socket?.on("message:read") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let matchId = dict["matchId"] as? String else { return }
            Task { @MainActor in self?.onMessagesRead?(matchId) }
        }

        // コイン残高更新
        socket?.on("coins:updated") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let coins = dict["coins"] as? Int else { return }
            Task { @MainActor in self?.currentCoins = coins }
        }

        // コイン不足
        socket?.on("coins:insufficient") { [weak self] _, _ in
            Task { @MainActor in self?.coinsInsufficient = true }
        }

        // すれ違い通知
        socket?.on("encounter:nearby") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let userDict = dict["user"] as? [String: Any],
                  let user = EncounterUser(from: userDict) else { return }
            Task { @MainActor in self?.pendingEncounter = user }
        }

        // すれ違いマッチ成立
        socket?.on("encounter:matched") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let matchId = dict["matchId"] as? String,
                  let userDict = dict["user"] as? [String: Any],
                  let user = EncounterUser(from: userDict) else { return }
            Task { @MainActor in
                self?.encounterMatch = EncounterMatchInfo(matchId: matchId, user: user)
            }
        }
    }
}

// MARK: - Data Models

struct MessageData: Identifiable {
    let id: String
    let matchId: String
    let senderId: String
    let content: String
    let read: Bool
    let createdAt: String

    init(id: String, matchId: String, senderId: String, content: String, read: Bool, createdAt: String) {
        self.id = id
        self.matchId = matchId
        self.senderId = senderId
        self.content = content
        self.read = read
        self.createdAt = createdAt
    }

    init?(from dict: [String: Any]) {
        guard let id = dict["_id"] as? String,
              let matchId = dict["matchId"] as? String,
              let senderId = dict["senderId"] as? String,
              let content = dict["content"] as? String else { return nil }
        self.id = id
        self.matchId = matchId
        self.senderId = senderId
        self.content = content
        self.read = dict["read"] as? Bool ?? false
        self.createdAt = dict["createdAt"] as? String ?? ""
    }
}

// Codable版（REST API用）
struct MessageDataCodable: Codable, Identifiable {
    let id: String
    let matchId: String
    let senderId: String
    let content: String
    let read: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case matchId, senderId, content, read, createdAt
    }

    func toMessageData() -> MessageData {
        MessageData(from: [
            "_id": id, "matchId": matchId, "senderId": senderId,
            "content": content, "read": read, "createdAt": createdAt,
        ])!
    }
}

struct MessagesResponse: Codable {
    let messages: [MessageDataCodable]
}

struct EncounterUser: Identifiable, Equatable {
    let id: String
    let name: String
    let age: Int
    let bio: String?
    let avatar: String?

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let age = dict["age"] as? Int else { return nil }
        self.id = id
        self.name = name
        self.age = age
        self.bio = dict["bio"] as? String
        self.avatar = dict["avatar"] as? String
    }
}

struct EncounterMatchInfo: Equatable {
    let matchId: String
    let user: EncounterUser
}

extension EncounterUser {
    func toMatchedUser(matchId: String) -> MatchedUser {
        let dict: [String: Any] = [
            "_id": matchId,
            "matchedUser": [
                "_id": id,
                "name": name,
                "age": age,
                "bio": bio ?? "",
                "avatar": avatar as Any,
                "interests": [String](),
            ],
            "matchedAt": ISO8601DateFormatter().string(from: Date()),
            "unreadCount": 0,
        ]
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(MatchedUser.self, from: data)
    }
}

struct MatchNotification: Equatable {
    let matchId: String
    let matchedUser: MatchedUserInfo
    let timestamp: String

    init?(from dict: [String: Any]) {
        guard let matchId = dict["matchId"] as? String,
              let userDict = dict["matchedUser"] as? [String: Any],
              let userId = userDict["_id"] as? String,
              let name = userDict["name"] as? String,
              let age = userDict["age"] as? Int else { return nil }
        self.matchId = matchId
        self.matchedUser = MatchedUserInfo(
            id: userId, name: name, age: age,
            bio: userDict["bio"] as? String,
            interests: userDict["interests"] as? [String],
            avatar: userDict["avatar"] as? String
        )
        self.timestamp = dict["timestamp"] as? String ?? ""
    }
}

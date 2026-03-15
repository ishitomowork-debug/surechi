import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [MessageData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient()
    private var token: String?
    private var matchId: String?

    func configure(matchId: String, token: String) {
        self.matchId = matchId
        self.token = token
    }

    func fetchMessages() {
        guard let token = token, let matchId = matchId else { return }
        isLoading = true

        Task {
            do {
                let response = try await apiClient.getMessages(matchId: matchId, token: token)
                self.messages = response.messages.map { $0.toMessageData() }
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    /// チャット画面を開いたとき既読APIを呼ぶ
    func markAsRead() {
        guard let token = token, let matchId = matchId else { return }
        Task {
            try? await apiClient.markMessagesAsRead(matchId: matchId, token: token)
        }
    }

    /// 相手が既読にしたとき、自分の送信メッセージを既読に更新
    func handleMessagesRead(matchId: String) {
        guard matchId == self.matchId else { return }
        messages = messages.map { msg in
            guard !msg.read else { return msg }
            return MessageData(
                id: msg.id, matchId: msg.matchId, senderId: msg.senderId,
                content: msg.content, read: true, createdAt: msg.createdAt
            )
        }
    }

    /// Socket.IO から受信したメッセージを追加
    func receiveMessage(_ message: MessageData) {
        guard message.matchId == matchId else { return }
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
        }
    }
}

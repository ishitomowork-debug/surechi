//
//  ContentView.swift
//  スレチ
//
//  Created by Tomoya Ishida on 2026/02/25.
//

import SwiftUI
import CoreLocation
import PhotosUI
import UniformTypeIdentifiers
import MapKit
import StoreKit

// MARK: - Auth View

struct AuthView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var socketService = SocketService()
    @StateObject private var locationService = LocationService()
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var showPassword = false
    @State private var showForgotPassword = false
    @State private var agreedToTerms = false
    @AppStorage("ageVerified") private var ageVerified = false

    var body: some View {
        Group {
        if !ageVerified {
            AgeGateView(isVerified: $ageVerified)
        } else if authVM.isLoggedIn {
            MainTabView()
                .environmentObject(authVM)
                .environmentObject(socketService)
                .environmentObject(locationService)
                .onAppear {
                    if let token = authVM.token {
                        socketService.connect(token: token)
                        locationService.startUpdating()
                        PushNotificationService.shared.requestPermissionAndRegister()
                    }
                }
        } else {
            NavigationStack {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("スレチ")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("すれ違えば出会える")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 30)

                    VStack(spacing: 15) {
                        if isSignUp {
                            TextField("名前", text: $name)
                                .textFieldStyle(.roundedBorder)
                            DatePicker(
                                "生年月日",
                                selection: $birthDate,
                                in: Calendar.current.date(byAdding: .year, value: -80, to: Date())!...Calendar.current.date(byAdding: .year, value: -18, to: Date())!,
                                displayedComponents: .date
                            )
                        }

                        TextField("メール", text: $email)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            #endif
                            .accessibilityIdentifier("emailField")

                        HStack {
                            Group {
                                if showPassword {
                                    TextField("パスワード", text: $password)
                                } else {
                                    SecureField("パスワード", text: $password)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("passwordField")
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    if isSignUp {
                        HStack(alignment: .top, spacing: 10) {
                            Toggle("", isOn: $agreedToTerms)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("以下に同意して登録します")
                                    .font(.caption)
                                HStack(spacing: 4) {
                                    Link("利用規約", destination: URL(string: "https://realmatching.app/terms")!)
                                        .font(.caption).foregroundColor(.blue)
                                    Text("・")
                                        .font(.caption)
                                    Link("プライバシーポリシー", destination: URL(string: "https://realmatching.app/privacy")!)
                                        .font(.caption).foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    Button(action: submitForm) {
                        HStack {
                            if authVM.isLoading { ProgressView().tint(.white) }
                            Text(isSignUp ? "登録" : "ログイン").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(authVM.isLoading || (isSignUp && !agreedToTerms))
                    .accessibilityIdentifier("submitButton")

                    HStack {
                        Text(isSignUp ? "既にアカウントをお持ちですか？" : "アカウントをお持ちではありませんか？")
                            .font(.caption)
                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "ログイン" : "登録")
                                .font(.caption).fontWeight(.bold).foregroundColor(.blue)
                        }
                        .accessibilityIdentifier("toggleModeButton")
                    }

                    if !isSignUp {
                        Button(action: { showForgotPassword = true }) {
                            Text("パスワードをお忘れですか？")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }
        }
        .onChange(of: authVM.isLoggedIn) { _, isLoggedIn in
            if !isLoggedIn { isSignUp = false }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    private func submitForm() {
        if isSignUp {
            authVM.register(email: email, password: password, name: name, birthDate: birthDate)
        } else {
            authVM.login(email: email, password: password)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var socketService: SocketService
    @EnvironmentObject var locationService: LocationService
    @StateObject private var matchVM = MatchViewModel()
    @State private var showMatchBanner = false
    @State private var encounterMatchId: String? = nil
    @State private var showEncounterChat = false
    @AppStorage("totalMatchCount") private var totalMatchCount = 0
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DiscoveryView()
                    .tabItem { Label("ライク", systemImage: "heart.fill") }

                LikedMeView()
                    .tabItem { Label("いいねした", systemImage: "star.fill") }

                MatchesListView()
                    .environmentObject(matchVM)
                    .tabItem { Label("マッチング", systemImage: "checkmark.circle.fill") }
                    .badge(matchVM.totalUnreadCount > 0 ? matchVM.totalUnreadCount : 0)

                NearbyMapView()
                    .tabItem { Label("マップ", systemImage: "map.fill") }

                ProfileView()
                    .tabItem { Label("プロフィール", systemImage: "person.fill") }
            }

            // オフラインバナー
            if !NetworkMonitor.shared.isConnected {
                OfflineBanner()
                    .zIndex(4)
            }

            // メール未確認バナー
            if authVM.currentUser?.emailVerified == false {
                EmailVerificationBanner()
                    .zIndex(3)
            }

            // マッチング通知バナー
            if showMatchBanner, let notification = socketService.newMatchNotification {
                MatchBanner(notification: notification)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }

            // すれ違いカード
            if let encounter = socketService.pendingEncounter {
                EncounterCardView(user: encounter) { liked in
                    socketService.sendEncounterSwipe(targetUserId: encounter.id, liked: liked)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .onAppear {
            if let token = authVM.token {
                matchVM.configure(token: token)
                matchVM.fetchMatches()
                PushNotificationService.shared.requestPermissionAndRegister()
                // LocationServiceにSocketServiceを連携
                locationService.socketService = socketService
            }
        }
        .onChange(of: socketService.newMatchNotification) { _, _ in
            withAnimation { showMatchBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation { showMatchBanner = false }
            }
            matchVM.fetchMatches()
            totalMatchCount += 1
            if totalMatchCount == 3 || totalMatchCount == 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { requestReview() }
            }
        }
        .onChange(of: socketService.encounterMatch) { _, match in
            guard let match else { return }
            encounterMatchId = match.matchId
            matchVM.fetchMatches()
            withAnimation { showEncounterChat = true }
        }
        .sheet(isPresented: $showEncounterChat) {
            if let matchId = encounterMatchId,
               let match = socketService.encounterMatch {
                let matchedUser = match.user.toMatchedUser(matchId: matchId)
                NavigationStack {
                    ChatView(match: matchedUser)
                        .environmentObject(authVM)
                        .environmentObject(socketService)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("閉じる") {
                                    showEncounterChat = false
                                    socketService.encounterMatch = nil
                                }
                            }
                        }
                }
            }
        }
        .onDisappear {
            socketService.disconnect()
        }
    }
}

// MARK: - Match Banner

struct MatchBanner: View {
    let notification: MatchNotification

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .foregroundColor(.pink)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("マッチング！").font(.headline)
                Text("\(notification.matchedUser.name)さんとマッチしました")
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Nearby Map View

struct NearbyMapView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var locationService: LocationService
    @State private var mapUsers: [MapUser] = []
    @State private var center: MapCenter? = nil
    @State private var selectedUser: MapUser? = nil
    @State private var isLoading = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    private let apiClient = APIClient()

    var body: some View {
        NavigationStack {
            ZStack {
                if let center {
                    Map(position: $cameraPosition, interactionModes: .all) {
                        // 自分の位置（正確）
                        UserAnnotation()

                        // 1km 半径円
                        MapCircle(
                            center: CLLocationCoordinate2D(
                                latitude: center.latitude,
                                longitude: center.longitude
                            ),
                            radius: 1000
                        )
                        .foregroundStyle(.blue.opacity(0.08))
                        .stroke(.blue.opacity(0.3), lineWidth: 1.5)

                        // 近くのユーザーピン（ファジー座標）
                        ForEach(mapUsers) { user in
                            Annotation(user.name, coordinate: CLLocationCoordinate2D(
                                latitude: user.latitude,
                                longitude: user.longitude
                            )) {
                                Button {
                                    selectedUser = user
                                } label: {
                                    VStack(spacing: 2) {
                                        AvatarView(avatarString: user.avatar, size: 36)
                                            .overlay(Circle().stroke(.white, lineWidth: 2))
                                            .shadow(radius: 3)
                                        Text(user.name)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 4)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                } else {
                    VStack(spacing: 16) {
                        if isLoading {
                            ProgressView("ユーザーを検索中...")
                        } else {
                            Image(systemName: "location.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("位置情報を取得できませんでした")
                                .foregroundColor(.gray)
                            Button("再試行") { loadUsers() }
                                .buttonStyle(.bordered)
                        }
                    }
                }

                // ユーザーカード（ピンタップ時）
                if let user = selectedUser {
                    VStack {
                        Spacer()
                        MapUserCard(user: user) {
                            selectedUser = nil
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("近くにいる人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { loadUsers() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear { loadUsers() }
        }
    }

    private func loadUsers() {
        guard let token = authVM.token else { return }
        isLoading = true
        Task {
            do {
                let response = try await apiClient.getNearbyUsersForMap(token: token)
                await MainActor.run {
                    mapUsers = response.users
                    center = response.center
                    cameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: response.center.latitude,
                            longitude: response.center.longitude
                        ),
                        latitudinalMeters: 2200,
                        longitudinalMeters: 2200
                    ))
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct MapUserCard: View {
    let user: MapUser
    let onDismiss: () -> Void
    @EnvironmentObject var authVM: AuthViewModel
    @State private var likeResult: String? = nil
    private let apiClient = APIClient()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                AvatarView(avatarString: user.avatar, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(user.name), \(user.age)")
                        .font(.title3).fontWeight(.semibold)
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio).font(.caption).foregroundColor(.gray).lineLimit(2)
                    }
                    Text("📍 約1km以内").font(.caption2).foregroundColor(.orange)
                }
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray).font(.title3)
                }
            }

            if let result = likeResult {
                Text(result).font(.caption).foregroundColor(.green)
            } else {
                HStack(spacing: 12) {
                    Button {
                        onDismiss()
                    } label: {
                        Label("スキップ", systemImage: "xmark")
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color(.systemGray5)).cornerRadius(10)
                            .foregroundColor(.primary)
                    }
                    Button {
                        sendLike()
                    } label: {
                        Label("いいね！", systemImage: "heart.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.pink).cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 8)
    }

    private func sendLike() {
        guard let token = authVM.token else { return }
        Task {
            do {
                _ = try await apiClient.likeUser(targetUserId: user.id, token: token)
                await MainActor.run { likeResult = "いいね！しました ❤️" }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { onDismiss() }
            } catch {
                await MainActor.run { likeResult = "エラーが発生しました" }
            }
        }
    }
}

// MARK: - Encounter Card View

struct EncounterCardView: View {
    let user: EncounterUser
    let onSwipe: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                // ヘッダー
                HStack {
                    Image(systemName: "figure.walk.motion")
                        .foregroundColor(.orange)
                    Text("すれ違い！")
                        .font(.headline).foregroundColor(.orange)
                    Spacer()
                    Button { onSwipe(false) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray).font(.title3)
                    }
                }

                // ユーザー情報
                HStack(spacing: 16) {
                    AvatarView(avatarString: user.avatar, size: 70)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(user.name), \(user.age)")
                            .font(.title3).fontWeight(.semibold)
                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio).font(.caption).foregroundColor(.gray).lineLimit(2)
                        }
                        Text("近くにいます 📍").font(.caption2).foregroundColor(.orange)
                    }
                    Spacer()
                }

                // ボタン
                HStack(spacing: 16) {
                    Button {
                        withAnimation { onSwipe(false) }
                    } label: {
                        Label("スキップ", systemImage: "xmark")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(.systemGray5)).cornerRadius(10)
                            .foregroundColor(.primary)
                    }

                    Button {
                        withAnimation { onSwipe(true) }
                    } label: {
                        Label("いいね！", systemImage: "heart.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.pink).cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3).ignoresSafeArea())
    }
}

// MARK: - Discovery View

struct DiscoveryView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var viewModel = DiscoveryViewModel()
    @StateObject private var locationService = LocationService()
    @State private var showFilterSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if let locationErr = locationService.locationError {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 40)).foregroundColor(.orange)
                            Text(locationErr).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                            Button("設定を開く") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }.buttonStyle(.borderedProminent)
                        }
                        .padding()
                        Spacer()
                    } else if viewModel.isLoading {
                        Spacer()
                        ProgressView("近くのユーザーを検索中...")
                        Spacer()
                    } else if let error = viewModel.errorMessage {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40)).foregroundColor(.orange)
                            Text(error).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                            Button("再試行") {
                                if let location = locationService.currentLocation, let token = authVM.token {
                                    viewModel.updateLocation(location, token: token)
                                } else {
                                    locationService.startUpdating()
                                }
                            }.buttonStyle(.bordered)
                        }
                        .padding()
                        Spacer()
                    } else if viewModel.nearbyUsers.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 50)).foregroundColor(.gray)
                            Text("近くにユーザーがいません").font(.headline)
                            Text("移動してみると新しい出会いがあるかも")
                                .font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ZStack {
                            if viewModel.nearbyUsers.count > 1 {
                                UserCardView(
                                    user: viewModel.nearbyUsers[1],
                                    onLike: {},
                                    onDislike: {}
                                )
                                .scaleEffect(0.95)
                                .offset(y: 12)
                                .allowsHitTesting(false)
                            }
                            if let topUser = viewModel.nearbyUsers.first {
                                UserCardView(
                                    user: topUser,
                                    onLike: { viewModel.likeUser(topUser.id) },
                                    onDislike: { viewModel.dislikeUser(topUser.id) },
                                    onSuperLike: { viewModel.superlikeUser(topUser.id) },
                                    onBlock: { viewModel.blockUser(topUser.id) },
                                    onReport: { reason in viewModel.reportUser(topUser.id, reason: reason) }
                                )
                                .id(topUser.id)
                            }
                        }
                        .padding()
                    }
                }
            }
            .refreshable {
                if let location = locationService.currentLocation, let token = authVM.token {
                    viewModel.updateLocation(location, token: token)
                } else {
                    locationService.startUpdating()
                }
            }
            .navigationTitle("ライク")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { viewModel.undoDislike() } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .disabled(!viewModel.canUndo)
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill").foregroundColor(.pink).font(.caption)
                        Text("\(viewModel.likesRemaining)").font(.caption).fontWeight(.bold)
                        Text("残り").font(.caption2).foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showFilterSheet = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .alert("いいね上限に達しました", isPresented: $viewModel.limitReached) {
                Button("OK") { viewModel.limitReached = false }
            } message: {
                Text("1日のいいね上限（20件）に達しました。明日またお試しください。")
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(viewModel: viewModel)
            }
            .onAppear {
                if let token = authVM.token {
                    viewModel.configure(token: token)
                    if let existing = locationService.currentLocation {
                        // 既に位置情報がある場合はすぐに送信してフェッチ
                        viewModel.updateLocation(existing, token: token)
                    } else {
                        locationService.startUpdating()
                    }
                }
            }
            .onChange(of: locationService.currentLocation) { _, newLocation in
                if let location = newLocation, let token = authVM.token {
                    viewModel.updateLocation(location, token: token)
                }
            }
        }
    }
}

// MARK: - User Card View

struct UserCardView: View {
    let user: NearbyUser
    let onLike: () -> Void
    let onDislike: () -> Void
    var onSuperLike: (() -> Void)? = nil
    var onBlock: (() -> Void)? = nil
    var onReport: ((String) -> Void)? = nil

    @State private var dragOffset = CGSize.zero
    @State private var showReportSheet = false
    private let swipeThreshold: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                // 背景・画像
                if let avatarStr = user.avatar,
                   let data = Data(base64Encoded: avatarStr),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 360)
                        .clipped()
                } else {
                    Color.gray.opacity(0.3)
                    Image(systemName: "person.fill")
                        .font(.system(size: 60)).foregroundColor(.gray)
                }
                // LIKE / NOPE overlay
                HStack {
                    Text("LIKE")
                        .font(.title).fontWeight(.heavy)
                        .foregroundColor(.green)
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.green, lineWidth: 3))
                        .rotationEffect(.degrees(-20))
                        .opacity(min(1, max(0, Double(dragOffset.width / swipeThreshold))))
                    Spacer()
                    Text("NOPE")
                        .font(.title).fontWeight(.heavy)
                        .foregroundColor(.red)
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 3))
                        .rotationEffect(.degrees(20))
                        .opacity(min(1, max(0, Double(-dragOffset.width / swipeThreshold))))
                }
                .padding(.top, 40)
                .padding(.horizontal, 20)

                // スーパーライクされたバッジ
                if user.superlikedMe {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Label("スーパーいいね!", systemImage: "star.fill")
                                .font(.caption).fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.blue.opacity(0.85))
                                .cornerRadius(20)
                                .padding(12)
                        }
                    }
                }
            }
            .frame(height: 360)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(user.name), \(user.age)").font(.headline)
                    if let status = onlineStatus(user.lastActiveAt) {
                        HStack(spacing: 3) {
                            Circle().fill(status.color).frame(width: 8, height: 8)
                            Text(status.label).font(.caption2).foregroundColor(status.color)
                        }
                    }
                    Spacer()
                    if user.distance > 0 {
                        Label(formatDistance(user.distance), systemImage: "location.fill")
                            .font(.caption).foregroundColor(.blue)
                    }
                }
                if !user.bio.isEmpty {
                    Text(user.bio).font(.caption).foregroundColor(.gray).lineLimit(2)
                }
                if !user.interests.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(user.interests, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .padding()

            HStack(spacing: 16) {
                Button(action: { animateSwipe(direction: -1) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40)).foregroundColor(.red)
                }
                Spacer()
                if let onSuperLike = onSuperLike {
                    Button(action: onSuperLike) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 36)).foregroundColor(.blue)
                    }
                    Spacer()
                }
                Button(action: { animateSwipe(direction: 1) }) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 40)).foregroundColor(.pink)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 4)
        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in dragOffset = value.translation }
                .onEnded { value in
                    if value.translation.width > swipeThreshold {
                        animateSwipe(direction: 1)
                    } else if value.translation.width < -swipeThreshold {
                        animateSwipe(direction: -1)
                    } else {
                        withAnimation(.spring()) { dragOffset = .zero }
                    }
                }
        )
        .contextMenu {
            if let onBlock = onBlock {
                Button(role: .destructive) { onBlock() } label: {
                    Label("ブロック", systemImage: "hand.raised.fill")
                }
            }
            if onReport != nil {
                Button(role: .destructive) { showReportSheet = true } label: {
                    Label("報告する", systemImage: "exclamationmark.bubble.fill")
                }
            }
        }
        .confirmationDialog("報告する理由を選択してください", isPresented: $showReportSheet, titleVisibility: .visible) {
            Button("スパム") { onReport?("スパム") }
            Button("不適切なコンテンツ") { onReport?("不適切なコンテンツ") }
            Button("ハラスメント") { onReport?("ハラスメント") }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func animateSwipe(direction: CGFloat) {
        let generator = UIImpactFeedbackGenerator(style: direction > 0 ? .medium : .rigid)
        generator.impactOccurred()
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: direction * 600, height: 50)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if direction > 0 { onLike() } else { onDislike() }
        }
    }
}

// MARK: - Matches List View

struct MatchesListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var socketService: SocketService
    @EnvironmentObject var viewModel: MatchViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
                } else if viewModel.matches.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 50)).foregroundColor(.gray)
                        Text("まだマッチングがありません").font(.headline)
                        Text("近くのユーザーにいいねしてみよう！")
                            .font(.caption).foregroundColor(.gray)
                    }
                } else {
                    List(viewModel.matches) { match in
                        NavigationLink(destination:
                            ChatView(match: match)
                                .environmentObject(authVM)
                                .environmentObject(socketService)
                        ) {
                            HStack(spacing: 12) {
                                AvatarView(avatarString: match.matchedUser.avatar, size: 50)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("\(match.matchedUser.name), \(match.matchedUser.age)")
                                            .font(.headline)
                                        Spacer()
                                        if let last = match.lastMessage {
                                            Text(relativeTime(last.createdAt))
                                                .font(.caption2).foregroundColor(.gray)
                                        }
                                    }
                                    if let last = match.lastMessage {
                                        let isMe = last.senderId == authVM.currentUser?.id
                                        Text((isMe ? "あなた: " : "") + last.content)
                                            .font(.caption).foregroundColor(.gray).lineLimit(1)
                                    } else {
                                        Text("マッチしました！メッセージを送ってみよう")
                                            .font(.caption).foregroundColor(.blue).lineLimit(1)
                                    }
                                    if let expiry = match.expiresAt, let daysLeft = daysRemaining(expiry), daysLeft <= 3 {
                                        Label("\(daysLeft)日で期限切れ", systemImage: "clock")
                                            .font(.caption2).foregroundColor(.orange)
                                    }
                                }
                                if match.unreadCount > 0 {
                                    Text("\(match.unreadCount)")
                                        .font(.caption2).fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.blockUser(userId: match.matchedUser.id, matchId: match.id)
                            } label: {
                                Label("ブロック", systemImage: "hand.raised.fill")
                            }
                        }
                    }
                    .refreshable { viewModel.fetchMatches() }
                }
            }
            .navigationTitle("マッチング")
            .onAppear { viewModel.fetchMatches() }
        }
    }
}

// MARK: - Chat View

struct ChatView: View {
    let match: MatchedUser
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var socketService: SocketService
    @StateObject private var viewModel = ChatViewModel()
    @State private var newMessage = ""
    @State private var showReportSheet = false
    @State private var showBlockConfirm = false
    @State private var showProfile = false
    @State private var showCoinShop = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isMe: message.senderId == authVM.currentUser?.id
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // コイン残高バー
            HStack(spacing: 6) {
                Image(systemName: "bitcoinsign.circle.fill").foregroundColor(.yellow).font(.caption)
                Text("\(socketService.currentCoins)コイン残高").font(.caption2).foregroundColor(.gray)
                Text("(1メッセージ = 1コイン = ¥10)").font(.caption2).foregroundColor(.gray)
                Spacer()
                Button("購入") { showCoinShop = true }
                    .font(.caption).foregroundColor(.blue)
            }
            .padding(.horizontal).padding(.top, 4)

            HStack(spacing: 12) {
                TextField("メッセージを入力...", text: $newMessage)
                    .textFieldStyle(.roundedBorder)

                Button {
                    let text = newMessage.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    socketService.sendMessage(matchId: match.id, content: text)
                    newMessage = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(
                            newMessage.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue
                        )
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationTitle("\(match.matchedUser.name), \(match.matchedUser.age)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle")
                    }
                    Menu {
                        Button(role: .destructive) { showReportSheet = true } label: {
                            Label("報告する", systemImage: "exclamationmark.bubble")
                        }
                        Button(role: .destructive) { showBlockConfirm = true } label: {
                            Label("ブロック", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            MatchedUserProfileView(user: match.matchedUser)
        }
        .sheet(isPresented: $showCoinShop) {
            CoinShopView().environmentObject(authVM)
        }
        .alert("コインが不足しています", isPresented: $socketService.coinsInsufficient) {
            Button("購入する") {
                socketService.coinsInsufficient = false
                showCoinShop = true
            }
            Button("キャンセル", role: .cancel) { socketService.coinsInsufficient = false }
        } message: {
            Text("メッセージを送るには1コイン（¥10相当）が必要です。")
        }
        .onAppear {
            socketService.currentCoins = authVM.currentUser?.coins ?? 0
        }
        .confirmationDialog("報告する理由を選択してください", isPresented: $showReportSheet, titleVisibility: .visible) {
            Button("スパム") { reportUser(reason: "スパム") }
            Button("不適切なコンテンツ") { reportUser(reason: "不適切なコンテンツ") }
            Button("ハラスメント") { reportUser(reason: "ハラスメント") }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("ブロックしますか？", isPresented: $showBlockConfirm) {
            Button("ブロック", role: .destructive) { blockUser() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(match.matchedUser.name)さんをブロックすると、マッチングが解除されます")
        }
        .onAppear {
            if let token = authVM.token {
                viewModel.configure(matchId: match.id, token: token)
                viewModel.fetchMessages()
                viewModel.markAsRead()
            }
            socketService.onNewMessage = { viewModel.receiveMessage($0) }
            socketService.onMessageSent = { viewModel.receiveMessage($0) }
            socketService.onMessagesRead = { viewModel.handleMessagesRead(matchId: $0) }
        }
        .onDisappear {
            socketService.onNewMessage = nil
            socketService.onMessageSent = nil
            socketService.onMessagesRead = nil
        }
    }

    private func reportUser(reason: String) {
        guard let token = authVM.token else { return }
        Task { try? await APIClient().reportUser(userId: match.matchedUser.id, reason: reason, token: token) }
    }

    private func blockUser() {
        guard let token = authVM.token else { return }
        Task { try? await APIClient().blockUser(userId: match.matchedUser.id, token: token) }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: MessageData
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 60) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMe ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(isMe ? .white : .primary)
                    .cornerRadius(16)
                HStack(spacing: 4) {
                    if !message.createdAt.isEmpty {
                        Text(formatTimestamp(message.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if isMe && message.read {
                        Text("既読")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if !isMe { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isEditingProfile = false
    @State private var showCoinShop = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    #if DEBUG
    @State private var seedMessage = ""
    @State private var showSeedResult = false
    @State private var isSeedLoading = false
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AvatarView(avatarString: authVM.currentUser?.avatar, size: 100)
                    .id(authVM.currentUser?.avatar ?? "none")

                if let user = authVM.currentUser {
                    VStack(spacing: 6) {
                        Text("\(user.name), \(user.age)")
                            .font(.title2).fontWeight(.semibold)
                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio).font(.body).foregroundColor(.gray).multilineTextAlignment(.center)
                        }
                        Text(user.email).font(.caption).foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                } else {
                    ProgressView()
                }

                // コイン残高
                HStack(spacing: 8) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundColor(.yellow)
                    Text("\(authVM.currentUser?.coins ?? 0) コイン")
                        .fontWeight(.semibold)
                    Spacer()
                    Button("コインを購入") { showCoinShop = true }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                Button(action: { isEditingProfile = true }) {
                    Text("プロフィール編集")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
                .padding(.horizontal)

                Spacer()

                Button(action: { authVM.logout() }) {
                    Text("ログアウト")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.red.opacity(0.7)).foregroundColor(.white).cornerRadius(8)
                }
                .padding(.horizontal)

                Button(action: { showDeleteAccountConfirm = true }) {
                    Text("アカウントを削除")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.clear)
                        .foregroundColor(.red)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                }
                .padding(.horizontal)
                .disabled(isDeletingAccount)
                .confirmationDialog("アカウントを削除しますか？", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
                    Button("削除する", role: .destructive) {
                        isDeletingAccount = true
                        Task { @MainActor in
                            _ = await authVM.deleteAccount()
                            isDeletingAccount = false
                        }
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("この操作は取り消せません。全てのデータが削除されます。")
                }

                #if DEBUG
                Button(action: {
                    isSeedLoading = true
                    Task { @MainActor in
                        seedMessage = await authVM.seedNearbyUsers()
                        isSeedLoading = false
                        showSeedResult = true
                    }
                }) {
                    HStack {
                        if isSeedLoading { ProgressView().tint(.white) }
                        Text("🧪 テストユーザーを追加")
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.orange.opacity(0.8)).foregroundColor(.white).cornerRadius(8)
                }
                .disabled(isSeedLoading)
                .padding(.horizontal)
                .alert("Dev Seed", isPresented: $showSeedResult) {
                    Button("OK") {}
                } message: {
                    Text(seedMessage)
                }

                Button(action: {
                    isSeedLoading = true
                    Task { @MainActor in
                        seedMessage = await authVM.simulateEncounter()
                        isSeedLoading = false
                        showSeedResult = true
                    }
                }) {
                    HStack {
                        if isSeedLoading { ProgressView().tint(.white) }
                        Text("🚶 すれ違いをシミュレート")
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.purple.opacity(0.8)).foregroundColor(.white).cornerRadius(8)
                }
                .disabled(isSeedLoading)
                .padding(.horizontal)
                #endif
            }
            .padding(.top, 30)
            .navigationTitle("プロフィール")
            .sheet(isPresented: $isEditingProfile) {
                ProfileEditView().environmentObject(authVM)
            }
            .sheet(isPresented: $showCoinShop) {
                CoinShopView().environmentObject(authVM)
            }
            .onAppear {
                if authVM.currentUser == nil { authVM.loadProfile() }
            }
        }
    }
}

// MARK: - Profile Edit View

struct ProfileEditView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var age: Int = 20
    @State private var bio: String = ""
    @State private var interests: [String] = []
    @State private var newInterest: String = ""
    @State private var currentAvatarString: String? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isImageLoading = false
    @State private var showErrorAlert = false
    @State private var errorText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("プロフィール画像") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack {
                            Spacer()
                            if isImageLoading {
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            } else if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                AvatarView(avatarString: currentAvatarString, size: 100)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "camera.fill")
                                            .padding(6)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                    }
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                    .disabled(isImageLoading)
                }
                Section("基本情報") {
                    TextField("名前", text: $name)
                    Stepper("年齢: \(age)", value: $age, in: 18...80)
                }
                Section("自己紹介") {
                    TextEditor(text: $bio).frame(minHeight: 80)
                    // テンプレ候補
                    if bio.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["旅行が好き", "映画鑑賞", "料理得意", "音楽好き", "アウトドア派", "インドア派"], id: \.self) { tmpl in
                                    Button(tmpl) { bio = tmpl }
                                        .font(.caption).buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                Section("趣味・興味") {
                    // 追加済みタグ
                    if !interests.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(interests, id: \.self) { tag in
                                HStack(spacing: 2) {
                                    Text(tag).font(.caption)
                                    Button { interests.removeAll { $0 == tag } } label: {
                                        Image(systemName: "xmark").font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                        }
                    }
                    // 候補タグ
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["旅行", "映画", "音楽", "料理", "スポーツ", "読書", "ゲーム", "アート", "カフェ", "アニメ"], id: \.self) { tag in
                                if !interests.contains(tag) {
                                    Button("+ \(tag)") { interests.append(tag) }
                                        .font(.caption).buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    // カスタム追加
                    HStack {
                        TextField("カスタムタグを追加", text: $newInterest)
                            .textFieldStyle(.roundedBorder)
                        Button("追加") {
                            let t = newInterest.trimmingCharacters(in: .whitespaces)
                            if !t.isEmpty && !interests.contains(t) {
                                interests.append(t)
                                newInterest = ""
                            }
                        }
                        .disabled(newInterest.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(authVM.isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { @MainActor in
                            var avatarBase64: String? = nil
                            if let data = selectedImageData,
                               let uiImage = UIImage(data: data) {
                                let resized = uiImage.resized(to: 300)
                                avatarBase64 = resized.jpegData(compressionQuality: 0.7)?.base64EncodedString()
                            }
                            if let error = await authVM.updateProfile(name: name, age: age, bio: bio, interests: interests, avatar: avatarBase64) {
                                errorText = error
                                showErrorAlert = true
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.isEmpty || authVM.isLoading || isImageLoading)
                }
            }
            .onAppear {
                if let user = authVM.currentUser {
                    name = user.name
                    age = user.age
                    bio = user.bio ?? ""
                    interests = user.interests ?? []
                    currentAvatarString = user.avatar
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task { @MainActor in
                    guard let newItem else { return }
                    isImageLoading = true
                    do {
                        if let picked = try await newItem.loadTransferable(type: PhotoPickerData.self) {
                            selectedImageData = picked.data
                        } else {
                            errorText = "この画像形式には対応していません"
                            showErrorAlert = true
                        }
                    } catch {
                        errorText = "画像の読み込みに失敗しました: \(error.localizedDescription)"
                        showErrorAlert = true
                    }
                    isImageLoading = false
                }
            }
            .overlay(alignment: .bottom) {
                if authVM.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("保存中...")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
                    .padding(.bottom, 16)
                }
            }
            .alert("保存エラー", isPresented: $showErrorAlert) {
                Button("OK") { showErrorAlert = false }
            } message: {
                Text(errorText)
            }
        }
    }
}

// MARK: - Helpers

private func formatDistance(_ meters: Int) -> String {
    meters >= 1000 ? String(format: "%.1fkm", Double(meters) / 1000) : "\(meters)m"
}

/// expiresAt (ISO8601) からの残り日数。過去の場合は 0 を返す
private func daysRemaining(_ isoString: String) -> Int? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: isoString)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: isoString)
    }
    guard let date else { return nil }
    let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    return max(0, days)
}

// MARK: - Flow Layout (タグ折り返しレイアウト)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Liked Me View

struct LikedMeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var users: [LikedMeUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let apiClient = APIClient()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("読み込み中...")
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Text(error).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                        Button("再試行") { fetchLikedMe() }.buttonStyle(.bordered)
                    }.padding()
                } else if users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash").font(.system(size: 50)).foregroundColor(.gray)
                        Text("まだいいねがありません").font(.headline)
                        Text("近くのユーザーにいいねしてもらいましょう").font(.caption).foregroundColor(.gray)
                    }
                } else {
                    List(users) { user in
                        HStack(spacing: 12) {
                            ZStack(alignment: .topTrailing) {
                                AvatarView(avatarString: user.avatar, size: 55)
                                if user.isSuperLike {
                                    Image(systemName: "star.fill")
                                        .font(.caption2).foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .offset(x: 4, y: -4)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("\(user.name), \(user.age)").font(.headline)
                                    if user.isSuperLike {
                                        Text("スーパーいいね").font(.caption2).foregroundColor(.blue)
                                    }
                                }
                                if !user.bio.isEmpty {
                                    Text(user.bio).font(.caption).foregroundColor(.gray).lineLimit(1)
                                }
                                if !user.interests.isEmpty {
                                    Text(user.interests.prefix(3).joined(separator: " · "))
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(relativeTime(user.likedAt)).font(.caption2).foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .refreshable { fetchLikedMe() }
                }
            }
            .navigationTitle("いいねした")
            .onAppear { fetchLikedMe() }
        }
    }

    private func fetchLikedMe() {
        guard let token = authVM.token else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                users = try await apiClient.getLikedMe(token: token)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var message: String? = nil
    @State private var isSuccess = false
    private let apiClient = APIClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("パスワードをリセット")
                    .font(.title2).fontWeight(.bold)
                Text("登録したメールアドレスを入力してください。リセット用のリンクをお送りします。")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("メールアドレス", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal)

                if let message = message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(isSuccess ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: sendReset) {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        Text("送信する")
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
                .padding(.horizontal)
                .disabled(isLoading || email.isEmpty)

                Spacer()
            }
            .padding(.top, 30)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func sendReset() {
        isLoading = true
        message = nil
        Task { @MainActor in
            do {
                try await apiClient.forgotPassword(email: email)
                isSuccess = true
                message = "メールを送信しました。受信ボックスをご確認ください。"
            } catch {
                isSuccess = false
                message = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            Text("インターネット接続がありません")
                .font(.caption).fontWeight(.medium).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray)
    }
}

// MARK: - Age Gate View

struct AgeGateView: View {
    @Binding var isVerified: Bool

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            VStack(spacing: 12) {
                Text("年齢確認")
                    .font(.largeTitle).fontWeight(.bold)
                Text("スレチは18歳以上の方を対象としています。\n続けるには年齢を確認してください。")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            VStack(spacing: 12) {
                Button(action: { isVerified = true }) {
                    Text("18歳以上です")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }
                Button(action: {
                    // 未成年はアプリを閉じる
                    exit(0)
                }) {
                    Text("18歳未満です")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color(.systemGray5)).foregroundColor(.primary).cornerRadius(10)
                }
            }
            .padding(.horizontal, 30)
            Spacer()
            Text("虚偽の申告は利用規約違反となります。")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Email Verification Banner

struct EmailVerificationBanner: View {
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack(spacing: 10) {
                Image(systemName: "envelope.badge")
                    .foregroundColor(.orange)
                Text("メールアドレスの確認をしてください")
                    .font(.caption).fontWeight(.medium)
                Spacer()
                Button(action: { withAnimation { isDismissed = true } }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemYellow).opacity(0.15))
            .overlay(Rectangle().frame(height: 1).foregroundColor(.orange.opacity(0.4)), alignment: .bottom)
        }
    }
}

private func formatTimestamp(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: isoString)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: isoString)
    }
    guard let date else { return "" }
    let display = DateFormatter()
    display.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "M/d HH:mm"
    return display.string(from: date)
}

// MARK: - Matched User Profile Sheet

struct MatchedUserProfileView: View {
    let user: MatchedUserInfo
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AvatarView(avatarString: user.avatar, size: 100)
                        .padding(.top, 24)

                    Text("\(user.name), \(user.age)")
                        .font(.title2).fontWeight(.bold)

                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    if let interests = user.interests, !interests.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(interests, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

/// ISO8601文字列を相対時刻（例: 3分前、2時間前）に変換
private func relativeTime(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: isoString)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: isoString)
    }
    guard let date else { return "" }
    let minutes = Int(-date.timeIntervalSinceNow / 60)
    if minutes < 1 { return "たった今" }
    if minutes < 60 { return "\(minutes)分前" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)時間前" }
    return "\(hours / 24)日前"
}

/// lastActiveAt (ISO8601) からオンライン状態を返す。5分以内→緑、60分以内→黄、それ以上→nil
private func onlineStatus(_ isoString: String?) -> (color: Color, label: String)? {
    guard let isoString else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: isoString)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: isoString)
    }
    guard let date else { return nil }
    let minutes = Int(-date.timeIntervalSinceNow / 60)
    if minutes < 5 { return (.green, "オンライン") }
    if minutes < 60 { return (.yellow, "\(minutes)分前") }
    return nil
}

// MARK: - Coin Shop View

struct CoinShopView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreManager()
    @State private var showResult = false
    @State private var resultMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 現在の残高
                HStack(spacing: 8) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.title2).foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("現在の残高").font(.caption).foregroundColor(.gray)
                        Text("\(authVM.currentUser?.coins ?? 0) コイン")
                            .font(.title3).fontWeight(.bold)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.yellow.opacity(0.1))

                Text("1コイン = メッセージ1通")
                    .font(.caption).foregroundColor(.gray)
                    .padding(.top, 8)

                if storeManager.products.isEmpty {
                    ProgressView("読み込み中...").padding()
                } else {
                    List(storeManager.products, id: \.id) { product in
                        let coins = StoreManager.coins(for: product.id)
                        Button {
                            guard let token = authVM.token else { return }
                            Task {
                                await storeManager.purchase(product, token: token)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName).font(.headline).foregroundColor(.primary)
                                    Text("\(coins)コイン = \(coins)通のメッセージ")
                                        .font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.title3).fontWeight(.bold).foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(storeManager.purchaseState == .purchasing)
                    }
                }

                if storeManager.purchaseState == .purchasing {
                    ProgressView("購入処理中...").padding()
                }
            }
            .navigationTitle("コインショップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("購入結果", isPresented: $showResult) {
                Button("OK") {}
            } message: {
                Text(resultMessage)
            }
            .onChange(of: storeManager.purchaseState) { _, state in
                switch state {
                case .success(let coins):
                    resultMessage = "\(coins)コインを購入しました！"
                    showResult = true
                    authVM.loadProfile()
                case .failed(let msg):
                    resultMessage = "購入に失敗しました: \(msg)"
                    showResult = true
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Photo Picker Transferable
// Data.self は public.data UTType しか受け付けず写真(public.jpeg/heic)で nil を返すため
// public.image を受け付けるカスタム Transferable を使用する
struct PhotoPickerData: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PhotoPickerData(data: data)
        }
    }
}

// MARK: - Avatar View

private let avatarImageCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 100
    return cache
}()

struct AvatarView: View {
    let avatarString: String?
    let size: CGFloat

    private var cachedImage: UIImage? {
        guard let str = avatarString else { return nil }
        let key = NSString(string: str)
        if let cached = avatarImageCache.object(forKey: key) { return cached }
        guard let data = Data(base64Encoded: str, options: .ignoreUnknownCharacters),
              let uiImage = UIImage(data: data) else { return nil }
        avatarImageCache.setObject(uiImage, forKey: key)
        return uiImage
    }

    var body: some View {
        Group {
            if let uiImage = cachedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.gray.opacity(0.3)
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Filter Sheet View

struct FilterSheetView: View {
    @ObservedObject var viewModel: DiscoveryViewModel
    @Environment(\.dismiss) var dismiss

    private let radiusOptions = [1000, 3000, 5000, 10000, 20000]

    var body: some View {
        NavigationStack {
            Form {
                Section("年齢範囲") {
                    HStack {
                        Text("最小: \(viewModel.filterMinAge)歳")
                        Spacer()
                        Slider(value: Binding(
                            get: { Double(viewModel.filterMinAge) },
                            set: { viewModel.filterMinAge = Int($0) }
                        ), in: 18...Double(viewModel.filterMaxAge), step: 1)
                    }
                    HStack {
                        Text("最大: \(viewModel.filterMaxAge)歳")
                        Spacer()
                        Slider(value: Binding(
                            get: { Double(viewModel.filterMaxAge) },
                            set: { viewModel.filterMaxAge = Int($0) }
                        ), in: Double(viewModel.filterMinAge)...80, step: 1)
                    }
                }
                Section("検索距離") {
                    Picker("距離", selection: $viewModel.filterRadius) {
                        ForEach(radiusOptions, id: \.self) { r in
                            Text(formatDistance(r)).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("フィルター設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        viewModel.fetchNearbyUsers()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - UIImage Resize

#if os(iOS)
extension UIImage {
    /// maxPixels を超えないようにリサイズ（scale=1.0 で実ピクセル数を保証）
    func resized(to maxPixels: CGFloat) -> UIImage {
        // size はポイント単位なのでピクセルに変換
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let ratio = min(maxPixels / pixelWidth, maxPixels / pixelHeight)
        if ratio >= 1 { return self }
        let newSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // scale=1 にして newSize をそのままピクセル数にする
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
#endif

#Preview {
    AuthView()
}

//
//  VerificationView.swift
//  スレチ
//
//  本人確認（身分証アップロード）画面
//

import SwiftUI
import PhotosUI
import UIKit

struct VerificationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var status: VerificationStatus? = nil
    @State private var isLoadingStatus = false
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    // 画像選択
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showImageSourceDialog = false
    @State private var showCamera = false

    private let apiClient = APIClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    if isLoadingStatus {
                        ProgressView("状態を確認中…")
                            .padding(.top, 40)
                    } else if let status {
                        statusSection(status)

                        if status.isUnsubmitted || status.isRejected {
                            uploadSection
                        }
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Button("再試行") { Task { await loadStatus() } }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("本人確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog("画像を選択", isPresented: $showImageSourceDialog, titleVisibility: .visible) {
                Button("カメラで撮影") { showCamera = true }
                Button("写真ライブラリから選択") { /* PhotosPicker is inline */ }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showCamera) {
                ImagePickerCamera(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadPickerImage(newItem) }
            }
            .task { await loadStatus() }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.rectangle.badge.xmark")
                .font(.system(size: 42))
                .foregroundColor(.blue)
                .padding(.top, 8)
            Text("安心してご利用いただくため、身分証による本人確認をお願いします。")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("本人確認が完了するまで、ライク機能はご利用いただけません。")
                .font(.caption)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func statusSection(_ status: VerificationStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: iconName(for: status))
                    .foregroundColor(color(for: status))
                    .font(.title3)
                Text(statusLabel(for: status))
                    .font(.headline)
                    .foregroundColor(color(for: status))
                Spacer()
            }

            Text(statusDescription(for: status))
                .font(.caption)
                .foregroundColor(.gray)

            if status.isRejected, let note = status.verificationNote, !note.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("却下理由")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
            }

            if status.isApproved, let verifiedAt = status.verifiedAt {
                Text("確認日: \(verifiedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color(for: status).opacity(0.08))
        .cornerRadius(12)
    }

    private var uploadSection: some View {
        VStack(spacing: 14) {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 36))
                            .foregroundColor(.gray)
                        Text("運転免許証・パスポート等の身分証")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            VStack(spacing: 10) {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label("写真ライブラリから選択", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                Button {
                    showCamera = true
                } label: {
                    Label("カメラで撮影", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "送信中…" : "送信する")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedImage == nil || isSubmitting ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(selectedImage == nil || isSubmitting)

            Text("※ 送信された画像は本人確認のためのみに使用され、承認後は安全に破棄されます。")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func iconName(for status: VerificationStatus) -> String {
        if status.isApproved { return "checkmark.seal.fill" }
        if status.isPending { return "clock.fill" }
        if status.isRejected { return "xmark.seal.fill" }
        return "exclamationmark.circle.fill"
    }

    private func color(for status: VerificationStatus) -> Color {
        if status.isApproved { return .green }
        if status.isPending { return .orange }
        if status.isRejected { return .red }
        return .blue
    }

    private func statusLabel(for status: VerificationStatus) -> String {
        if status.isApproved { return "本人確認済み" }
        if status.isPending { return "審査中です" }
        if status.isRejected { return "却下されました" }
        return "未提出"
    }

    private func statusDescription(for status: VerificationStatus) -> String {
        if status.isApproved { return "全ての機能をご利用いただけます。" }
        if status.isPending { return "管理者による確認をお待ちください。通常1〜2営業日以内に完了します。" }
        if status.isRejected { return "下記の理由により却下されました。再度身分証をアップロードしてください。" }
        return "身分証をアップロードして本人確認を完了してください。"
    }

    // MARK: - Actions

    private func loadStatus() async {
        guard let token = authVM.token else { return }
        await MainActor.run {
            isLoadingStatus = true
            errorMessage = nil
        }
        do {
            let result = try await apiClient.getVerificationStatus(token: token)
            await MainActor.run {
                self.status = result
                self.isLoadingStatus = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingStatus = false
            }
        }
    }

    private func loadPickerImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            await MainActor.run {
                self.selectedImage = uiImage
                self.errorMessage = nil
            }
        }
    }

    private func submit() async {
        guard let token = authVM.token, let image = selectedImage else { return }

        await MainActor.run {
            isSubmitting = true
            errorMessage = nil
            successMessage = nil
        }

        // JPEG 0.6 圧縮 → base64
        guard let base64 = compressToBase64(image: image, quality: 0.6) else {
            await MainActor.run {
                errorMessage = "画像の処理に失敗しました"
                isSubmitting = false
            }
            return
        }

        do {
            try await apiClient.submitVerification(idImageBase64: base64, token: token)
            await MainActor.run {
                selectedImage = nil
                selectedItem = nil
                successMessage = "送信しました。審査をお待ちください。"
                isSubmitting = false
            }
            await loadStatus()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }

    private func compressToBase64(image: UIImage, quality: CGFloat) -> String? {
        // 長辺を最大 1600px にリサイズして送信サイズを抑える
        let maxDim: CGFloat = 1600
        let resized: UIImage = {
            let size = image.size
            let longest = max(size.width, size.height)
            guard longest > maxDim else { return image }
            let scale = maxDim / longest
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }()

        guard let jpeg = resized.jpegData(compressionQuality: quality) else { return nil }
        return jpeg.base64EncodedString()
    }
}

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct ImagePickerCamera: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerCamera
        init(_ parent: ImagePickerCamera) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

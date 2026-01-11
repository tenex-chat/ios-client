//
// ImageLightboxView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Kingfisher
import Photos
import SwiftUI

// MARK: - ImageLightboxView

/// Fullscreen image viewer with pinch-to-zoom, double-tap zoom, pan, and download functionality
@MainActor
public struct ImageLightboxView: View {
    // MARK: Lifecycle

    public init(url: URL, isPresented: Binding<Bool>) {
        self.url = url
        _isPresented = isPresented
    }

    // MARK: Public

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .opacity(self.dismissOpacity)

                self.zoomableImage(geometry: geometry)
                    .offset(y: self.scale == 1.0 ? self.dragOffset.height : 0)
                    .gesture(self.dismissGesture)

                self.controlsOverlay
            }
            .onTapGesture {
                self.handleBackgroundTap()
            }
        }
        .ignoresSafeArea()
        #if os(iOS)
        .statusBarHidden(true)
        #endif
        .alert("Save Image", isPresented: $showSaveAlert) {
            Button("OK") {}
        } message: {
            Text(self.saveAlertMessage)
        }
    }

    // MARK: Private

    private let url: URL

    @Binding private var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var isSaving = false

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 4.0

    private var dismissOpacity: Double {
        if self.scale == 1.0 {
            let progress = min(abs(self.dragOffset.height) / 300.0, 0.5)
            return 1.0 - Double(progress)
        }
        return 1.0
    }

    private func handleBackgroundTap() {
        // Tap outside to close (only when not zoomed)
        if self.scale == 1.0 {
            self.dismiss()
        }
    }

    private func zoomableImage(geometry: GeometryProxy) -> some View {
        KFImage(self.url)
            .resizable()
            .placeholder {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
            .aspectRatio(contentMode: .fit)
            .scaleEffect(self.scale)
            .offset(self.offset)
            .gesture(self.magnificationGesture)
            .gesture(self.scale > 1.0 ? self.panGesture(in: geometry) : nil)
            .onTapGesture(count: 2) {
                self.doubleTapZoom()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = self.lastScale * value
                self.scale = min(max(newScale, self.minScale), self.maxScale)
            }
            .onEnded { _ in
                self.handleMagnificationEnd()
            }
    }

    private func handleMagnificationEnd() {
        if self.scale < 1.0 {
            withAnimation(.spring(response: 0.3)) {
                self.scale = 1.0
                self.offset = .zero
            }
            self.lastScale = 1.0
            self.lastOffset = .zero
        } else if self.scale > self.maxScale {
            withAnimation(.spring(response: 0.3)) {
                self.scale = self.maxScale
            }
            self.lastScale = self.maxScale
        } else {
            self.lastScale = self.scale
        }
    }

    private func panGesture(in _: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                self.offset = CGSize(
                    width: self.lastOffset.width + value.translation.width,
                    height: self.lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                self.lastOffset = self.offset
            }
    }

    private var dismissGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if self.scale == 1.0 {
                    state = value.translation
                }
            }
            .onEnded { value in
                if self.scale == 1.0, abs(value.translation.height) > 150 {
                    self.dismiss()
                }
            }
    }

    private func doubleTapZoom() {
        withAnimation(.spring(response: 0.3)) {
            if self.scale > 1.0 {
                // Reset to 1x
                self.scale = 1.0
                self.offset = .zero
                self.lastScale = 1.0
                self.lastOffset = .zero
            } else {
                // Zoom to 2x
                self.scale = 2.0
                self.lastScale = 2.0
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            self.isPresented = false
        }
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                self.downloadButton
                self.closeButton
            }
            .padding(.top, 60)

            Spacer()
        }
    }

    private var downloadButton: some View {
        Button {
            self.saveImageToPhotoLibrary()
        } label: {
            self.downloadButtonLabel
        }
        .disabled(self.isSaving)
        .padding(.trailing, 8)
    }

    private var downloadButtonLabel: some View {
        Group {
            if self.isSaving {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else {
                Image(systemName: "arrow.down.circle")
            }
        }
        .font(.system(size: 20, weight: .medium))
        .foregroundColor(.white)
        .padding(12)
        .background(Color.black.opacity(0.5))
        .clipShape(Circle())
    }

    private var closeButton: some View {
        Button {
            self.dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .padding(.trailing, 16)
    }

    private func saveImageToPhotoLibrary() {
        self.isSaving = true

        Task {
            await self.performImageSave()
        }
    }

    private func performImageSave() async {
        do {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

            guard status == .authorized || status == .limited else {
                self.handleSaveError(message: "Photo library access denied. Please enable in Settings.")
                return
            }

            let result = try await KingfisherManager.shared.retrieveImage(with: self.url)

            #if os(iOS)
            try await self.saveToPhotoLibrary(image: result.image)
            self.handleSaveSuccess()
            #else
            self.handleSaveError(message: "Image download not supported on macOS")
            #endif
        } catch {
            self.handleSaveError(message: "Failed to save image: \(error.localizedDescription)")
        }
    }

    #if os(iOS)
    private func saveToPhotoLibrary(image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAsset(from: image)
        }
    }
    #endif

    private func handleSaveSuccess() {
        self.isSaving = false
        self.saveAlertMessage = "Image saved to Photos"
        self.showSaveAlert = true
    }

    private func handleSaveError(message: String) {
        self.isSaving = false
        self.saveAlertMessage = message
        self.showSaveAlert = true
    }
}

// MARK: - Preview

#if DEBUG
    struct ImageLightboxView_Previews: PreviewProvider {
        static var previews: some View {
            if let previewURL = URL(string: "https://picsum.photos/800/600") {
                ImageLightboxView(
                    url: previewURL,
                    isPresented: .constant(true)
                )
            }
        }
    }
#endif

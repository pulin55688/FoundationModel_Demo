//
//  TapToSegmentView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import PhotosUI
import SwiftUI
import UIKit

@available(iOS 27.0, *)
struct TapToSegmentView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var tapToSegmenter: TapToSegmenter?
    @State private var maskedImage: CGImage?
    @State private var maskOverlayImage: CGImage?
    @State private var selectedPoint: CGPoint?
    @State private var lassoPoints: [CGPoint] = []
    @State private var quality: TapToSegmentQuality = .balanced
    @State private var selectionMode: SelectionMode = .point
    @State private var displayMode: DisplayMode = .spotlight
    @State private var isLoadingImage = false
    @State private var isSegmenting = false
    @State private var confidence: Float?
    @State private var modelMaskSize: CGSize?
    @State private var scaledMaskSize: CGSize?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                imagePickerArea
                selectionModePicker
                qualityPicker
                displayModePicker
                segmentationCanvas
                statusArea
                resultArea
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle("Tap to Segment")
        .onChange(of: selectedPhotoItem) { _, newItem in
            loadImage(from: newItem)
        }
        .onChange(of: quality) { _, _ in
            clearSegmentationResult()
        }
        .onChange(of: selectionMode) { _, _ in
            clearSegmentationResult()
        }
    }

    private var shouldShowMaskedImage: Bool {
        displayMode == .spotlight && maskedImage != nil
    }

    private var currentOverlayImage: CGImage? {
        switch displayMode {
        case .spotlight:
            return nil
        case .mask:
            return maskOverlayImage
        }
    }

    private var imagePickerArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("圖片")
                .font(.headline)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(selectedImage == nil ? "選擇圖片" : "更換圖片", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(isLoadingImage || isSegmenting)
        }
    }

    private var selectionModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("選取方式")
                .font(.headline)

            Picker("選取方式", selection: $selectionMode) {
                ForEach(SelectionMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isSegmenting)
        }
    }

    private var qualityPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("品質")
                .font(.headline)

            Picker("品質", selection: $quality) {
                ForEach(TapToSegmentQuality.allCases) { quality in
                    Text(quality.title)
                        .tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isSegmenting)
        }
    }

    private var displayModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("顯示方式")
                .font(.headline)

            Picker("顯示方式", selection: $displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var segmentationCanvas: some View {
        if let selectedImage {
            GeometryReader { geometry in
                let imageRect = Self.aspectFitRect(
                    imageSize: selectedImage.size,
                    containerSize: geometry.size
                )

                ZStack {
                    Color(.secondarySystemBackground)

                    if shouldShowMaskedImage, let maskedImage {
                        Image(decorative: maskedImage, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)
                    } else {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)
                    }

                    if let overlayImage = currentOverlayImage {
                        Image(decorative: overlayImage, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)
                    }

                    if selectionMode == .lasso,
                       !lassoPoints.isEmpty,
                       maskedImage == nil,
                       maskOverlayImage == nil {
                        lassoPath(in: imageRect)
                            .stroke(
                                .yellow,
                                style: StrokeStyle(
                                    lineWidth: Self.lassoDisplayLineWidth(in: imageRect),
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .shadow(color: .black.opacity(0.45), radius: 2)
                    }

                    if let selectedPoint, displayMode == .mask {
                        Circle()
                            .fill(.white)
                            .stroke(.cyan, lineWidth: 3)
                            .frame(width: 18, height: 18)
                            .shadow(radius: 3)
                            .position(Self.displayPoint(for: selectedPoint, in: imageRect))
                    }

                    if isSegmenting {
                        ProgressView()
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard selectionMode == .lasso,
                                  imageRect.contains(value.location) else {
                                return
                            }

                            let normalizedPoint = Self.normalizedPoint(from: value.location, in: imageRect)
                            appendLassoPoint(normalizedPoint)
                        }
                        .onEnded { value in
                            switch selectionMode {
                            case .point:
                                guard imageRect.contains(value.location) else { return }
                                let normalizedPoint = Self.normalizedPoint(from: value.location, in: imageRect)
                                segment(at: normalizedPoint)
                            case .lasso:
                                segmentWithLasso()
                            }
                        }
                )
            }
            .frame(height: 380)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 260)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)

                        Text("選擇圖片開始")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if isLoadingImage {
            ProgressView("正在載入圖片…")
                .frame(maxWidth: .infinity, alignment: .center)
        }

        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var resultArea: some View {
        if let confidence, let modelMaskSize, let scaledMaskSize {
            VStack(alignment: .leading, spacing: 8) {
                Text("分割結果")
                    .font(.headline)

                resultRow("Confidence", String(format: "%.2f", confidence))
                resultRow("Model mask", "\(Int(modelMaskSize.width)) x \(Int(modelMaskSize.height))")
                resultRow("Scaled mask", "\(Int(scaledMaskSize.width)) x \(Int(scaledMaskSize.height))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func resultRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.footnote)
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            await MainActor.run {
                isLoadingImage = true
                errorMessage = nil
                selectedImage = nil
                tapToSegmenter = nil
                clearSegmentationResult()
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw TapToSegmentError.invalidImage
                }

                let preparedImage = image.preparedForTapToSegment(maxPixelLength: 1_280)
                let segmenter = try TapToSegmenter(image: preparedImage)

                await MainActor.run {
                    selectedImage = preparedImage
                    tapToSegmenter = segmenter
                    isLoadingImage = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "圖片載入失敗：\(error.localizedDescription)"
                    isLoadingImage = false
                }
            }
        }
    }

    private func segment(at normalizedPoint: CGPoint) {
        guard let tapToSegmenter else { return }

        Task {
            await MainActor.run {
                selectedPoint = normalizedPoint
                lassoPoints = []
                maskedImage = nil
                maskOverlayImage = nil
                confidence = nil
                modelMaskSize = nil
                scaledMaskSize = nil
                errorMessage = nil
                isSegmenting = true
            }

            do {
                let result = try await tapToSegmenter.segment(
                    seedPoint: normalizedPoint,
                    quality: quality
                )

                await MainActor.run {
                    maskedImage = result.maskedImage
                    maskOverlayImage = result.maskOverlayImage
                    confidence = result.confidence
                    modelMaskSize = result.modelMaskSize
                    scaledMaskSize = result.scaledMaskSize
                    isSegmenting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "分割失敗：\(error.localizedDescription)"
                    isSegmenting = false
                }
            }
        }
    }

    private func appendLassoPoint(_ normalizedPoint: CGPoint) {
        if lassoPoints.isEmpty {
            selectedPoint = nil
            maskedImage = nil
            maskOverlayImage = nil
            confidence = nil
            modelMaskSize = nil
            scaledMaskSize = nil
            errorMessage = nil
        }

        lassoPoints.append(normalizedPoint)
    }

    private func segmentWithLasso() {
        guard let tapToSegmenter else { return }
        let scribblePoints = lassoPoints

        Task {
            await MainActor.run {
                selectedPoint = nil
                maskedImage = nil
                maskOverlayImage = nil
                confidence = nil
                modelMaskSize = nil
                scaledMaskSize = nil
                errorMessage = nil
                isSegmenting = true
            }

            do {
                let result = try await tapToSegmenter.segment(
                    scribblePoints: scribblePoints,
                    quality: quality
                )

                await MainActor.run {
                    maskedImage = result.maskedImage
                    maskOverlayImage = result.maskOverlayImage
                    confidence = result.confidence
                    modelMaskSize = result.modelMaskSize
                    scaledMaskSize = result.scaledMaskSize
                    lassoPoints = []
                    isSegmenting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "分割失敗：\(error.localizedDescription)"
                    isSegmenting = false
                }
            }
        }
    }

    @MainActor
    private func clearSegmentationResult() {
        maskedImage = nil
        maskOverlayImage = nil
        selectedPoint = nil
        lassoPoints = []
        confidence = nil
        modelMaskSize = nil
        scaledMaskSize = nil
        errorMessage = nil
    }

    private static func aspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private func lassoPath(in imageRect: CGRect) -> Path {
        var path = Path()
        guard let firstPoint = lassoPoints.first else { return path }

        path.move(to: Self.displayPoint(for: firstPoint, in: imageRect))

        for point in lassoPoints.dropFirst() {
            path.addLine(to: Self.displayPoint(for: point, in: imageRect))
        }

        return path
    }

    private static func lassoDisplayLineWidth(in imageRect: CGRect) -> CGFloat {
        max(imageRect.width * 0.01, 6)
    }

    private static func normalizedPoint(from location: CGPoint, in imageRect: CGRect) -> CGPoint {
        let x = (location.x - imageRect.minX) / imageRect.width
        let yFromTop = (location.y - imageRect.minY) / imageRect.height
        return CGPoint(x: min(max(x, 0), 1), y: min(max(1 - yFromTop, 0), 1))
    }

    private static func displayPoint(for normalizedPoint: CGPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + normalizedPoint.x * imageRect.width,
            y: imageRect.minY + (1 - normalizedPoint.y) * imageRect.height
        )
    }
}

@available(iOS 27.0, *)
private enum SelectionMode: String, CaseIterable, Identifiable {
    case point
    case lasso

    var id: String { rawValue }

    var title: String {
        switch self {
        case .point:
            return "點擊"
        case .lasso:
            return "套索"
        }
    }
}

@available(iOS 27.0, *)
private enum DisplayMode: String, CaseIterable, Identifiable {
    case spotlight
    case mask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spotlight:
            return "凸顯物品"
        case .mask:
            return "檢查 Mask"
        }
    }
}

@available(iOS 27.0, *)
#Preview {
    NavigationStack {
        TapToSegmentView()
    }
}

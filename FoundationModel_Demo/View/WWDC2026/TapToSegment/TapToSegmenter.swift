//
//  TapToSegmenter.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Foundation
import UIKit
import Vision

@available(iOS 27.0, *)
enum TapToSegmentQuality: String, CaseIterable, Identifiable {
    case fast
    case balanced
    case accurate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:
            return "快速"
        case .balanced:
            return "平衡"
        case .accurate:
            return "精準"
        }
    }

    var visionQualityLevel: GenerateIterativeSegmentationRequest.QualityLevel {
        switch self {
        case .fast:
            return .fast
        case .balanced:
            return .balanced
        case .accurate:
            return .accurate
        }
    }
}

@available(iOS 27.0, *)
struct TapToSegmentResult {
    let maskedImage: CGImage
    let maskOverlayImage: CGImage
    let modelMaskSize: CGSize
    let scaledMaskSize: CGSize
    let confidence: Float
}

@available(iOS 27.0, *)
enum TapToSegmentError: LocalizedError {
    case invalidImage
    case emptyMask
    case emptyScribble
    case failedToCreateScribbleBuffer

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "無法讀取這張圖片，請換一張再試。"
        case .emptyMask:
            return "沒有產生分割結果，請點選圖片中更明確的物件位置。"
        case .emptyScribble:
            return "套索路徑太短，請在圖片上畫出明確的選取範圍。"
        case .failedToCreateScribbleBuffer:
            return "無法建立套索輸入，請重新畫一次。"
        }
    }
}

@available(iOS 27.0, *)
struct TapToSegmenter {
    private static let ciContext = CIContext()
    private let cgImage: CGImage
    private let handler: ImageRequestHandler

    init(image: UIImage) throws {
        guard let cgImage = image.cgImage else {
            throw TapToSegmentError.invalidImage
        }

        self.cgImage = cgImage
        handler = ImageRequestHandler(cgImage, orientation: image.cgImageOrientation)
    }

    func segment(
        seedPoint: CGPoint,
        quality: TapToSegmentQuality
    ) async throws -> TapToSegmentResult {
        let point = NormalizedPoint(x: seedPoint.x, y: seedPoint.y)
        let request = GenerateIterativeSegmentationRequest(seedPoint: point)
        request.qualityLevel = quality.visionQualityLevel

        return try await perform(request)
    }

    func segment(
        scribblePoints: [CGPoint],
        quality: TapToSegmentQuality
    ) async throws -> TapToSegmentResult {
        guard scribblePoints.count >= 2 else {
            throw TapToSegmentError.emptyScribble
        }

        let scribbleBuffer = try makeScribbleBuffer(from: scribblePoints)
        let request = GenerateIterativeSegmentationRequest(seedScribbleBuffer: scribbleBuffer)
        request.qualityLevel = quality.visionQualityLevel

        return try await perform(request)
    }

    private func perform(_ request: GenerateIterativeSegmentationRequest) async throws -> TapToSegmentResult {
        // GenerateIterativeSegmentationRequest 需要 downloadable assets。
        // 第一次跑時如果模型資產尚未 ready，先觸發下載。
        switch await request.assetStatus {
        case .ready:
            break
        case .error(let error):
            throw error
        case .notReady, .downloading:
            try await request.downloadAssets()
        }

        guard let observation = try await handler.perform(request) else {
            throw TapToSegmentError.emptyMask
        }

        let maskImage = try observation.cgImage
        let scaledAlphaMask = try Self.makeScaledAlphaMask(
            from: maskImage,
            targetSize: CGSize(width: cgImage.width, height: cgImage.height)
        )
        let maskedImage = try Self.makeMaskedImage(
            sourceImage: cgImage,
            alphaMask: scaledAlphaMask
        )
        let maskOverlayImage = try Self.makeMaskOverlayImage(
            alphaMask: scaledAlphaMask,
            extent: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        )

        return TapToSegmentResult(
            maskedImage: maskedImage,
            maskOverlayImage: maskOverlayImage,
            modelMaskSize: observation.size,
            scaledMaskSize: CGSize(width: cgImage.width, height: cgImage.height),
            confidence: observation.confidence,
        )
    }

    private func makeScribbleBuffer(from normalizedPoints: [CGPoint]) throws -> CVReadOnlyPixelBuffer {
        let width = cgImage.width
        let height = cgImage.height
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var pixelBuffer: CVPixelBuffer?

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TapToSegmentError.failedToCreateScribbleBuffer
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw TapToSegmentError.failedToCreateScribbleBuffer
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw TapToSegmentError.failedToCreateScribbleBuffer
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // 影片建議 scribble stroke 至少是圖片寬度的 1%，太細會讓模型提示不明確。
        let lineWidth = max(CGFloat(width) * 0.01, 1)
        context.setStrokeColor(gray: 1, alpha: 1)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let firstPoint = Self.pixelPoint(from: normalizedPoints[0], width: width, height: height)
        context.beginPath()
        context.move(to: firstPoint)

        for normalizedPoint in normalizedPoints.dropFirst() {
            context.addLine(to: Self.pixelPoint(from: normalizedPoint, width: width, height: height))
        }

        // 不自動 close path，避免多產生一條從終點連回起點的 scribble 提示線。
        context.strokePath()
        return CVReadOnlyPixelBuffer(unsafeBuffer: pixelBuffer)
    }

    private static func pixelPoint(from normalizedPoint: CGPoint, width: Int, height: Int) -> CGPoint {
        CGPoint(
            x: normalizedPoint.x * CGFloat(width),
            y: (1 - normalizedPoint.y) * CGFloat(height)
        )
    }

    private static func makeScaledAlphaMask(
        from maskImage: CGImage,
        targetSize: CGSize
    ) throws -> CIImage {
        let mask = CIImage(cgImage: maskImage)
        let alphaMask = try makeAlphaMask(from: mask)
        let targetExtent = CGRect(origin: .zero, size: targetSize)
        let scaleX = targetSize.width / mask.extent.width
        let scaleY = targetSize.height / mask.extent.height

        return alphaMask
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: targetExtent)
    }

    private static func makeMaskOverlayImage(
        alphaMask: CIImage,
        extent: CGRect
    ) throws -> CGImage {
        return try makeOverlayImage(
            color: CIColor(red: 0, green: 0.72, blue: 1, alpha: 0.55),
            alphaMask: alphaMask,
            extent: extent
        )
    }

    private static func makeAlphaMask(from mask: CIImage) throws -> CIImage {
        // PixelBufferObservation.cgImage 通常是「灰階但 alpha 全不透明」。
        // SwiftUI .mask 只看 alpha，會把黑色區域也視為可見；這裡先把亮度轉成 alpha。
        let alphaFilter = CIFilter.maskToAlpha()
        alphaFilter.inputImage = mask

        guard let alphaMask = alphaFilter.outputImage else {
            throw TapToSegmentError.emptyMask
        }

        return alphaMask
    }

    private static func makeMaskedImage(
        sourceImage: CGImage,
        alphaMask: CIImage
    ) throws -> CGImage {
        let originalImage = CIImage(cgImage: sourceImage)
        let extent = originalImage.extent
        let darkOverlay = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.62))
            .cropped(to: extent)
        let dimmedBackground = darkOverlay.composited(over: originalImage)

        let blendFilter = CIFilter.blendWithAlphaMask()
        blendFilter.inputImage = originalImage
        blendFilter.backgroundImage = dimmedBackground
        blendFilter.maskImage = alphaMask

        guard let outputImage = blendFilter.outputImage,
              let maskedImage = ciContext.createCGImage(outputImage, from: extent) else {
            throw TapToSegmentError.emptyMask
        }

        return maskedImage
    }

    private static func makeOverlayImage(
        color: CIColor,
        alphaMask: CIImage,
        extent: CGRect
    ) throws -> CGImage {
        let overlayColor = CIImage(color: color)
            .cropped(to: extent)

        let clearBackground = CIImage(color: .clear)
            .cropped(to: extent)

        let blendFilter = CIFilter.blendWithAlphaMask()
        blendFilter.inputImage = overlayColor
        blendFilter.backgroundImage = clearBackground
        blendFilter.maskImage = alphaMask

        guard let outputImage = blendFilter.outputImage,
              let overlayImage = ciContext.createCGImage(outputImage, from: extent) else {
            throw TapToSegmentError.emptyMask
        }

        return overlayImage
    }
}

extension UIImage {
    func preparedForTapToSegment(maxPixelLength: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxPixelLength || imageOrientation != .up else { return self }

        let scale = min(1, maxPixelLength / longestSide)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

//
//  TapToSegmenter.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
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
    let spotlightOverlayImage: CGImage
    let maskOverlayImage: CGImage
    let confidence: Float
    let size: CGSize
}

@available(iOS 27.0, *)
enum TapToSegmentError: LocalizedError {
    case invalidImage
    case emptyMask

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "無法讀取這張圖片，請換一張再試。"
        case .emptyMask:
            return "沒有產生分割結果，請點選圖片中更明確的物件位置。"
        }
    }
}

@available(iOS 27.0, *)
enum TapToSegmenter {
    private static let ciContext = CIContext()

    static func segment(
        image: UIImage,
        seedPoint: CGPoint,
        quality: TapToSegmentQuality
    ) async throws -> TapToSegmentResult {
        guard let cgImage = image.cgImage else {
            throw TapToSegmentError.invalidImage
        }

        let point = NormalizedPoint(x: seedPoint.x, y: seedPoint.y)
        let request = GenerateIterativeSegmentationRequest(seedPoint: point)
        request.qualityLevel = quality.visionQualityLevel

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

        guard let observation = try await request.perform(on: cgImage, orientation: image.cgImageOrientation) else {
            throw TapToSegmentError.emptyMask
        }

        let maskImage = try observation.cgImage
        let spotlightOverlayImage = try makeSpotlightOverlayImage(from: maskImage)
        let maskOverlayImage = try makeMaskOverlayImage(from: maskImage)

        return TapToSegmentResult(
            spotlightOverlayImage: spotlightOverlayImage,
            maskOverlayImage: maskOverlayImage,
            confidence: observation.confidence,
            size: observation.size
        )
    }

    private static func makeSpotlightOverlayImage(from maskImage: CGImage) throws -> CGImage {
        let mask = CIImage(cgImage: maskImage)
        let alphaMask = try makeAlphaMask(from: mask, inverted: true)
        return try makeOverlayImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.62),
            alphaMask: alphaMask,
            extent: mask.extent
        )
    }

    private static func makeMaskOverlayImage(from maskImage: CGImage) throws -> CGImage {
        let mask = CIImage(cgImage: maskImage)
        let alphaMask = try makeAlphaMask(from: mask, inverted: false)
        return try makeOverlayImage(
            color: CIColor(red: 0, green: 0.72, blue: 1, alpha: 0.55),
            alphaMask: alphaMask,
            extent: mask.extent
        )
    }

    private static func makeAlphaMask(from mask: CIImage, inverted: Bool) throws -> CIImage {
        let inputMask: CIImage

        // PixelBufferObservation.cgImage 通常是「灰階但 alpha 全不透明」。
        // SwiftUI .mask 只看 alpha，會把黑色區域也視為可見；這裡先把亮度轉成 alpha。
        if inverted {
            let invertFilter = CIFilter.colorInvert()
            invertFilter.inputImage = mask

            guard let invertedMask = invertFilter.outputImage else {
                throw TapToSegmentError.emptyMask
            }

            inputMask = invertedMask
        } else {
            inputMask = mask
        }

        let alphaFilter = CIFilter.maskToAlpha()
        alphaFilter.inputImage = inputMask

        guard let alphaMask = alphaFilter.outputImage else {
            throw TapToSegmentError.emptyMask
        }

        return alphaMask
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

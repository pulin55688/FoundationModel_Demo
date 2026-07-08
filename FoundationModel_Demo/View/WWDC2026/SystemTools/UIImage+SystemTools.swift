//
//  UIImage+SystemTools.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import ImageIO
import UIKit

extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }

    func preparedForSystemTools(maxPixelLength: CGFloat) -> UIImage {
        // 只縮超過限制的圖片；小圖保留原尺寸，避免不必要的重新繪製。
        let longestSide = max(size.width, size.height)
        guard longestSide > maxPixelLength else { return self }

        let scale = maxPixelLength / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

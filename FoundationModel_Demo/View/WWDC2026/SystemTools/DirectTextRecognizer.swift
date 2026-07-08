//
//  DirectTextRecognizer.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import UIKit
import Vision

@available(iOS 27.0, *)
enum DirectTextRecognizer {
    static func recognizeText(in image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw SystemToolsDemoError.invalidImageData
        }

        // 這條路只使用 Vision 文字辨識，不經過 LanguageModelSession 或 OCRTool。
        // 適合用來確認圖片文字量，或在 OCRTool output 超過 context 上限時做 baseline。
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hant", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        guard !lines.isEmpty else {
            return "沒有辨識到文字。"
        }

        return lines.joined(separator: "\n")
    }
}

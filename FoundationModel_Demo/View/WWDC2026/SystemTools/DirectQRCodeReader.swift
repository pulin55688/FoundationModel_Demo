//
//  DirectQRCodeReader.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import UIKit
import Vision

@available(iOS 27.0, *)
enum DirectQRCodeReader {
    static func readPayloads(in image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw SystemToolsDemoError.invalidImageData
        }

        // 這條路只使用 Vision 的 barcode request，不經過 LanguageModelSession 或 BarcodeReaderTool。
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .ean13, .ean8, .code128, .pdf417]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        guard !observations.isEmpty else {
            return "沒有偵測到 QR Code。"
        }

        return observations.enumerated().map { index, observation in
            let payload = observation.payloadStringValue
                ?? observation.payloadData.flatMap { String(data: $0, encoding: .utf8) }
                ?? observation.payloadData?.base64EncodedString()
                ?? "(沒有可讀取的 payload)"
            let confidence = String(format: "%.2f", observation.confidence)

            return """
            #\(index + 1)
            條碼格式種類: \(observation.symbology.rawValue)
            信心分數: \(confidence)
            Payload: \(payload)
            """
        }
        .joined(separator: "\n\n")
    }
}

//
//  WWDC26Demo.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/6/26.
//

import Foundation
import FoundationModels
import Playgrounds
import UIKit

#Playground("Context Size") {
    let model = SystemLanguageModel()
    // 檢查模型上下文大小
    print(model.contextSize)
    
    if #available(iOS 26.4, *) {
        // 計算指令、提示詞的 token 數量
        let count = try await model.tokenCount(for: "請幫我規劃東京三日遊")
        print(count)
    } else {
        // Fallback on earlier versions
    }
}

@available(iOS 27.0, *)
#Playground("Session Usage") {
    let session = LanguageModelSession(model: SystemLanguageModel())
    let response = try await session.respond(
        to: "請幫我規劃東京三日遊行程"
//        ,
//        contextOptions: ContextOptions(reasoningLevel: .light)
    )
    
    // 輸入的 token
    print(response.usage.input.totalTokenCount)
    // 從快取讀取的輸入 token
    print(response.usage.input.cachedTokenCount)
    // 輸出的 token
    print(response.usage.output.totalTokenCount)
    // 用於推理的輸出 token
    print(response.usage.output.reasoningTokenCount)
}

@available(iOS 27.0, *)
#Playground("PCC Model, need required entitlement") {
//    let pccModel = PrivateCloudComputeLanguageModel()
//    print("PCC Model is available: \(pccModel.isAvailable)")
//    let session = LanguageModelSession(
//        model: PrivateCloudComputeLanguageModel()
//    )
//
//    let response = try await session.respond(
//        to: "請幫我規劃東京三日遊行程",
//        contextOptions: ContextOptions(reasoningLevel: .light) // 指定思考層級
//    )
}

@available(iOS 27.0, *)
#Playground("Image Understanding") {
    let model = SystemLanguageModel.default
    print("availability:", model.availability)
    print("isAvailable:", model.isAvailable)
    print("supports vision:", model.capabilities.contains(.vision))
    
    let session = LanguageModelSession(model: model)
    
    let url = Bundle.main.url(forResource: "cat", withExtension: "jpg")!
    
    let response = try await session.respond {
        "What kind of cat is in this image?"
//        Attachment(imageURL: url)
        Attachment(UIImage(named: "cat")!)
    }
    
    print(response.content)
}

//#Playground("OCR Tool") {
//    <#code#>
//}
//
//#Playground("Spotlight Search Tool") {
//    <#code#>
//}

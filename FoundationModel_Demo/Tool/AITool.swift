//
//  AITool.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/10/15.
//

import Foundation
import FoundationModels

class AITool {
    static let shared = AITool()
    
    // 接收 prompt，回傳 AI 回應內容
    public func generateResponse( for prompt: String ) async -> String {
        let session = LanguageModelSession()
        if let answer = try? await session.respond(to: "請使用繁體中文回答以下問題：\(prompt)") {
            return answer.content
        } else {
            return ""
        }
    }
    
    /// 建立一個回應串流方法，輸入提示與要生成的資料型別，輸出模型回應串流
    /// - Parameters:
    ///   - prompt: 要傳給模型的提示文字
    ///   - type: 要生成的型別
    /// - Returns: 可逐步產生部分結果的回應串流
    public func makeStream<T>(prompt: String, generating type: T.Type) -> LanguageModelSession.ResponseStream<T> where T: Generable {
        let session = LanguageModelSession()
        let stream = session.streamResponse( to: "請使用繁體中文回答以下問題：\(prompt)",
                                             generating: type )
        return stream
    }
}

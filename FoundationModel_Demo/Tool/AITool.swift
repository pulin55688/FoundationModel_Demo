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
    
    /// 接收 prompt，回傳 AI 回應內容
    /// - Returns: 生成的回應內容
    public func generateResponse( for prompt: String ) async -> String {
        // 建立一個語言模型工作階段實例
        let session = LanguageModelSession()
        
        // 對模型發出請求並等待回應
        if let answer = try? await session.respond(to: "請使用繁體中文回答以下問題：\(prompt)") {
            // 成功取得模型回應後，回傳其文字內容
            return answer.content
        } else {
            // 請求或解析過程發生錯誤（例如：工作階段失敗或中斷）
            return ""
        }
    }
    
    /// 使用指定型別產生非串流回應
    /// - Parameters:
    ///   - prompt: 要傳給模型的提示文字
    ///   - type: 要生成的型別 (需符合 Generable)
    /// - Returns: 生成的型別實例，若失敗回傳 nil
    public func generateResponse<T>(for prompt: String, generating type: T.Type) async -> T? where T: Generable {
        let session = LanguageModelSession()
        do {
            guard let answer = try? await session.respond( to: "請使用繁體中文回答以下問題：\(prompt)",
                                                           generating: type ) else { return nil }
            return answer.content
        } catch {
            return nil
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
    
    /// 透過具備天氣查詢工具的語言模型工作階段查詢指定城市天氣
    /// - Parameter city: 要查詢的城市名稱（例如：台北、台中）
    /// - Returns: 天氣查詢結果的文字，若失敗則回傳錯誤描述
    public func queryWithWeatherTool( city: String ) async -> String {
        // 建立一個語言模型工作階段，並注入自訂的 WeatherTool 以允許模型在需要時呼叫外部工具
        let session = LanguageModelSession( tools: [WeatherTool()] )
        do {
            // 對模型發出請求，要求查詢指定城市的天氣
            let response = try await session.respond( to: "請查詢\(city)地區的天氣" )
            // 從模型回應中取出文字內容並回傳
            return response.content
        } catch {
            // 回傳錯誤描述
            return "查詢失敗：\(error)"
        }
    }
}


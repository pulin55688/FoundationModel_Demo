//
//  WeatherTool.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/9/20
//

import Foundation
import FoundationModels
import Playgrounds

// 1) 定義 Tool：模型可呼叫來查詢天氣
struct WeatherTool: Tool {
    // 提供名稱與描述，利於除錯與可讀性（即使協議未必要求，保留也不影響編譯）
    let name: String = "weather"
    let description: String = "查詢指定城市的目前天氣。"
    
    @Generable(description: "查詢指定城市的目前天氣")
    struct Arguments: Codable {
        var city: String
    }

    func call(arguments: Arguments) async throws -> String {
        // 實際上應串接外部 API；在這裡回傳示範字串
        let result = "目前\(arguments.city)天氣晴 25°C"
        return result
    }
}

//#Playground("查詢台北天氣") {
//    func queryTaipeiWeather() async {
//        let session = LanguageModelSession( tools: [WeatherTool()] )
//        do {
//            let response = try await session.respond( to: "請查詢台北的天氣" )
//            print(response.content)
//        } catch {
//            print("查詢失敗：\(error)")
//        }
//    }
//    
//    await queryTaipeiWeather()
//}
//
//#Playground("查詢台南天氣") {
//    func queryTainanWeather() async {
//        let session = LanguageModelSession( tools: [WeatherTool()] )
//        do {
//            let response = try await session.respond( to: "請查詢台南的天氣" )
//            print(response.content)
//        } catch {
//            print("查詢失敗：\(error)")
//        }
//    }
//    
//    await queryTainanWeather()
//}

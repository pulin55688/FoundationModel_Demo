//
//  WeatherTool.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/9/20
//

import Foundation
import FoundationModels
import Playgrounds

// 定義 Tool：模型可呼叫來查詢天氣
struct WeatherTool: Tool {
    // 提供名稱與描述，利於除錯與可讀性
    let name: String = "查詢天氣工具"
    let description: String = "查詢指定城市的目前天氣。"
    
    // 以 @Generable 標記參數結構，提供給模型理解與自動產生參數的提示
    // Codable 讓參數能被序列化/反序列化，便於與模型/系統交換資料
    @Generable(description: "查詢指定城市的目前天氣")
    struct Arguments: Codable {
        var city: String
    }

    // 核心執行邏輯：當語言模型決定呼叫此工具時會進來這裡
    // - arguments: 模型或程式端傳入的參數（城市）
    // - 回傳：目前天氣的描述字串（實務上應串接外部天氣 API）
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

//
//  CatModel.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/9/20.
//

import Foundation
import FoundationModels
import Playgrounds

@Generable(description: "簡易貓咪資料")
struct CatProfile {
    var name: String

    @Guide(description: "貓齡", .range(0...20))
    var age: Int

    @Guide(description: "個性描述，一句話")
    var profile: String
}

class CatModel {
    func getACat() async {
        let session = LanguageModelSession()
        do {
            let cat = try await session.respond(
                to: "請產生一隻可愛的領養貓資料",
                generating: CatProfile.self
            )
            
            // 型別安全地取得欄位
            print("名字：\(cat.content.name)")
            print("年齡：\(cat.content.age)")
            print("介紹：\(cat.content.profile)")
        } catch {
            // 處理錯誤，避免未處理的 throw
            print("取得貓咪資料失敗：\(error)")
        }
    }
}

//#Playground("產生一隻貓咪") {
//    let model = CatModel()
//    await model.getACat()
//}

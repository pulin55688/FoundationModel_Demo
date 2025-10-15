//
//  PetModel.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/9/20.
//

import Foundation
import FoundationModels
import Playgrounds

@Generable(description: "寵物資料")
struct PetProfile {
    @Guide(description: "寵物的名字")
    var name: String
    
    /**
     @Guide 可逐欄位提供更細的規範，使模型盡量產生符合說明與條件的內容。
     例如這邊告訴模型這個欄位是「寵物年齡」，並使用 .range(0...20) 設定生成限制
     */
    @Guide(description: "寵物年齡", .range(0...20))
    var age: Int

    @Guide(description: "個性描述，一句話")
    var description: String
}

class PetModel {
    public func getAPet( petType: String ) async -> PetProfile? {
        let pet = await AITool.shared.generateResponse( for: "請產生一隻種類為\(petType)的寵物資料",
                                                        generating: PetProfile.self )
       return pet
    }
    
}

//#Playground("產生一隻貓咪") {
//    let model = PetModel()
//    guard let cat = await model.getAPet(petType: "貓咪") else { return }
//    print(cat)
//}

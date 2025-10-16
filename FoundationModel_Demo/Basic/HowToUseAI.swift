//
//  HowToUseAI.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/10/16.
//

import Playgrounds
import FoundationModels

#Playground("AI 基礎使用") {
    // 建立一個語言模型工作階段實例
    let session = LanguageModelSession()
    
    // 對模型發出請求並等待回應
    let response = try await session.respond(to: "請列出五個知名的世界旅遊景點，並簡單介紹景點。")
    print(response.content)
}

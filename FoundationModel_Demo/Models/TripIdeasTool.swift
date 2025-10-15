//
//  TripIdeasTool.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/9/20.
//

import FoundationModels
import Playgrounds
import Foundation

// 標記 Generable 代表：
// 1) 可被模型生成
// 2) 可被序列化與反序列化（Codable）
@Generable
struct TripIdeas {
    @Guide(description: "旅遊建議")
    var ideas: String
}

class TripIdeasTool {
    
    public func getTrip( country: String ) -> AsyncThrowingStream<String, Error> {
        let stream: LanguageModelSession.ResponseStream<TripIdeas> = AITool.shared.makeStream(
            prompt: "推薦 5 個\(country)旅遊行程",
            generating: TripIdeas.self
        )
                
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await partial in stream {
                        // partial: ResponseStream<TripIdeas>.Snapshot，代表「到目前為止」模型已經生成出的部分結果
                        /**
                         stream  ->  partial (一個時刻的快照)
                         ->  content (快照對應的型別資料，例如 TripIdeas)
                         ->  ideas (型別內自定義的欄位)
                         */
                        guard let ideas = partial.content.ideas else {
                            // 還沒有內容就略過這次迭代，等待下一個快照
                            continue
                        }
                        // 在逐步生成的過程中，模型可能還沒產生到某個欄位或其內容尚不完整，
                        // 因此被設計為 Optional
                        print(ideas) // 內容隨著生成進度逐步變長
                        // 每次有新內容就丟出
                        continuation.yield(ideas)
                    }
                    continuation.finish()
                } catch {
                    print("取得旅遊建議失敗：\(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
}

#Playground("取得旅遊建議") {
    let model = TripIdeasTool()
    do {
        for try await partialIdeas in model.getTrip( country: "日本" ) {
            await MainActor.run {
                print(partialIdeas) // 這裡 partialText 是「到目前為止」的完整快照
            }
        }
    } catch {
        await MainActor.run {
            print("發生錯誤：\(error.localizedDescription)")
        }
    }
}


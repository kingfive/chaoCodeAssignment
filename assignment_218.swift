//【ChaoCode】 Swift 中級篇 18 多個 Async 任務 實作作業參考解答

import Foundation
import _Concurrency


// 1. 請將以下內容改用 async let 寫，讓程式能在 2 秒初完成。
// ＊如果你的 playground 也無法使用此語法，可以直接對照是否跟答案一樣。
//
//Task {
//    let startTime = Date.now
//    async let username = getUsername()
//    async let movies = getAllMovies()
//
//    print("Hello \(await username)，現在熱門電影是 \(await movies)")
//    printElapsedTime(from: startTime)
//}



// 2. 根據步驟依序建立一個取得翻譯過的「Hello」API 服務，接著使用這個 API 提供首頁畫面需要的資訊，最後測試獲得首頁畫面資訊的功能是否正常。第二步驟和第三步驟都需要使用 TaskGroup 完成。
// 1️⃣ 寫一個根據使用者位置取得當地語言的「HelloAPIManager」的服務。
// ＊你可以透過網址「 https://fourtonfish.com/hellosalut/?cc= 」後面加上位置取得對應的當地 Hello。此位置資料和 User 中的 location 屬性一樣。
// ＊下載到資料後，可以透過 helloDataToString(Data) 這個方法把資料轉成 String。
// ＊所有錯誤都應該被拋出去讓呼叫端自行決定如何處理。
// ＊請先打開瀏覽器到「 https://fourtonfish.com/hellosalut/?cc=tw 」 ，確認你能正常連到此網站，如果不行的話則直接使用「getLocalizedHello(of:)」這個方法取得當地 Hello。
enum HelloAPIManager {
    enum HelloAPIError: Error {
        case incorrectURL
        case unableToParseData
    }

    static func hello(at location: String) async throws -> String {
        guard let url = URL(string: "https://fourtonfish.com/hellosalut/?cc=\(location)") else {
            throw HelloAPIError.incorrectURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode),
              let hello = helloDataToString(data) else {
            throw HelloAPIError.unableToParseData
        }
        return hello
    }
}


// 2️⃣ 寫一個登入並提供首頁畫面內容的 function，首頁內容包含使用者名稱（User 中的 name 屬性）、當地 Hello 以及當地氣溫。
// ＊ 請使用 TaskGroup 處理並將 function 回傳值設為 HomePageContent 來提供以上資訊。
// ＊ 如果找不到當地 Hello 就直接回傳英文 Hello；如果找不到當地氣溫則回傳 nil。
// ＊ 無法登入應報錯。
// ＊ 💡 提示：通常不同回傳值的 Task 會建立在不同的 group。但遇到需要在同一個 group 中處理不同回傳值的 Task 時，可以搭配 enum 處理。

typealias HomePageContent = (username: String, localilzedHello: String, localTemprature: Double?)

enum HomePageResult {
    case hello(String)
    case weather(Double?)
}

func login(account: String, password: String) async throws -> HomePageContent {
    try await withThrowingTaskGroup(of: HomePageResult.self, returning: HomePageContent.self) { group in
        
        let user = try await User(account: account, password: password)

        group.addTask {
            .hello((try? await HelloAPIManager.hello(at: user.location)) ?? "Hello")
        }
        group.addTask {
            .weather(try? await getWeather(for: user.location))
        }

        var content: HomePageContent = ("", "", 0)
        
        for try await result in group {
            switch result {
                case .weather(let temprature):
                    content.localTemprature = temprature
                case .hello(let hello):
                    content.localilzedHello = hello
            }
        }
        
        content.username = user.name
        return content
    }
}

// 3️⃣ 用 TaskGroup 測試 testCases 中的六組登入資料，使用你在第二步建立的 function 登入。
// ＊ 最後應照原本的測試順序印出歡迎訊息。
// ＊ 歡迎訊息是：「Hello,ＯＯＯ。今天的溫度大約是 ＸＸ 度。」。Hello 應為當地語言，ＯＯＯ 是使用者名稱，如果沒有溫度資訊則省略。
// ＊ 無法登入時印出「無法登入帳號 ＸＸＸ，原因：ＯＯＯ」。ＯＯＯ直接使用錯誤名稱即可。
// ＊ 印出測試完六組總共花費多少時間。我的完成時間是兩秒多，不過因為包含網路任務所以這個數字會受到你的網路速度影響。

let testCases: [(account: String, password: String)] = [("janechao", "pass"), ("chaocode", "pass"), ("aragakiyui", "pass"), ("thinkaboutzu", "pass"), ("kimkardashian", "1234"), ("emilyinparis", "pass")]
Task {
    let startTime = Date.now
    
    await withTaskGroup(of: (id: String, message: String).self) { group in
        testCases.forEach { test in
            group.addTask {
                do {
                    let result = try await login(account: test.account, password: test.password)
                    let tempratureMessage = result.localTemprature == .none ? "" : "今天的溫度大約是 \(result.localTemprature!) 度。"
                    
                    return (test.account, "\(result.localilzedHello), \(result.username)。\(tempratureMessage)")
                } catch {
                    return (test.account, "無法登入帳號 \(test.account)，原因：\(error)")
                }
                
            }
        }
        
        var results = [String: String]()
        for await result in group {
            results[result.id] = result.message
        }
        
        testCases.forEach { print(results[$0.account]!) }
    }
    
    printElapsedTime(from: startTime)
}


import Foundation

enum Config {
    #if DEBUG
    static let serverURL = "http://localhost:3000"
    #else
    static let serverURL = "https://REPLACE_WITH_RAILWAY_URL"
    #endif

    static let apiBaseURL = "\(serverURL)/api"
}

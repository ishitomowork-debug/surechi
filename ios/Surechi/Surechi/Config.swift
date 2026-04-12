import Foundation

enum Config {
    #if DEBUG
    static let serverURL = "http://localhost:3000"
    #else
    static let serverURL = "https://surechi-production.up.railway.app"
    #endif

    static let apiBaseURL = "\(serverURL)/api"
}

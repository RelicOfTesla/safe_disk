import Foundation
import Cocoa


struct WindowConfiguration: Codable {

    let arguments: String
    let hiddenAtLaunch: Bool
    let title: String
    let width: Int
    let height: Int

    enum CodingKeys: String, CodingKey {
        case arguments
        case hiddenAtLaunch
        case title
        case width
        case height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        arguments = try container.decodeIfPresent(String.self, forKey: .arguments) ?? ""
        hiddenAtLaunch = try container.decodeIfPresent(Bool.self, forKey: .hiddenAtLaunch) ?? false
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 1280
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 720
    }

    init(arguments: String, hiddenAtLaunch: Bool, title: String = "", width: Int = 1280, height: Int = 720) {
        self.arguments = arguments
        self.hiddenAtLaunch = hiddenAtLaunch
        self.title = title
        self.width = width
        self.height = height
    }

    static let defaultConfiguration = WindowConfiguration(
        arguments: "",
        hiddenAtLaunch: false,
        title: "",
        width: 1280,
        height: 720
    )

    static func fromJson(_ json: [String: Any?]) -> WindowConfiguration {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            debugPrint("invalid json object: \(json)")
            return defaultConfiguration
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(WindowConfiguration.self, from: jsonData)
        } catch {
            debugPrint("Failed to parse window configuration: \(error)")
            return defaultConfiguration
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(arguments, forKey: .arguments)
        try container.encode(hiddenAtLaunch, forKey: .hiddenAtLaunch)
        try container.encode(title, forKey: .title)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

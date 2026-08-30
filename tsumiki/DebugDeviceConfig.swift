import Foundation
import UIKit

enum DebugDeviceConfig {
    // 許可不要。同一開発者のアプリが1つでも残っていれば固定値を返す
    static var persistentDeviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    private static let registeredIDs: [String] = {
        guard let url = Bundle.main.url(forResource: "debug-config", withExtension: "js"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let pattern = #"VENDOR_IDS\s*:\s*\[([^\]]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else { return [] }
        return content[range]
            .components(separatedBy: ",")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                  .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
            .filter { !$0.isEmpty }
    }()

    static var isDebugDevice: Bool {
        registeredIDs.contains(persistentDeviceID)
    }
}

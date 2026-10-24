import Foundation

enum PublicationAttribution {
    static func value(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let junk = #"^(网站|栏目|首页|未知|none|null|undefined|n/?a|site|category|unknown|—|–|-|\.{1,3})$"#
        if text.range(of: junk, options: [.regularExpression, .caseInsensitive]) != nil { return nil }
        if text.range(of: #"^https?://\S+$"#, options: [.regularExpression, .caseInsensitive]) != nil { return nil }
        if text.range(of: #"^[\p{P}\p{S}\s]+$"#, options: .regularExpression) != nil { return nil }
        return text
    }
}

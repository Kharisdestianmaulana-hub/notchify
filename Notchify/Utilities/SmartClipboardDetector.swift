import SwiftUI
import AppKit

struct SmartClipboardResult {
    let message: String
    let icon: String
    let colorSwatch: Color?
    let accentColor: Color
}

class SmartClipboardDetector {
    static func detect(text: String) -> SmartClipboardResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SmartClipboardResult(message: LanguageManager.tr("Text Copied"), icon: "text.quote", colorSwatch: nil, accentColor: .cyan)
        }
        
        // 1. Color Code (HEX, RGB, RGBA)
        if let (color, label) = parseColor(trimmed) {
            let msg = "\(LanguageManager.tr("Color")) \(label) \(LanguageManager.tr("Copied"))"
            return SmartClipboardResult(message: msg, icon: "circle.fill", colorSwatch: color, accentColor: color)
        }
        
        // 2. URL / Link
        if isURL(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("Link Copied"),
                icon: "link",
                colorSwatch: nil,
                accentColor: .blue
            )
        }
        
        // 3. Email Address
        if isEmail(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("Email Copied"),
                icon: "envelope.fill",
                colorSwatch: nil,
                accentColor: Color(red: 0.7, green: 0.35, blue: 0.95)
            )
        }
        
        // 4. Terminal Command or Code
        if let (isCommand, _) = detectCodeOrCommand(trimmed) {
            if isCommand {
                return SmartClipboardResult(
                    message: LanguageManager.tr("Terminal Command Copied"),
                    icon: "terminal.fill",
                    colorSwatch: nil,
                    accentColor: Color(red: 0.2, green: 0.9, blue: 0.5)
                )
            } else {
                return SmartClipboardResult(
                    message: LanguageManager.tr("Code Snippet Copied"),
                    icon: "chevron.left.forwardslash.chevron.right",
                    colorSwatch: nil,
                    accentColor: Color(red: 0.3, green: 0.85, blue: 0.95)
                )
            }
        }
        
        // 5. File / Directory Path
        if isFilePath(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("File Path Copied"),
                icon: "folder.fill",
                colorSwatch: nil,
                accentColor: Color(red: 1.0, green: 0.8, blue: 0.2)
            )
        }
        
        // 6. Currency / Price
        if isCurrency(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("Currency Copied"),
                icon: "dollarsign.circle.fill",
                colorSwatch: nil,
                accentColor: Color(red: 0.2, green: 0.85, blue: 0.4)
            )
        }
        
        // 7. Phone Number
        if isPhoneNumber(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("Phone Number Copied"),
                icon: "phone.fill",
                colorSwatch: nil,
                accentColor: Color(red: 0.2, green: 0.85, blue: 0.4)
            )
        }
        
        // 8. Text with Word Count (Fallback)
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count > 2 {
            let msg = "\(LanguageManager.tr("Text Copied")) (\(words.count) \(LanguageManager.tr("words")))"
            return SmartClipboardResult(
                message: msg,
                icon: "text.quote",
                colorSwatch: nil,
                accentColor: .cyan
            )
        } else {
            return SmartClipboardResult(
                message: LanguageManager.tr("Text Copied"),
                icon: "text.quote",
                colorSwatch: nil,
                accentColor: .cyan
            )
        }
    }
    
    // MARK: - Helper Parsers
    private static func parseColor(_ text: String) -> (Color, String)? {
        // HEX (#FFF, #FFFF, #RRGGBB, #RRGGBBAA)
        if text.hasPrefix("#") {
            let hex = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.count == 3 || hex.count == 4 || hex.count == 6 || hex.count == 8 {
                var int: UInt64 = 0
                if Scanner(string: hex).scanHexInt64(&int) {
                    let r, g, b, a: Double
                    if hex.count == 3 {
                        r = Double((int >> 8) * 17) / 255.0
                        g = Double((int >> 4 & 0xF) * 17) / 255.0
                        b = Double((int & 0xF) * 17) / 255.0
                        a = 1.0
                    } else if hex.count == 6 {
                        r = Double((int >> 16) & 0xFF) / 255.0
                        g = Double((int >> 8) & 0xFF) / 255.0
                        b = Double(int & 0xFF) / 255.0
                        a = 1.0
                    } else if hex.count == 8 {
                        r = Double((int >> 24) & 0xFF) / 255.0
                        g = Double((int >> 16) & 0xFF) / 255.0
                        b = Double((int >> 8) & 0xFF) / 255.0
                        a = Double(int & 0xFF) / 255.0
                    } else {
                        r = 1.0; g = 1.0; b = 1.0; a = 1.0
                    }
                    let color = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
                    return (color, "#\(hex.uppercased())")
                }
            }
        }
        
        // RGB / RGBA: rgb(255, 99, 71) or rgba(255, 99, 71, 0.8)
        let lower = text.lowercased()
        if (lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(")) && lower.hasSuffix(")") {
            let cleaned = lower.replacingOccurrences(of: "rgba(", with: "")
                               .replacingOccurrences(of: "rgb(", with: "")
                               .replacingOccurrences(of: ")", with: "")
            let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3,
               let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) {
                let a = parts.count >= 4 ? (Double(parts[3]) ?? 1.0) : 1.0
                let color = Color(.sRGB, red: min(r, 255.0)/255.0, green: min(g, 255.0)/255.0, blue: min(b, 255.0)/255.0, opacity: a)
                return (color, "RGB")
            }
        }
        return nil
    }
    
    private static func isURL(_ text: String) -> Bool {
        guard !text.contains(" ") && !text.contains("\n") else { return false }
        if text.hasPrefix("http://") || text.hasPrefix("https://") || text.hasPrefix("www.") {
            return true
        }
        if let url = URL(string: text), url.scheme != nil, url.host != nil {
            return true
        }
        return false
    }
    
    private static func isEmail(_ text: String) -> Bool {
        guard !text.contains(" ") && !text.contains("\n") && text.contains("@") && text.contains(".") else { return false }
        let pattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    
    private static func detectCodeOrCommand(_ text: String) -> (isCommand: Bool, dummy: Void)? {
        let cmdPrefixes = [
            "git ", "npm ", "npx ", "yarn ", "pnpm ", "brew ", "sudo ", "curl ", "wget ",
            "docker ", "podman ", "cargo ", "pip ", "python ", "python3 ", "swift ", "go ",
            "cd ", "ls ", "mkdir ", "chmod ", "chown ", "cat ", "grep ", "ssh ", "scp ",
            "defaults ", "killall ", "xcodebuild ", "code ", "open "
        ]
        if cmdPrefixes.contains(where: { text.hasPrefix($0) }) {
            return (true, ())
        }
        
        let codeKeywords = [
            "func ", "function ", "def ", "class ", "struct ", "enum ", "import ",
            "const ", "export ", "public func ", "private func ", "let ", "var "
        ]
        if codeKeywords.contains(where: { text.hasPrefix($0) }) {
            return (false, ())
        }
        return nil
    }
    
    private static func isFilePath(_ text: String) -> Bool {
        guard !text.contains("\n"), text.count > 2 else { return false }
        if text.hasPrefix("//") { return false }
        if text.hasPrefix("/") || text.hasPrefix("~/") {
            let slashCount = text.filter { $0 == "/" }.count
            return slashCount >= 1 && !text.hasPrefix("http")
        }
        return false
    }
    
    private static func isCurrency(_ text: String) -> Bool {
        guard !text.contains("\n"), text.count <= 25 else { return false }
        let lower = text.lowercased()
        if lower.hasPrefix("rp") || lower.hasPrefix("idr") ||
           text.hasPrefix("$") || text.hasPrefix("€") || text.hasPrefix("£") || text.hasPrefix("¥") {
            return text.contains(where: { $0.isNumber })
        }
        if lower.hasSuffix(" idr") || lower.hasSuffix(" usd") || lower.hasSuffix(" eur") {
            return text.contains(where: { $0.isNumber })
        }
        return false
    }
    
    private static func isPhoneNumber(_ text: String) -> Bool {
        guard !text.contains("\n") else { return false }
        let digits = text.filter { $0.isNumber }
        guard digits.count >= 8 && digits.count <= 15 else { return false }
        let allowed = CharacterSet(charactersIn: "+-() 0123456789")
        if text.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return text.hasPrefix("+") || text.hasPrefix("08") || text.hasPrefix("02") || text.hasPrefix("(0") || text.hasPrefix("(")
        }
        return false
    }
}

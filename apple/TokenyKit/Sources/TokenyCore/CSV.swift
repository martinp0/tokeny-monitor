import Foundation

/// Small RFC 4180 reader. Enough for the OpenRouter activity export and the Cursor / Grok Bot
/// usage export, including quoted commas and quotes inside the Usage JSON column.
enum CSVTable {
    static func parse(_ text: String, transformHeader: (String) -> String) -> [[String: String]] {
        let records = records(in: text)
        guard let header = records.first else { return [] }
        let names = header.map { transformHeader(stripBOM($0)) }
        var rows: [[String: String]] = []
        for record in records.dropFirst() {
            if record.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            var row: [String: String] = [:]
            for (index, name) in names.enumerated() where !name.isEmpty {
                row[name] = index < record.count ? record[index] : ""
            }
            rows.append(row)
        }
        return rows
    }

    static func headerNames(_ text: String) -> [String] {
        guard let first = records(in: text).first else { return [] }
        return first.map { stripBOM($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func stripBOM(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{FEFF}", with: "")
    }

    private static func records(in text: String) -> [[String]] {
        var records: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if inQuotes {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                    index += 1
                    continue
                }
                field.append(char)
                index += 1
                continue
            }
            if char == "\"" {
                inQuotes = true
                index += 1
                continue
            }
            if char == "," {
                fields.append(field)
                field = ""
                index += 1
                continue
            }
            if char == "\n" || char == "\r" {
                if char == "\r", index + 1 < chars.count, chars[index + 1] == "\n" { index += 1 }
                fields.append(field)
                field = ""
                records.append(fields)
                fields = []
                index += 1
                continue
            }
            field.append(char)
            index += 1
        }
        if inQuotes || !field.isEmpty || !fields.isEmpty {
            fields.append(field)
            records.append(fields)
        }
        return records
    }
}

import Foundation

/// Best-guess fields extracted from OCR'd receipt text. Either field may be
/// `nil` when nothing plausible was found, in which case the UI simply
/// leaves that part of the form blank for the user to fill in.
struct ParsedReceipt: Equatable {
    var purchaseDate: Date?
    var totalAmount: Decimal?
}

/// Pure text-in, values-out heuristics for pulling a purchase date and a
/// total amount out of OCR'd receipt lines. Deliberately has no dependency
/// on Vision/UIKit so it can be unit-tested with plain `[String]` fixtures.
struct ReceiptParser {
    // MARK: Date formats, tried in this order for every date-shaped
    // substring found in the text. Single-letter month/day symbols ("M",
    // "d") accept both "3" and "03", so these formats tolerate receipts
    // that don't zero-pad.
    private static let dateFormatStrings = [
        "yyyy-M-d",
        "M/d/yyyy",
        "d/M/yyyy",
        "MMM d, yyyy",
        "MMMM d, yyyy"
    ]

    private static let formatters: [DateFormatter] = dateFormatStrings.map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }

    /// Matches numeric dates like 03/14/2026, 31-01-2026, or 2026-02-10.
    private static let numericDatePattern = #"\b\d{1,4}[\/\-]\d{1,2}[\/\-]\d{1,4}\b"#

    /// Matches month-name dates like "Jan 5, 2026" or "January 5, 2026".
    private static let monthNameDatePattern =
        #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-zA-Z]*\.?\s+\d{1,2},?\s+\d{4}\b"#

    /// Keywords that mark a line as likely holding the receipt's total,
    /// most specific first. Lines containing "SUBTOTAL" are always skipped
    /// since it textually contains "TOTAL" but isn't the final amount.
    private static let totalKeywords = [
        "GRAND TOTAL", "TOTAL DUE", "AMOUNT DUE", "BALANCE DUE", "TOTAL", "AMOUNT", "BALANCE"
    ]

    /// Matches a currency-looking amount, e.g. "$64.78", "64.78", "£12.00".
    private static let amountPattern = #"[\$£€]?\s?\d{1,6}\.\d{2}"#

    init() {}

    /// Parses OCR'd receipt lines, returning the most plausible purchase
    /// date (on or before `referenceDate`) and total amount found.
    func parse(lines: [String], referenceDate: Date = Date()) -> ParsedReceipt {
        ParsedReceipt(
            purchaseDate: extractDate(lines: lines, referenceDate: referenceDate),
            totalAmount: extractTotal(lines: lines)
        )
    }

    // MARK: - Date extraction

    private func extractDate(lines: [String], referenceDate: Date) -> Date? {
        var best: Date?
        for candidate in dateCandidates(in: lines) {
            for formatter in Self.formatters {
                guard let parsed = formatter.date(from: candidate), parsed <= referenceDate else {
                    continue
                }
                if let currentBest = best {
                    if parsed > currentBest {
                        best = parsed
                    }
                } else {
                    best = parsed
                }
                break
            }
        }
        return best
    }

    private func dateCandidates(in lines: [String]) -> [String] {
        var candidates: [String] = []
        for line in lines {
            candidates.append(contentsOf: matches(of: Self.numericDatePattern, in: line))
            candidates.append(contentsOf: matches(of: Self.monthNameDatePattern, in: line))
        }
        return candidates
    }

    // MARK: - Amount extraction

    private func extractTotal(lines: [String]) -> Decimal? {
        let uppercasedLines = lines.map { $0.uppercased() }
        for keyword in Self.totalKeywords {
            for (index, upperLine) in uppercasedLines.enumerated() {
                guard !upperLine.contains("SUBTOTAL"), upperLine.contains(keyword) else {
                    continue
                }
                if let amount = extractAmounts(from: lines[index]).max() {
                    return amount
                }
            }
        }
        // Fallback: largest currency-looking amount anywhere in the receipt.
        return lines.flatMap { extractAmounts(from: $0) }.max()
    }

    private func extractAmounts(from line: String) -> [Decimal] {
        matches(of: Self.amountPattern, in: line).compactMap { raw in
            let cleaned = raw.filter { $0.isNumber || $0 == "." }
            return Decimal(string: cleaned)
        }
    }

    // MARK: - Regex helper

    private func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }
}

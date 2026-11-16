/// An exact nonnegative decimal score. Repeated 5× rats cannot overflow an Int.
/// No third-party big-number library or network dependency is required.
public struct ArcadeScore: Equatable, Comparable, Sendable, CustomStringConvertible {
    public private(set) var digits: String

    public init(_ text: String = "0") {
        guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }) else {
            digits = "0"
            return
        }
        let normalized = text.drop(while: { $0 == "0" })
        digits = normalized.isEmpty ? "0" : String(normalized)
    }

    public var description: String { digits }

    public mutating func addOne() {
        var bytes = Array(digits.utf8)
        var position = bytes.count - 1
        while position >= 0 {
            if bytes[position] < 57 {
                bytes[position] += 1
                digits = String(decoding: bytes, as: UTF8.self)
                return
            }
            bytes[position] = 48
            position -= 1
        }
        bytes.insert(49, at: 0)
        digits = String(decoding: bytes, as: UTF8.self)
    }

    public mutating func multiplyByFive() {
        var result: [UInt8] = []
        var carry = 0
        for byte in digits.utf8.reversed() {
            let value = Int(byte - 48) * 5 + carry
            result.append(UInt8(value % 10) + 48)
            carry = value / 10
        }
        if carry > 0 { result.append(UInt8(carry) + 48) }
        digits = String(decoding: result.reversed(), as: UTF8.self)
    }

    public var nextLevel: ArcadeScore {
        var result = self
        result.addOne()
        return result
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.digits.count != rhs.digits.count { return lhs.digits.count < rhs.digits.count }
        return lhs.digits.lexicographicallyPrecedes(rhs.digits)
    }

    /// A bounded approximation for movement speed only. The actual score stays exact.
    public var speedValue: Double {
        digits.count > 6 ? 1_000_000 : (Double(digits) ?? 0)
    }

    public var compact: String {
        let count = digits.count
        guard count > 3 else { return digits }
        let groups = (count - 1) / 3
        let suffixes = ["", "K", "M", "B", "T"]
        if groups < suffixes.count {
            let leading = (count - 1) % 3 + 1
            let whole = String(digits.prefix(leading))
            let decimals = String(digits.dropFirst(leading).prefix(max(0, 3 - leading)))
            return whole + (decimals.isEmpty ? "" : "." + decimals) + suffixes[groups]
        }
        return String(digits.prefix(1)) + "." + String(digits.dropFirst().prefix(2)) + "e\(count - 1)"
    }
}

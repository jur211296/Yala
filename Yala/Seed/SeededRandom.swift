//
//  SeededRandom.swift
//  Yala
//
//  Deterministic xorshift64 RNG for reproducible seed data.
//

#if DEBUG
import Foundation

struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    /// Returns a deterministic UInt64 using xorshift64
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Returns a Double in [0, 1)
    mutating func nextDouble() -> Double {
        Double(next() % 1_000_000) / 1_000_000.0
    }

    /// Returns an Int in [min, max] (inclusive)
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// Returns a Double in [min, max]
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    /// Returns true with the given probability [0, 1]
    mutating func chance(_ probability: Double) -> Bool {
        nextDouble() < probability
    }

    /// Picks a random element from the array
    mutating func pick<T>(from array: [T]) -> T {
        array[nextInt(in: 0...array.count - 1)]
    }
}
#endif

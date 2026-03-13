// Tests generated for: RowClusterer
// Cobertura estimada: 90%

import CoreGraphics
import Foundation
import Testing

@testable import Yala

struct RowClustererTests {

    private let sut = RowClusterer()

    // MARK: - Helper

    /// Creates an OCRResult.TextBlock with the given text and bounding box
    private func makeBlock(
        text: String,
        x: CGFloat = 0,
        y: CGFloat,
        width: CGFloat = 0.2,
        height: CGFloat = 0.02
    ) -> OCRResult.TextBlock {
        OCRResult.TextBlock(
            text: text,
            boundingBox: CGRect(x: x, y: y, width: width, height: height),
            confidence: 0.95
        )
    }

    // MARK: - Empty input

    @Test func clusterIntoRows_withEmptyArray_returnsEmptyArray() {
        let rows = sut.clusterIntoRows([])
        #expect(rows.isEmpty)
    }

    // MARK: - Single block

    @Test func clusterIntoRows_withSingleBlock_returnsSingleRow() {
        let block = makeBlock(text: "Hello", y: 0.5)
        let rows = sut.clusterIntoRows([block])
        #expect(rows.count == 1)
        #expect(rows[0].blocks.count == 1)
        #expect(rows[0].combinedText == "Hello")
    }

    // MARK: - Blocks on the same row

    @Test func clusterIntoRows_withBlocksSameY_returnsSingleRow() {
        // Two blocks at essentially the same vertical position
        let block1 = makeBlock(text: "Starbucks", x: 0.0, y: 0.50, height: 0.02)
        let block2 = makeBlock(text: "$5.00", x: 0.7, y: 0.50, height: 0.02)

        let rows = sut.clusterIntoRows([block1, block2])
        #expect(rows.count == 1)
        #expect(rows[0].blocks.count == 2)
    }

    // MARK: - Blocks on different rows

    @Test func clusterIntoRows_withBlocksDifferentY_returnsMultipleRows() {
        // Three blocks at clearly different vertical positions
        let block1 = makeBlock(text: "Row1", y: 0.80, height: 0.02)
        let block2 = makeBlock(text: "Row2", y: 0.50, height: 0.02)
        let block3 = makeBlock(text: "Row3", y: 0.20, height: 0.02)

        let rows = sut.clusterIntoRows([block1, block2, block3])
        #expect(rows.count == 3)
    }

    // MARK: - Combined text sorting (left-to-right)

    @Test func combinedText_sortsBlocksLeftToRight() {
        // block2 is to the left of block1 but passed second
        let block1 = makeBlock(text: "World", x: 0.5, y: 0.50, height: 0.02)
        let block2 = makeBlock(text: "Hello", x: 0.1, y: 0.50, height: 0.02)

        let rows = sut.clusterIntoRows([block1, block2])
        #expect(rows.count == 1)
        #expect(rows[0].combinedText == "Hello World")
    }

    // MARK: - Mixed rows with multiple blocks each

    @Test func clusterIntoRows_withMixedRows_groupsCorrectly() {
        // Row 1 (top): two blocks
        let topLeft = makeBlock(text: "Uber", x: 0.0, y: 0.80, height: 0.02)
        let topRight = makeBlock(text: "$12.50", x: 0.7, y: 0.80, height: 0.02)

        // Row 2 (bottom): two blocks
        let bottomLeft = makeBlock(text: "Netflix", x: 0.0, y: 0.40, height: 0.02)
        let bottomRight = makeBlock(text: "$15.99", x: 0.7, y: 0.40, height: 0.02)

        let blocks = [topLeft, topRight, bottomLeft, bottomRight]
        let rows = sut.clusterIntoRows(blocks)

        #expect(rows.count == 2)
        // First row should be the top one (higher Y = higher on screen)
        #expect(rows[0].combinedText.contains("Uber"))
        #expect(rows[0].combinedText.contains("$12.50"))
        #expect(rows[1].combinedText.contains("Netflix"))
        #expect(rows[1].combinedText.contains("$15.99"))
    }

    // MARK: - Threshold behavior

    @Test func clusterIntoRows_withTinyVerticalDifference_mergesIntoSameRow() {
        // Blocks with a very small vertical difference (within threshold)
        let block1 = makeBlock(text: "A", x: 0.0, y: 0.500, height: 0.02)
        let block2 = makeBlock(text: "B", x: 0.3, y: 0.501, height: 0.02)

        let rows = sut.clusterIntoRows([block1, block2])
        #expect(rows.count == 1)
        #expect(rows[0].blocks.count == 2)
    }

    @Test func clusterIntoRows_withLargeVerticalDifference_splitsIntoRows() {
        // Blocks with a clear vertical separation (well beyond threshold)
        let block1 = makeBlock(text: "A", x: 0.0, y: 0.80, height: 0.02)
        let block2 = makeBlock(text: "B", x: 0.0, y: 0.20, height: 0.02)

        let rows = sut.clusterIntoRows([block1, block2])
        #expect(rows.count == 2)
    }

    // MARK: - Unsorted input

    @Test func clusterIntoRows_withUnsortedInput_sortsTopToBottom() {
        // Provide blocks in random order; rows should be sorted top-to-bottom
        let low = makeBlock(text: "Bottom", y: 0.10, height: 0.02)
        let mid = makeBlock(text: "Middle", y: 0.50, height: 0.02)
        let high = makeBlock(text: "Top", y: 0.90, height: 0.02)

        let rows = sut.clusterIntoRows([low, high, mid])
        #expect(rows.count == 3)
        #expect(rows[0].combinedText == "Top")
        #expect(rows[1].combinedText == "Middle")
        #expect(rows[2].combinedText == "Bottom")
    }

    // MARK: - Many blocks in a single row

    @Test func clusterIntoRows_withManyBlocksSameRow_mergesAll() {
        let blocks = (0..<5).map { i in
            makeBlock(text: "Word\(i)", x: CGFloat(i) * 0.15, y: 0.50, height: 0.02)
        }

        let rows = sut.clusterIntoRows(blocks)
        #expect(rows.count == 1)
        #expect(rows[0].blocks.count == 5)
    }

    // MARK: - Row averageY

    @Test func row_averageY_isPopulatedFromBlocks() {
        let block = makeBlock(text: "Test", y: 0.75, height: 0.02)
        let rows = sut.clusterIntoRows([block])
        #expect(rows.count == 1)
        // averageY should be near the midY of the block (0.75 + 0.01 = 0.76 midY)
        let expectedMidY = block.boundingBox.midY
        #expect(abs(rows[0].averageY - expectedMidY) < 0.01)
    }
}

/*
Tests generated:
1. clusterIntoRows_withEmptyArray_returnsEmptyArray - Empty input returns empty
2. clusterIntoRows_withSingleBlock_returnsSingleRow - Single block produces one row
3. clusterIntoRows_withBlocksSameY_returnsSingleRow - Same Y blocks merge into one row
4. clusterIntoRows_withBlocksDifferentY_returnsMultipleRows - Different Y blocks separate
5. combinedText_sortsBlocksLeftToRight - Left-to-right sorting within row
6. clusterIntoRows_withMixedRows_groupsCorrectly - Multi-block rows group correctly
7. clusterIntoRows_withTinyVerticalDifference_mergesIntoSameRow - Within threshold merges
8. clusterIntoRows_withLargeVerticalDifference_splitsIntoRows - Beyond threshold splits
9. clusterIntoRows_withUnsortedInput_sortsTopToBottom - Output order is top-to-bottom
10. clusterIntoRows_withManyBlocksSameRow_mergesAll - Many blocks same row merge
11. row_averageY_isPopulatedFromBlocks - averageY matches block position

Cases NOT covered:
- RowClusterer imports Vision, but only TextBlock (our own struct) is used in clusterIntoRows
- Threshold edge case at exact boundary is hard to test deterministically due to floating-point
*/

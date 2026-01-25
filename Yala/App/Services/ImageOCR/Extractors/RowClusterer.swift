//
//  RowClusterer.swift
//  Yala
//
//  Clusters text observations into rows based on vertical proximity
//

import Foundation
import Vision

/// Clusters OCR text blocks into horizontal rows based on vertical position
struct RowClusterer {

    /// A cluster of text blocks that belong to the same horizontal row
    struct Row {
        let blocks: [OCRResult.TextBlock]
        let averageY: CGFloat

        /// Combined text from all blocks in the row, sorted left-to-right
        var combinedText: String {
            blocks
                .sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .map { $0.text }
                .joined(separator: " ")
        }
    }

    /// Cluster text blocks into rows based on vertical proximity
    /// - Parameter textBlocks: Array of text blocks from OCR
    /// - Returns: Array of rows, each containing blocks from the same horizontal line
    func clusterIntoRows(_ textBlocks: [OCRResult.TextBlock]) -> [Row] {
        guard !textBlocks.isEmpty else { return [] }

        // 1. Sort blocks by vertical position (top to bottom)
        // Vision coordinates: origin is bottom-left, so higher Y = higher on screen
        let sortedBlocks = textBlocks.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }

        // 2. Cluster blocks into rows
        var rows: [Row] = []
        var currentRowBlocks: [OCRResult.TextBlock] = []
        var currentRowY: CGFloat = sortedBlocks[0].boundingBox.midY

        for block in sortedBlocks {
            let blockY = block.boundingBox.midY
            let verticalDistance = abs(currentRowY - blockY)

            // Threshold: if distance > 15% of average block height, it's a new row
            let threshold: CGFloat = 0.15
            let avgHeight = (block.boundingBox.height + (currentRowBlocks.last?.boundingBox.height ?? block.boundingBox.height)) / 2
            let maxDistance = avgHeight * threshold

            if verticalDistance <= maxDistance && !currentRowBlocks.isEmpty {
                // Same row
                currentRowBlocks.append(block)
                // Update average Y
                currentRowY = (currentRowY + blockY) / 2
            } else {
                // New row - save previous row if not empty
                if !currentRowBlocks.isEmpty {
                    rows.append(Row(blocks: currentRowBlocks, averageY: currentRowY))
                }
                // Start new row
                currentRowBlocks = [block]
                currentRowY = blockY
            }
        }

        // Add last row
        if !currentRowBlocks.isEmpty {
            rows.append(Row(blocks: currentRowBlocks, averageY: currentRowY))
        }

        return rows
    }
}

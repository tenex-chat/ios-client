//
// DocumentDiff.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - DiffLineType

/// Type of change for a diff line
public enum DiffLineType: Sendable {
    case unchanged
    case added
    case removed
}

// MARK: - DiffLine

/// Represents a single line in a diff result
public struct DiffLine: Identifiable, Sendable {
    public let id: UUID
    public let type: DiffLineType
    public let content: String
    public let oldLineNumber: Int?
    public let newLineNumber: Int?

    public init(
        type: DiffLineType,
        content: String,
        oldLineNumber: Int?,
        newLineNumber: Int?
    ) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}

// MARK: - DiffStats

/// Statistics about a diff
public struct DiffStats: Sendable {
    public let additions: Int
    public let deletions: Int
    public let unchanged: Int

    public var totalChanges: Int { additions + deletions }

    public init(additions: Int, deletions: Int, unchanged: Int) {
        self.additions = additions
        self.deletions = deletions
        self.unchanged = unchanged
    }
}

// MARK: - DocumentDiff

/// Computes line-by-line differences between document versions
/// Uses Swift's built-in CollectionDifference (Myers algorithm)
public enum DocumentDiff {
    /// Compute the diff between two document contents
    public static func compute(old: String, new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        let changeMaps = buildChangeMaps(oldLines: oldLines, newLines: newLines)
        return buildDiffLines(
            oldLines: oldLines,
            newLines: newLines,
            removed: changeMaps.removed,
            inserted: changeMaps.inserted
        )
    }

    /// Compute statistics for a diff
    public static func stats(from diffLines: [DiffLine]) -> DiffStats {
        var additions = 0
        var deletions = 0
        var unchanged = 0

        for line in diffLines {
            switch line.type {
            case .added:
                additions += 1
            case .removed:
                deletions += 1
            case .unchanged:
                unchanged += 1
            }
        }

        return DiffStats(additions: additions, deletions: deletions, unchanged: unchanged)
    }

    /// Compute diff asynchronously for large documents
    public static func computeAsync(old: String, new: String) async -> [DiffLine] {
        await Task.detached(priority: .userInitiated) {
            compute(old: old, new: new)
        }.value
    }

    // MARK: - Private Helpers

    private static func buildChangeMaps(
        oldLines: [String],
        newLines: [String]
    ) -> (removed: [Int: String], inserted: [Int: String]) {
        let difference = newLines.difference(from: oldLines)

        var removedByOffset: [Int: String] = [:]
        var insertedByOffset: [Int: String] = [:]

        for change in difference {
            switch change {
            case let .remove(offset, element, _):
                removedByOffset[offset] = element
            case let .insert(offset, element, _):
                insertedByOffset[offset] = element
            }
        }

        return (removedByOffset, insertedByOffset)
    }

    private static func buildDiffLines(
        oldLines: [String],
        newLines: [String],
        removed: [Int: String],
        inserted: [Int: String]
    ) -> [DiffLine] {
        var result: [DiffLine] = []
        var oldIdx = 0
        var newIdx = 0

        while oldIdx < oldLines.count || newIdx < newLines.count {
            if let removedLine = removed[oldIdx] {
                result.append(makeLine(.removed, removedLine, oldIdx + 1, nil))
                oldIdx += 1
            } else if let insertedLine = inserted[newIdx] {
                result.append(makeLine(.added, insertedLine, nil, newIdx + 1))
                newIdx += 1
            } else if oldIdx < oldLines.count, newIdx < newLines.count {
                result.append(makeLine(.unchanged, oldLines[oldIdx], oldIdx + 1, newIdx + 1))
                oldIdx += 1
                newIdx += 1
            } else {
                break
            }
        }

        return result
    }

    private static func makeLine(
        _ type: DiffLineType,
        _ content: String,
        _ oldNum: Int?,
        _ newNum: Int?
    ) -> DiffLine {
        DiffLine(type: type, content: content, oldLineNumber: oldNum, newLineNumber: newNum)
    }
}

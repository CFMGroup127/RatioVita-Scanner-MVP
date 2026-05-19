import Foundation

/// Reads **ZIP** archives written by `ZipStoreWriter` (compression method **STORED / 0** only).
enum ZipStoreReader {
    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50

    enum ZipReadError: Error, LocalizedError {
        case emptyArchive
        case endOfCentralDirectoryNotFound
        case unsupportedCompression(UInt16)
        case invalidCentralDirectory
        case invalidLocalHeader
        case truncatedFile(String)

        var errorDescription: String? {
            switch self {
                case .emptyArchive: "Archive is empty."
                case .endOfCentralDirectoryNotFound: "Could not find ZIP end-of-central-directory record."
                case let .unsupportedCompression(m): "Unsupported compression method \(m) (only STORED is supported)."
                case .invalidCentralDirectory: "ZIP central directory is malformed."
                case .invalidLocalHeader: "ZIP local file header is malformed."
                case let .truncatedFile(name): "Truncated entry: \(name)"
            }
        }
    }

    private struct EndOfCentralDirectory {
        let totalEntries: UInt16
        let centralDirectorySize: UInt32
        let centralDirectoryOffset: UInt32
    }

    /// Extracts every file from `zipData` into `destinationDirectory` (created if needed).
    static func unzip(data zipData: Data, to destinationDirectory: URL) throws {
        guard !zipData.isEmpty else { throw ZipReadError.emptyArchive }
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let eocd = try locateEndOfCentralDirectory(in: zipData)
        var cursor = Int(eocd.centralDirectoryOffset)
        let centralEnd = cursor + Int(eocd.centralDirectorySize)

        for _ in 0..<Int(eocd.totalEntries) {
            guard cursor + 46 <= zipData.count else { throw ZipReadError.invalidCentralDirectory }
            guard zipData.readUInt32LE(cursor) == centralHeaderSignature else { throw ZipReadError.invalidCentralDirectory }

            let cenMethod = zipData.readUInt16LE(cursor + 10)
            guard cenMethod == 0 else { throw ZipReadError.unsupportedCompression(cenMethod) }

            let fnLen = Int(zipData.readUInt16LE(cursor + 28))
            let extraLen = Int(zipData.readUInt16LE(cursor + 30))
            let commentLen = Int(zipData.readUInt16LE(cursor + 32))
            let localOffset = Int(zipData.readUInt32LE(cursor + 42))
            let recordSize = 46 + fnLen + extraLen + commentLen
            guard cursor + recordSize <= zipData.count else { throw ZipReadError.invalidCentralDirectory }

            guard let nameData = String(
                data: zipData.subdata(in: cursor + 46..<cursor + 46 + fnLen),
                encoding: .utf8
            ) else {
                throw ZipReadError.invalidCentralDirectory
            }
            cursor += recordSize

            guard nameData.last != "/", !nameData.isEmpty else { continue }

            try extractStoredFile(
                named: nameData,
                zipData: zipData,
                localHeaderOffset: localOffset,
                into: destinationDirectory
            )
        }

        if cursor != centralEnd {
            // Non-fatal: some tools append bytes after the central directory.
            _ = centralEnd
        }
    }

    private static func locateEndOfCentralDirectory(in data: Data) throws -> EndOfCentralDirectory {
        let sigBytes: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        var idx = data.count - 22
        let minScan = max(0, data.count - 65536 - 22)
        while idx >= minScan {
            if data[idx] == sigBytes[0],
               idx + 3 < data.count,
               data[idx + 1] == sigBytes[1],
               data[idx + 2] == sigBytes[2],
               data[idx + 3] == sigBytes[3]
            {
                let commentLen = Int(data.readUInt16LE(idx + 20))
                guard idx + 22 + commentLen <= data.count else {
                    idx -= 1
                    continue
                }
                let totalEntries = data.readUInt16LE(idx + 10)
                let centralSize = data.readUInt32LE(idx + 12)
                let centralOffset = data.readUInt32LE(idx + 16)
                return EndOfCentralDirectory(
                    totalEntries: totalEntries,
                    centralDirectorySize: centralSize,
                    centralDirectoryOffset: centralOffset
                )
            }
            idx -= 1
        }
        throw ZipReadError.endOfCentralDirectoryNotFound
    }

    private static func extractStoredFile(
        named relativePath: String,
        zipData: Data,
        localHeaderOffset: Int,
        into destinationDirectory: URL
    ) throws {
        guard localHeaderOffset + 30 <= zipData.count else { throw ZipReadError.invalidLocalHeader }
        guard zipData.readUInt32LE(localHeaderOffset) == localHeaderSignature else { throw ZipReadError.invalidLocalHeader }

        let method = zipData.readUInt16LE(localHeaderOffset + 8)
        guard method == 0 else { throw ZipReadError.unsupportedCompression(method) }

        let comp = zipData.readUInt32LE(localHeaderOffset + 18)
        let uncomp = zipData.readUInt32LE(localHeaderOffset + 22)
        guard comp == uncomp else { throw ZipReadError.unsupportedCompression(method) }

        let fnLen = Int(zipData.readUInt16LE(localHeaderOffset + 26))
        let extraLen = Int(zipData.readUInt16LE(localHeaderOffset + 28))
        let dataStart = localHeaderOffset + 30 + fnLen + extraLen
        let dataEnd = dataStart + Int(uncomp)
        guard dataEnd <= zipData.count else { throw ZipReadError.truncatedFile(relativePath) }
        let payload = zipData.subdata(in: dataStart..<dataEnd)

        let outURL = destinationDirectory.appendingPathComponent(relativePath)
        let parent = outURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: outURL.path) {
            try FileManager.default.removeItem(at: outURL)
        }
        try payload.write(to: outURL, options: .atomic)
    }
}

extension Data {
    fileprivate func readUInt16LE(_ offset: Int) -> UInt16 {
        precondition(offset + 2 <= count)
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    fileprivate func readUInt32LE(_ offset: Int) -> UInt32 {
        precondition(offset + 4 <= count)
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}

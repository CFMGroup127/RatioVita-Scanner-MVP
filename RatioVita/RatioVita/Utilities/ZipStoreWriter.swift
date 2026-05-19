import Foundation

/// Minimal **ZIP (compression method STORED)** writer for bundling a flat folder tree on all platforms.
/// Suitable for JPEG + SQLite payloads that are already compressed or compact.
enum ZipStoreWriter {
    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50
    private static let endCentralSignature: UInt32 = 0x0605_4B50

    /// Recursively zips `rootDirectory` into `destinationURL` (file must not exist, or is replaced).
    static func zipDirectoryContents(rootDirectory: URL, destinationURL: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        fm.createFile(atPath: destinationURL.path, contents: nil)

        let handle = try FileHandle(forWritingTo: destinationURL)
        defer { try? handle.close() }

        var centralEntries: [CentralEntry] = []
        var offset: UInt32 = 0

        guard let enumerator = fm.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ZipStoreError.enumerationFailed
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let vals = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard vals.isRegularFile == true else { continue }

            let rel = relativePath(from: rootDirectory, to: fileURL)
            guard !rel.isEmpty, rel != "/" else { continue }
            let data = try Data(contentsOf: fileURL)
            let crc = crc32(data)

            let nameData = Data(rel.utf8)
            let localHeader = buildLocalHeader(
                crc: crc,
                uncompressedSize: UInt32(data.count),
                filenameLength: UInt16(nameData.count),
                extraLength: 0
            )
            try write(handle, localHeader)
            try write(handle, nameData)
            try write(handle, data)

            centralEntries.append(
                CentralEntry(
                    relativePath: rel,
                    crc: crc,
                    size: UInt32(data.count),
                    localHeaderOffset: offset
                )
            )
            offset += UInt32(localHeader.count + nameData.count + data.count)
        }

        let centralStart = offset
        for entry in centralEntries {
            let nameData = Data(entry.relativePath.utf8)
            let central = buildCentralDirectoryRecord(
                crc: entry.crc,
                uncompressedSize: entry.size,
                compressedSize: entry.size,
                filenameLength: UInt16(nameData.count),
                extraLength: 0,
                commentLength: 0,
                localHeaderOffset: entry.localHeaderOffset
            )
            try write(handle, central)
            try write(handle, nameData)
            offset += UInt32(central.count + nameData.count)
        }

        let centralSize = offset - centralStart
        let eocd = buildEndOfCentralDirectory(
            diskNumber: 0,
            centralDirDisk: 0,
            entriesOnDisk: UInt16(centralEntries.count),
            totalEntries: UInt16(centralEntries.count),
            centralDirectorySize: centralSize,
            centralDirectoryOffset: centralStart,
            commentLength: 0
        )
        try write(handle, eocd)
    }

    private struct CentralEntry {
        let relativePath: String
        let crc: UInt32
        let size: UInt32
        let localHeaderOffset: UInt32
    }

    enum ZipStoreError: Error {
        case enumerationFailed
    }

    private static func relativePath(from root: URL, to file: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        let filePath = file.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return file.lastPathComponent }
        return String(filePath.dropFirst(rootPath.count))
    }

    private static func write(_ handle: FileHandle, _ data: Data) throws {
        try handle.write(contentsOf: data)
    }

    private static func buildLocalHeader(
        crc: UInt32,
        uncompressedSize: UInt32,
        filenameLength: UInt16,
        extraLength: UInt16
    ) -> Data {
        var d = Data()
        d.appendUInt32(localHeaderSignature)
        d.appendUInt16(20) // version needed
        d.appendUInt16(0) // flags
        d.appendUInt16(0) // STORED
        d.appendUInt16(0) // mod time
        d.appendUInt16(0) // mod date
        d.appendUInt32(crc)
        d.appendUInt32(uncompressedSize) // compressed
        d.appendUInt32(uncompressedSize) // uncompressed
        d.appendUInt16(filenameLength)
        d.appendUInt16(extraLength)
        return d
    }

    private static func buildCentralDirectoryRecord(
        crc: UInt32,
        uncompressedSize: UInt32,
        compressedSize: UInt32,
        filenameLength: UInt16,
        extraLength: UInt16,
        commentLength: UInt16,
        localHeaderOffset: UInt32
    ) -> Data {
        var d = Data()
        d.appendUInt32(centralHeaderSignature)
        d.appendUInt16(0x0314) // version made by (Unix, 2.0)
        d.appendUInt16(20) // version needed
        d.appendUInt16(0) // flags
        d.appendUInt16(0) // STORED
        d.appendUInt16(0)
        d.appendUInt16(0)
        d.appendUInt32(crc)
        d.appendUInt32(compressedSize)
        d.appendUInt32(uncompressedSize)
        d.appendUInt16(filenameLength)
        d.appendUInt16(extraLength)
        d.appendUInt16(commentLength)
        d.appendUInt16(0) // disk start
        d.appendUInt16(0) // internal attrs
        d.appendUInt32(0) // external attrs
        d.appendUInt32(localHeaderOffset)
        return d
    }

    private static func buildEndOfCentralDirectory(
        diskNumber: UInt16,
        centralDirDisk: UInt16,
        entriesOnDisk: UInt16,
        totalEntries: UInt16,
        centralDirectorySize: UInt32,
        centralDirectoryOffset: UInt32,
        commentLength: UInt16
    ) -> Data {
        var d = Data()
        d.appendUInt32(endCentralSignature)
        d.appendUInt16(diskNumber)
        d.appendUInt16(centralDirDisk)
        d.appendUInt16(entriesOnDisk)
        d.appendUInt16(totalEntries)
        d.appendUInt32(centralDirectorySize)
        d.appendUInt32(centralDirectoryOffset)
        d.appendUInt16(commentLength)
        return d
    }

    // MARK: - CRC32 (IEEE)

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = (crc >> 8) ^ crcTable[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        return ~crc
    }

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }
}

extension Data {
    fileprivate mutating func appendUInt16(_ v: UInt16) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    fileprivate mutating func appendUInt32(_ v: UInt32) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}

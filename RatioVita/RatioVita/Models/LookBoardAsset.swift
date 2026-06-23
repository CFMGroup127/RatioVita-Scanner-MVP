import Foundation

/// Visual look board ingested by VitaLogic and streamed to crew devices.
struct LookBoardAsset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let sourceFilename: String
    let tags: [String]
    let thumbnailURL: URL?
    let fullImageURL: URL?
    let notes: String?

    init(
        id: String,
        title: String,
        sourceFilename: String,
        tags: [String],
        thumbnailURL: URL?,
        fullImageURL: URL?,
        notes: String?
    ) {
        self.id = id
        self.title = title
        self.sourceFilename = sourceFilename
        self.tags = tags
        self.thumbnailURL = thumbnailURL
        self.fullImageURL = fullImageURL
        self.notes = notes
    }

    var primaryGroupTag: String {
        tags.first ?? "Uncategorized"
    }

    var displayTags: [String] {
        tags.map { tag in
            tag.hasPrefix("#") ? tag : "#\(tag)"
        }
    }

    static func previewSamples() -> [LookBoardAsset] {
        [
            LookBoardAsset(
                id: "male-detectives",
                title: "Male Detectives",
                sourceFilename: "IMG_0034 (1).jpeg",
                tags: ["MaleDetectives", "Suits", "Fittings", "Cast", "EstablishedLooks"],
                thumbnailURL: nil,
                fullImageURL: nil,
                notes: "Established detective block — verify suits on floor."
            ),
            LookBoardAsset(
                id: "female-detectives",
                title: "Female Detectives",
                sourceFilename: "IMG_0036 (1).jpeg",
                tags: ["FemaleDetectives", "Suits", "Fittings", "Cast", "EstablishedLooks"],
                thumbnailURL: nil,
                fullImageURL: nil,
                notes: "Pair with male detective palette for continuity."
            ),
            LookBoardAsset(
                id: "skateboarders-khalid",
                title: "Skateboarders & Khalid Homies",
                sourceFilename: "IMG_0039.jpeg",
                tags: ["Skateboarders", "KhalidHomies", "Background", "NoLogos", "NoGraphics"],
                thumbnailURL: nil,
                fullImageURL: nil,
                notes: "Dispatch to BG agent — no logos or graphics on wardrobe."
            ),
        ]
    }
}

#if canImport(FirebaseFirestore)
extension LookBoardAsset {
    init?(documentId: String, data: [String: Any]) {
        let title = (data["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = (data["sourceFilename"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (title?.isEmpty == false ? title : filename) ?? documentId

        var parsedTags = (data["tags"] as? [String]) ?? []
        if parsedTags.isEmpty, let hashtagField = data["metadataTags"] as? String {
            parsedTags = hashtagField
                .split(whereSeparator: { $0.isWhitespace || $0 == "," })
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "#")) }
                .filter { !$0.isEmpty }
        }

        let thumb = (data["thumbnailURL"] as? String).flatMap(URL.init(string:))
            ?? (data["thumbnailUrl"] as? String).flatMap(URL.init(string:))
        let full = (data["fullImageURL"] as? String).flatMap(URL.init(string:))
            ?? (data["imageURL"] as? String).flatMap(URL.init(string:))
            ?? (data["imageUrl"] as? String).flatMap(URL.init(string:))

        self.init(
            id: documentId,
            title: resolvedTitle,
            sourceFilename: filename ?? resolvedTitle,
            tags: parsedTags,
            thumbnailURL: thumb,
            fullImageURL: full,
            notes: data["notes"] as? String
        )
    }
}
#endif

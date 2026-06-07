import Foundation
import SwiftData

@Model
final class CrewFeedbackTicket {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var originatingDepartment: String
    var userSovereigntyLevel: String
    var userNotes: String
    var currentViewContext: String
    var devicePlatform: String
    var isExecuted: Bool
    var remoteDispatchID: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        originatingDepartment: String,
        userSovereigntyLevel: String,
        userNotes: String,
        currentViewContext: String,
        devicePlatform: String = "",
        isExecuted: Bool = false,
        remoteDispatchID: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originatingDepartment = originatingDepartment
        self.userSovereigntyLevel = userSovereigntyLevel
        self.userNotes = userNotes
        self.currentViewContext = currentViewContext
        self.devicePlatform = devicePlatform
        self.isExecuted = isExecuted
        self.remoteDispatchID = remoteDispatchID
    }
}

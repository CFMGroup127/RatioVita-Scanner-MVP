import Foundation
import SwiftData

@MainActor
enum MasterScriptBreakdownEngine {
    @discardableResult
    static func ingestScene(
        context: ModelContext,
        sceneNumber: Int,
        location: String,
        description: String,
        characters: [String],
        productionTitle: String
    ) throws -> ScriptSceneBreakdown {
        let scene = ScriptSceneBreakdown(
            sceneNumber: sceneNumber,
            locationSetting: location,
            sceneDescription: description,
            characters: characters,
            productionTitle: productionTitle
        )
        context.insert(scene)
        propagateDepartmentStubs(scene: scene)
        try context.save()
        return scene
    }

    private static func propagateDepartmentStubs(scene: ScriptSceneBreakdown) {
        if scene.sceneDescription.lowercased().contains("van") || scene.sceneDescription.lowercased()
            .contains("truck")
        {
            scene.setNote("Picture car / unit move flagged", department: .transport)
        }
        if scene.sceneDescription.lowercased().contains("uniform") || scene.sceneDescription.lowercased()
            .contains("costume")
        {
            scene.setNote("Continuity wardrobe card required", department: .costume)
        }
        if scene.sceneDescription.lowercased().contains("desk") || scene.sceneDescription.lowercased().contains("set") {
            scene.setNote("Set dec asset line", department: .artSetDec)
        }
    }
}

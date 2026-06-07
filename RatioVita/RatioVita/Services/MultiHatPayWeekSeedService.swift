import Foundation
import SwiftData

/// Injects the **multi-hat pay week** stress-test production (Mon–Sun, 4+ departments, split ACTRA days).
enum MultiHatPayWeekSeedService {
    static let productionTitle = "RatioVita Multi-Hat Test Week"
    /// Bump when tier/day payload changes so **Load** can rebuild incomplete seeds.
    static let seedVersion = "v2026-05-20-full"

    private static let seedMarker = "[RatioVitaSeed:"

    @MainActor
    static func seed(modelContext: ModelContext, forceReload: Bool = true) throws -> ProductionProject {
        var fd = FetchDescriptor<ProductionProject>(
            predicate: #Predicate { $0.title == productionTitle }
        )
        fd.fetchLimit = 1

        let project: ProductionProject
        if let existing = try modelContext.fetch(fd).first {
            project = existing
            if forceReload || !isCurrentSeed(project) {
                clearPayrollChildren(project, modelContext: modelContext)
            } else {
                return existing
            }
        } else {
            project = ProductionProject(
                title: productionTitle,
                notes: seedNotes,
                crewOccupationTitle: "Costume Supervisor",
                defaultKitPhoneRateCAD: 5,
                defaultKitLaptopRateCAD: 5,
                defaultKitTabletRateCAD: 5,
                defaultKitVehicleRateCAD: 65,
                payrollVehicleKitEnabled: true,
                payrollDepartment: "Costumes",
                payrollProductionCompany: "Netflix",
                payrollLoanoutCompany: "Bespoke Craft and Catering Services Inc.",
                payrollUnionName: "IA 873",
                payrollUnionID: "873-TEST",
                payrollResidencyStatusRaw: PayrollComplianceProfile.ResidencyTier.resident.rawValue,
                payrollGuildStatusRaw: PayrollComplianceProfile.GuildTier.member.rawValue,
                payrollAutoStampCrewInitials: true,
                payrollCrewInitialsOverride: "CM"
            )
            modelContext.insert(project)
        }

        applyProjectProfile(project, modelContext: modelContext)
        insertRateTiers(project: project, modelContext: modelContext)
        insertCrewDays(project: project, modelContext: modelContext)

        try modelContext.save()
        return project
    }

    // MARK: - Profile

    private static var seedNotes: String {
        "\(seedMarker) \(seedVersion)] Collin Morris · Bespoke Craft and Catering Services Inc. · "
            + "Mon–Sun May 18–24, 2026 · UTM weekend · Wed/Thu concurrent Costumes + ACTRA BG."
    }

    private static func isCurrentSeed(_ project: ProductionProject) -> Bool {
        guard let notes = project.notes, notes.contains(seedMarker) else { return false }
        guard notes.contains(seedVersion) else { return false }
        return project.laborPositionRates.count >= 7 && project.crewTimecardDays.count >= 10
    }

    private static func applyProjectProfile(_ project: ProductionProject, modelContext: ModelContext) {
        project.notes = seedNotes
        project.crewOccupationTitle = "Costume Supervisor"
        project.payrollDepartment = "Costumes"
        project.payrollProductionCompany = "Netflix"
        project.payrollLoanoutCompany = "Bespoke Craft and Catering Services Inc."
        project.payrollUnionName = "IA 873"
        project.payrollUnionID = "873-TEST"
        project.payrollResidencyStatusRaw = PayrollComplianceProfile.ResidencyTier.resident.rawValue
        project.payrollGuildStatusRaw = PayrollComplianceProfile.GuildTier.member.rawValue
        project.payrollAutoStampCrewInitials = true
        project.payrollCrewInitialsOverride = "CM"
        project.payrollVehicleKitEnabled = true
        project.defaultKitPhoneRateCAD = 5
        project.defaultKitLaptopRateCAD = 5
        project.defaultKitTabletRateCAD = 5
        project.defaultKitVehicleRateCAD = 65
        project.defaultKitPhoneWeeklyRateCAD = 25
        project.defaultKitLaptopWeeklyRateCAD = 25
        project.defaultKitTabletWeeklyRateCAD = 25
        project.updatedAt = .now

        if project.businessEntity == nil {
            var entityFD = FetchDescriptor<BusinessEntity>()
            entityFD.fetchLimit = 50
            let entities = (try? modelContext.fetch(entityFD)) ?? []
            if let match = entities.first(where: {
                $0.legalName.localizedCaseInsensitiveContains("Bespoke Craft")
            }) {
                project.businessEntity = match
            }
        }
    }

    private static func clearPayrollChildren(_ project: ProductionProject, modelContext: ModelContext) {
        for day in project.crewTimecardDays {
            modelContext.delete(day)
        }
        for rate in project.laborPositionRates {
            modelContext.delete(rate)
        }
        for checkout in project.kitCheckouts {
            modelContext.delete(checkout)
        }
    }

    // MARK: - Rate tiers

    private struct TierSeed {
        let month: Int
        let day: Int
        let department: String
        let occupation: String
        let base: Decimal
        let premium: Decimal
        let allowances: String?
    }

    private static func insertRateTiers(project: ProductionProject, modelContext: ModelContext) {
        let tiers: [TierSeed] = [
            TierSeed(
                month: 5, day: 18, department: "Costumes", occupation: "Costume Supervisor",
                base: 56, premium: 0,
                allowances: "cell|5\nlaptop|5\ntablet|5"
            ),
            TierSeed(
                month: 5, day: 19, department: "Costumes", occupation: "Assistant Costume Designer",
                base: 56, premium: 0,
                allowances: "cell|5\nlaptop|5\ntablet|5"
            ),
            TierSeed(
                month: 5, day: 20, department: "Costumes", occupation: "Costume Set Supervisor",
                base: 56, premium: 0,
                allowances: "cell|5\nlaptop|5\ntablet|5\nkit|12"
            ),
            TierSeed(
                month: 5, day: 20, department: "Performers", occupation: "BG Tanker Driver (Special Skills)",
                base: 45, premium: 12,
                allowances: nil
            ),
            TierSeed(
                month: 5, day: 22, department: "Transport", occupation: "Truck Supervisor",
                base: 52, premium: 8,
                allowances: "vehicle|65\ncell|5"
            ),
            TierSeed(
                month: 5, day: 23, department: "Locations", occupation: "Set PA / Lockup Support",
                base: 48, premium: 0,
                allowances: "cell|5"
            ),
            TierSeed(
                month: 5, day: 24, department: "Assistant Directors", occupation: "3rd AD / Background Marshall",
                base: 50, premium: 0,
                allowances: "cell|5\ntablet|5"
            ),
        ]

        let cal = Calendar.current
        for tier in tiers {
            let effective = cal.date(from: DateComponents(year: 2026, month: tier.month, day: tier.day)) ?? .now
            let rate = ShowLaborPositionRate(
                effectiveFromDate: cal.startOfDay(for: effective),
                occupationTitle: tier.occupation,
                baseHourlyRateCAD: tier.base,
                premiumHourlyRateCAD: tier.premium,
                department: tier.department,
                allowanceNotes: tier.allowances,
                productionProject: project
            )
            modelContext.insert(rate)
        }
    }

    // MARK: - Crew days

    private struct DaySeed {
        let month: Int
        let day: Int
        let department: String
        let occupation: String
        let unit: String
        let travelLeaveHour: Int?
        let callHour: Int
        let callMinute: Int
        let meal1StartHour: Int?
        let meal1EndHour: Int?
        let meal2StartHour: Int?
        let meal2EndHour: Int?
        let wrapHour: Int
        let wrapMinute: Int
        let travelHomeHour: Int?
        let phone: Bool
        let laptop: Bool
        let tablet: Bool
        let vehicle: Bool
        let notes: String?
    }

    private static func insertCrewDays(project: ProductionProject, modelContext: ModelContext) {
        let cal = Calendar.current
        func sod(_ month: Int, _ day: Int) -> Date {
            cal.startOfDay(for: cal.date(from: DateComponents(year: 2026, month: month, day: day)) ?? .now)
        }
        func stamp(_ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
            cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .now
        }

        let days: [DaySeed] = [
            // Mon — Costumes
            DaySeed(
                month: 5, day: 18, department: "Costumes", occupation: "Costume Supervisor", unit: "Main Unit",
                travelLeaveHour: 6, callHour: 7, callMinute: 0, meal1StartHour: 12, meal1EndHour: 13,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 19, wrapMinute: 0, travelHomeHour: 20,
                phone: true, laptop: true, tablet: true, vehicle: false,
                notes: "Mon · Main Unit prep / truck load-in."
            ),
            // Tue — Costumes
            DaySeed(
                month: 5, day: 19, department: "Costumes", occupation: "Assistant Costume Designer", unit: "Main Unit",
                travelLeaveHour: 6, callHour: 7, callMinute: 0, meal1StartHour: 12, meal1EndHour: 13,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 19, wrapMinute: 0, travelHomeHour: 20,
                phone: true, laptop: true, tablet: true, vehicle: false,
                notes: "Tue · Main Unit coordination."
            ),
            // Wed — Costumes (morning) + Performers (ACTRA afternoon) — concurrent streams
            DaySeed(
                month: 5, day: 20, department: "Costumes", occupation: "Costume Set Supervisor", unit: "Main Splinter",
                travelLeaveHour: 5, callHour: 6, callMinute: 0, meal1StartHour: 11, meal1EndHour: 12,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 12, wrapMinute: 30, travelHomeHour: nil,
                phone: true, laptop: true, tablet: true, vehicle: false,
                notes: "[EP Crew] Wed AM — set supervisor until ACTRA pull (continuous day)."
            ),
            DaySeed(
                month: 5, day: 20, department: "Performers", occupation: "BG Tanker Driver (Special Skills)",
                unit: "Main Splinter",
                travelLeaveHour: nil, callHour: 13, callMinute: 0, meal1StartHour: 17, meal1EndHour: 18,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 19, wrapMinute: 0, travelHomeHour: 21,
                phone: true, laptop: false, tablet: false, vehicle: false,
                notes: "[ACTRA Voucher] Wed PM — stunt tanker; overlaps Costumes clock (do not log off)."
            ),
            // Thu — split hats
            DaySeed(
                month: 5, day: 21, department: "Costumes", occupation: "Costume Set Supervisor", unit: "Main Splinter",
                travelLeaveHour: 6, callHour: 7, callMinute: 0, meal1StartHour: 12, meal1EndHour: 13,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 13, wrapMinute: 30, travelHomeHour: nil,
                phone: true, laptop: true, tablet: true, vehicle: false,
                notes: "[EP Crew] Thu AM — continuity until skateboard stunt pull."
            ),
            DaySeed(
                month: 5, day: 21, department: "Performers", occupation: "BG Skateboard Stunt", unit: "Main Splinter",
                travelLeaveHour: nil, callHour: 14, callMinute: 0, meal1StartHour: 18, meal1EndHour: 19,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 20, wrapMinute: 0, travelHomeHour: 22,
                phone: true, laptop: false, tablet: false, vehicle: false,
                notes: "[ACTRA Voucher] Thu PM — special skills BG; return to wardrobe after wrap on set."
            ),
            // Fri — Transport
            DaySeed(
                month: 5, day: 22, department: "Transport", occupation: "Truck Supervisor", unit: "2nd Unit",
                travelLeaveHour: 5, callHour: 6, callMinute: 0, meal1StartHour: 12, meal1EndHour: 13,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 18, wrapMinute: 0, travelHomeHour: 19,
                phone: true, laptop: false, tablet: false, vehicle: true,
                notes: "Fri · Move wardrobe trucks toward UTM weekend footprint."
            ),
            // Sat — Locations (6th day)
            DaySeed(
                month: 5, day: 23, department: "Locations", occupation: "Set PA / Lockup Support",
                unit: "2nd Splinter · U of T Mississauga",
                travelLeaveHour: 7, callHour: 8, callMinute: 0, meal1StartHour: 13, meal1EndHour: 14,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 20, wrapMinute: 0, travelHomeHour: 21,
                phone: true, laptop: false, tablet: false, vehicle: false,
                notes: "Sat · 6th day premium · UTM location."
            ),
            // Sun — ADs (7th day)
            DaySeed(
                month: 5, day: 24, department: "Assistant Directors", occupation: "3rd AD / Background Marshall",
                unit: "2nd Splinter · U of T Mississauga",
                travelLeaveHour: 8, callHour: 9, callMinute: 0, meal1StartHour: 14, meal1EndHour: 15,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 21, wrapMinute: 0, travelHomeHour: 22,
                phone: true, laptop: false, tablet: true, vehicle: false,
                notes: "Sun · 7th day double premium · UTM · turnaround rest disruption test."
            ),
            // Reference long day (May 13 grid font / EP import QA)
            DaySeed(
                month: 5, day: 13, department: "Costumes", occupation: "Costume Coordinator", unit: "Main Unit",
                travelLeaveHour: 3, callHour: 4, callMinute: 0, meal1StartHour: 14, meal1EndHour: 15,
                meal2StartHour: nil, meal2EndHour: nil, wrapHour: 23, wrapMinute: 48, travelHomeHour: 1,
                phone: true, laptop: true, tablet: false, vehicle: false,
                notes: "Reference row — May 13 long day (04:00 call, 23:48 wrap)."
            ),
        ]

        for seed in days {
            let workDate = sod(seed.month, seed.day)
            let call = stamp(seed.month, seed.day, hour: seed.callHour, minute: seed.callMinute)
            let travelLeave = seed.travelLeaveHour.map { stamp(seed.month, seed.day, hour: $0) }
            let meal1Start = seed.meal1StartHour.map { stamp(seed.month, seed.day, hour: $0) }
            let meal1End = seed.meal1EndHour.map { stamp(seed.month, seed.day, hour: $0) }
            let meal2Start = seed.meal2StartHour.map { stamp(seed.month, seed.day, hour: $0) }
            let meal2End = seed.meal2EndHour.map { stamp(seed.month, seed.day, hour: $0) }
            var wrap = stamp(seed.month, seed.day, hour: seed.wrapHour, minute: seed.wrapMinute)
            if seed.wrapHour < seed.callHour {
                wrap = cal.date(byAdding: .day, value: 1, to: wrap) ?? wrap
            }
            var travelHome: Date?
            if let th = seed.travelHomeHour {
                travelHome = stamp(seed.month, seed.day, hour: th)
                if th < seed.wrapHour {
                    travelHome = cal.date(byAdding: .day, value: 1, to: travelHome!) ?? travelHome
                }
            }

            let day = CrewTimecardDay(
                workDate: workDate,
                productionProject: project,
                travelLeaveZoneStart: travelLeave,
                callOnSet: call,
                department: seed.department,
                unitType: seed.unit,
                meal1Start: meal1Start,
                meal1End: meal1End,
                meal2Start: meal2Start,
                meal2End: meal2End,
                wrapOffSet: wrap,
                travelReturnHome: travelHome,
                occupationTitle: seed.occupation,
                ancillaryPhoneDays: seed.phone ? 1 : 0,
                ancillaryLaptopDays: seed.laptop ? 1 : 0,
                ancillaryTabletDays: seed.tablet ? 1 : 0,
                ancillaryVehicleDays: seed.vehicle ? 1 : 0,
                ancillaryPhoneRateCAD: seed.phone ? 5 : nil,
                ancillaryLaptopRateCAD: seed.laptop ? 5 : nil,
                ancillaryTabletRateCAD: seed.tablet ? 5 : nil,
                ancillaryVehicleRateCAD: seed.vehicle ? 65 : nil,
                notes: seed.notes
            )
            modelContext.insert(day)
        }
    }
}

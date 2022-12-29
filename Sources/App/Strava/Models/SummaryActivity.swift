//
//  SummaryActivity.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Vapor


struct SummaryActivity: Content {
    let athlete: Athlete
    let name: String
    let distance: Decimal
    let movingTime: Int
    let elapsedTime: Int
    let totalElevationGain: Int
    let sportType: SportType?
    let workoutType: Int?
    let id: Int
    let startDate: Date
    let startDateLocal: Date
    let timezone: String
    let utcOffset: Int
    let locationCity: String?
    let locationState: String?
    let locationCountry: String
    let achievementCount: Int
    let kudosCount: Int
    let commentCount: Int
    let athleteCount: Int
    let photoCount: Int
    let map: Map
    let trainer: Bool
    let commute: Bool
    let manual: Bool
    let `private`: Bool
    let visibility: String
    let flagged: Bool
    let gearId: String
    let startLatlng: [Decimal]
    let endLatlng: [Decimal]
    let averageSpeed: Decimal
    let maxSpeed: Decimal
    let averageCadence: Decimal
    let averageTemp: Int?
    let averageWatts: Decimal
    let maxWatts: Int
    let weightedAverageWatts: Int
    let kilojoules: Decimal
    let deviceWatts: Bool
    let hasHeartrate: Bool
    let averageHeartrate: Decimal
    let maxHeartrate: Decimal
    let heartrateOptOut: Bool
    let displayHideHeartrateOption: Bool
    let elevHigh: Decimal
    let elevLow: Decimal
    let uploadId: Int
    let uploadIdStr: String
    let externalId: String
    let fromAcceptedTag: Bool
    let prCount: Int
    let totalPhotoCount: Int
    let hasKudoed: Bool
    let sufferScore: Int
}

// MARK: - Athlete
struct Athlete: Codable {
    let id: Int
}

// MARK: - Map
struct Map: Codable {
    let id: String
    let summaryPolyline: String
}

enum SportType: String, Codable {
    case AlpineSki, BackcountrySki, Canoeing, Crossfit, EBikeRide, Elliptical, EMountainBikeRide, Golf, GravelRide, Handcycle, Hike, IceSkate, InlineSkate, Kayaking, Kitesurf, MountainBikeRide, NordicSki, Ride, RockClimbing, RollerSki, Rowing, Run, Sail, Skateboard, Snowboard, Snowshoe, Soccer, StairStepper, StandUpPaddling, Surfing, Swim, TrailRun, Velomobile, VirtualRide, VirtualRun, Walk, WeightTraining, Wheelchair, Windsurf, Workout, Yoga
}

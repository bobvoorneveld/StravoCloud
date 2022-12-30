//
//  StravaActivity.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Fluent
import Vapor
import FluentPostGIS

import Polyline
import GeoJSON


final class Location: Fields {
    @Field(key: "city")
    var city: String?

    @Field(key: "state")
    var state: String?

    @Field(key: "country")
    var country: String

    init() { }
}


final class StravaActivity: Model, Content {
    static let schema = "strava_activities"

    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Parent(key: "user_id")
    var user: User

    @Field(key: "strava_id")
    var stravaID: Int

    @Field(key: "name")
    var name: String
    
    @Field(key: "distance")
    var distance: Double
    
    @Field(key: "moving_time")
    var movingTime: Int
    
    @Field(key: "elapsed_time")
    var elapsedTime: Int
    
    @Field(key: "total_elevation_gain")
    var totalElevationGain: Double
    
    @Field(key: "sport_type")
    var sportType: String
    
    @Field(key: "workout_type")
    var workoutType: Int?
    
    @Field(key: "start_date")
    var startDate: Date
    
    @Field(key: "start_date_local")
    var startDateLocal: Date
    
    @Field(key: "timezone")
    var timezone: String
    
    @Field(key: "utc_offset")
    var utcOffset: Int
    
    @Group(key: "location")
    var location: Location
    
    @Field(key: "achievement_count")
    var achievementCount: Int
    
    @Field(key: "kudos_count")
    var kudosCount: Int
    
    @Field(key: "comment_count")
    var commentCount: Int
    
    @Field(key: "athlete_count")
    var athleteCount: Int

    @Field(key: "photo_count")
    var photoCount: Int
    
    @Field(key: "map_summary_polyline")
    var summaryPolyline: String
    
    @Field(key: "map_summary_line")
    var summaryLine: GeometricLineString2D

    @Field(key: "trainer")
    var trainer: Bool
    
    @Field(key: "commute")
    var commute: Bool
    
    @Field(key: "manual")
    var manual: Bool
    
    @Field(key: "private")
    var `private`: Bool
    
    @Field(key: "visibility")
    var visibility: String
    
    @Field(key: "flagged")
    var flagged: Bool
    
    @Field(key: "gear_id")
    var gearID: String?
    
    @Field(key: "start_location")
    var startLocation: GeometricPoint2D
    
    @Field(key: "end_location")
    var endLocation: GeometricPoint2D
    
    @Field(key: "average_speed")
    var averageSpeed: Double
    
    @Field(key: "max_speed")
    var maxSpeed: Double
    
    @Field(key: "average_cadence")
    var averageCadence: Double?
    
    @Field(key: "average_temp")
    var averageTemp: Int?
    
    @Field(key: "average_watts")
    var averageWatts: Double?
    
    @Field(key: "max_watts")
    var maxWatts: Int?
    
    @Field(key: "weighted_average_watts")
    var weightedAverageWatts: Int?
    
    @Field(key: "kilojoules")
    var kilojoules: Double?
    
    @Field(key: "device_watts")
    var deviceWatts: Bool
    
    @Field(key: "has_heartrate")
    var hasHeartrate: Bool
    
    @Field(key: "average_heartrate")
    var averageHeartrate: Double?

    @Field(key: "max_heartrate")
    var maxHeartrate: Double?

    @Field(key: "heartrate_opt_out")
    var heartrateOptOut: Bool

    @Field(key: "display_hide_heartrate_option")
    var displayHideHeartrateOption: Bool

    @Field(key: "elev_high")
    var elevationHigh: Double

    @Field(key: "elev_low")
    var elevationLow: Double

    @Field(key: "upload_id")
    var uploadID: Int
    
    @Field(key: "upload_id_str")
    var uploadIDStr: String

    @Field(key: "external_id")
    var externalID: String

    @Field(key: "from_accepted_tag")
    var fromAcceptedTag: Bool

    @Field(key: "pr_count")
    var prCount: Int

    @Field(key: "total_photo_count")
    var totalPhotoCount: Int

    @Field(key: "has_kudoed")
    var hasKudoed: Bool
    
    @Field(key: "suffer_score")
    var sufferScore: Int?

    init() { }

    init(id: UUID? = nil, activity: SummaryActivity, userID: User.IDValue) {
        self.id = id
        self.stravaID = activity.id
        self.name = activity.name
        self.distance = activity.distance
        self.movingTime = activity.movingTime
        self.elapsedTime = activity.elapsedTime
        self.totalElevationGain = activity.totalElevationGain
        self.sportType = activity.sportType!.rawValue
        self.workoutType = activity.workoutType
        self.startDate = activity.startDate
        self.startDateLocal = activity.startDateLocal
        self.timezone = activity.timezone
        self.utcOffset = activity.utcOffset
        self.location.city = activity.locationCity
        self.location.state = activity.locationState
        self.location.country = activity.locationCountry
        self.achievementCount = activity.achievementCount
        self.kudosCount = activity.kudosCount
        self.commentCount = activity.commentCount
        self.athleteCount = activity.commentCount
        self.photoCount = activity.photoCount
        self.summaryPolyline = activity.map.summaryPolyline

        let coordinates = Polyline(encodedPolyline: activity.map.summaryPolyline).coordinates!
        let points = coordinates.map { GeometricPoint2D(x: $0.longitude, y: $0.latitude) }
        let linestring = GeometricLineString2D(points: points)
        self.summaryLine = linestring

        self.trainer = activity.trainer
        self.commute = activity.commute
        self.manual = activity.manual
        self.`private` = activity.private
        self.visibility = activity.visibility
        self.flagged = activity.flagged
        self.gearID = activity.gearId
        self.startLocation = GeometricPoint2D(x: activity.startLatlng[1], y: activity.startLatlng[0])
        self.endLocation = GeometricPoint2D(x: activity.endLatlng[1], y: activity.endLatlng[0])
        self.averageSpeed = activity.averageSpeed
        self.maxSpeed = activity.maxSpeed
        self.averageCadence = activity.averageCadence
        self.averageTemp = activity.averageTemp
        self.averageWatts = activity.averageWatts
        self.maxWatts = activity.maxWatts
        self.weightedAverageWatts = activity.weightedAverageWatts
        self.kilojoules = activity.kilojoules
        self.deviceWatts = activity.deviceWatts ?? false
        self.hasHeartrate = activity.hasHeartrate
        self.averageHeartrate = activity.averageHeartrate
        self.maxHeartrate = activity.maxHeartrate
        self.heartrateOptOut = activity.heartrateOptOut
        self.displayHideHeartrateOption = activity.displayHideHeartrateOption
        self.elevationHigh = activity.elevHigh
        self.elevationLow = activity.elevLow
        self.uploadID = activity.uploadId
        self.uploadIDStr = activity.uploadIdStr
        self.externalID = activity.externalId
        self.fromAcceptedTag = activity.fromAcceptedTag
        self.prCount = activity.prCount
        self.totalPhotoCount = activity.totalPhotoCount
        self.hasKudoed = activity.hasKudoed
        self.sufferScore = activity.sufferScore
        
        self.$user.id = userID
    }
}

extension StravaActivity {
    var feature: Feature {
        Feature(geometry:
                .lineString(
                    try! .init(coordinates:
                            summaryLine.points.map {
                                .init(longitude: $0.x, latitude: $0.y)
                            }
                         )
                ), properties: [
                    "name": "\(name)",
                    "stroke": "#f60909",
                    "stroke-width": 2,
                    "stroke-opacity": 1
                ]
        )
    }
}

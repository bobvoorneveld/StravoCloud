//
//  CreateStravaActivity.swift
//  
//
//  Created by Bob Voorneveld on 30/12/2022.
//

import Fluent

extension StravaActivity {
    struct Migration: AsyncMigration {
        var name: String { "CreateStravaActivity" }

        func prepare(on database: Database) async throws {
            try await database.schema("strava_activities")
                .id()
                .field("created_at", .datetime, .required)
                .field("updated_at", .datetime, .required)
                .field("user_id", .uuid, .required, .references("users", "id"))
                .field("strava_id", .int, .required)
                .unique(on: "strava_id")
                .field("name", .string, .required)
                .field("distance", .double, .required)
                .field("moving_time", .int, .required)
                .field("elapsed_time", .int, .required)
                .field("total_elevation_gain", .double, .required)
                .field("sport_type", .string, .required)
                .field("workout_type", .int)
                .field("start_date", .datetime, .required)
                .field("start_date_local", .datetime, .required)
                .field("timezone", .string, .required)
                .field("utc_offset", .int, .required)
                .field("location_city", .string)
                .field("location_state", .string)
                .field("location_country", .string, .required)
                .field("achievement_count", .int, .required)
                .field("kudos_count", .int, .required)
                .field("comment_count", .int, .required)
                .field("athlete_count", .int, .required)
                .field("photo_count", .int, .required)
                .field("map_summary_polyline", .string, .required)
                .field("map_summary_line", .geographicLineString2D, .required)
                .field("trainer", .bool, .required)
                .field("commute", .bool, .required)
                .field("manual", .bool, .required)
                .field("private", .bool, .required)
                .field("visibility", .string, .required)
                .field("flagged", .bool, .required)
                .field("gear_id", .string)
                .field("start_location", .geographicPoint2D, .required)
                .field("end_location", .geographicPoint2D, .required)
                .field("average_speed", .double, .required)
                .field("max_speed", .double, .required)
                .field("average_cadence", .double)
                .field("average_temp", .int)
                .field("average_watts", .double)
                .field("max_watts", .int)
                .field("weighted_average_watts", .int)
                .field("kilojoules", .double)
                .field("device_watts", .bool, .required)
                .field("has_heartrate", .bool, .required)
                .field("average_heartrate", .double)
                .field("max_heartrate", .double)
                .field("heartrate_opt_out", .bool, .required)
                .field("display_hide_heartrate_option", .bool, .required)
                .field("elev_high", .double, .required)
                .field("elev_low", .double, .required)
                .field("upload_id", .int, .required)
                .field("upload_id_str", .string, .required)
                .field("external_id", .string, .required)
                .field("from_accepted_tag", .bool, .required)
                .field("pr_count", .int, .required)
                .field("total_photo_count", .int, .required)
                .field("has_kudoed", .bool, .required)
                .field("suffer_score", .int)
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("strava_activities").delete()
        }
    }
}

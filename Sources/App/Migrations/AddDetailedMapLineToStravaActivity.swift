//
//  AddDetailedMapLineToStravaActivity.swift
//
//
//  Created by Bob Voorneveld on 30/12/2022.
//

import Fluent

extension StravaActivity {
    struct AddDetailedMapLine: AsyncMigration {
        var name: String { "AddDetailedMapLineToStravaActivity" }

        func prepare(on database: Database) async throws {
            try await database.schema("strava_activities")
                .field("map_detailed_polyline", .string)
                .field("map_detailed_line", .geometricLineString2D)
                .update()
        }

        func revert(on database: Database) async throws {
            try await database.schema("strava_activities")
                .deleteField("map_detailed_polyline")
                .deleteField("map_detailed_line")
                .update()
        }
    }
}

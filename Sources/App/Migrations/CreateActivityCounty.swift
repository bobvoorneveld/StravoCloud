//
//  ActivityCounty.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Fluent

extension ActivityCounty {
    struct Migration: AsyncMigration {
        var name: String { "CreateActivityCounty" }

        func prepare(on database: Database) async throws {
            try await database.schema("gemeente_gegeneraliseerd")
                .unique(on: "id")
                .update()

            try await database.schema("activity+county")
                .id()
                .field("activity_id", .uuid, .required, .references("strava_activities", "id"))
                .field("county_id", .int, .required, .references("gemeente_gegeneraliseerd", "id"))
                .unique(on: "activity_id", "county_id")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("activity+county").delete()
        }
    }
}

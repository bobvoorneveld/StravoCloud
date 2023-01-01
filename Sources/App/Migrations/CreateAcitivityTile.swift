//
//  CreateActivityTile.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Fluent

extension ActivityTile {
    struct Migration: AsyncMigration {
        var name: String { "CreateActivityTile" }

        func prepare(on database: Database) async throws {
            try await database.schema("activity_tiles")
                .id()
                .field("activity_id", .uuid, .required, .references("strava_activities", "id"))
                .field("x", .int, .required)
                .field("y", .int, .required)
                .field("z", .int, .required)
                .unique(on: "activity_id", "x", "y", "z")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("activity_tiles").delete()
        }
    }
}

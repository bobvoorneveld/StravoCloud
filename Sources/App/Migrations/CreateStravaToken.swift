//
//  CreateStravaToken.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Fluent

extension StravaToken {
    struct Migration: AsyncMigration {
        var name: String { "CreateStravaToken" }

        func prepare(on database: Database) async throws {
            try await database.schema("strava_tokens")
                .id()
                .field("refresh_token", .string, .required)
                .field("access_token", .string)
                .field("expires_at", .date)
                .field("user_id", .uuid, .required, .references("users", "id"))
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("strava_tokens").delete()
        }
    }
}

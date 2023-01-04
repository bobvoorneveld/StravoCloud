//
//  AddGeoJSONTilesToUser.swift
//  
//
//  Created by Bob Voorneveld on 04/01/2023.
//

import Fluent

extension User {
    struct AddGeoJSONTilesToUserMigration: AsyncMigration {
        var name: String { "AddGeoJSONTilesToUser" }

        func prepare(on database: Database) async throws {
            try await database.schema("users")
                .field("geojson_tiles", .string)
                .update()
        }

        func revert(on database: Database) async throws {
            try await database.schema("users")
                .deleteField("geojson_tiles")
                .update()
        }
    }
}

//
//  migrations.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Vapor
import FluentPostGIS


func setupMigrations(app: Application) throws {
    app.migrations.add(User.Migration())
    app.migrations.add(UserToken.Migration())
    app.migrations.add(StravaToken.Migration())
    
    app.migrations.add(EnablePostGISMigration())

    app.migrations.add(StravaActivity.Migration())
    app.migrations.add(ActivityTile.Migration())
    app.migrations.add(ActivityCounty.Migration())
    app.migrations.add(User.AddGeoJSONTilesToUserMigration())
}

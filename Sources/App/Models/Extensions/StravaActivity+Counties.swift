//
//  File.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Fluent

extension StravaActivity {
    
    @discardableResult
    func getCounties(on db: Database) async throws -> [County] {
        try await $counties.load(on: db)
        guard counties.isEmpty else  {
            return counties
        }

        let counties = try await County.query(on: db).filterGeometryIntersects(\.$geom2, summaryLine).all()
        for county in counties {
            try await $counties.attach(county, method: .ifNotExists, on: db)
        }
        try await $counties.load(on: db)
        return counties
    }
}

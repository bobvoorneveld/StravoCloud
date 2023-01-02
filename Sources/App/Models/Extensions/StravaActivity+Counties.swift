//
//  File.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Fluent

extension StravaActivity {
    
    @discardableResult
    func getCounties(on db: Database, forced: Bool = false) async throws -> [County] {
        if !forced {
            try await $counties.load(on: db)
            guard counties.isEmpty else  {
                return counties
            }
        }

        let counties: [County]
        if let detailedLine {
            counties = try await County.query(on: db).filterGeometryIntersects(\.$geom2, detailedLine).all()
        } else {
            counties = try await County.query(on: db).filterGeometryIntersects(\.$geom2, summaryLine).all()
        }
        
        // remove old counties if we're reloading
        if forced {
            try await self.$counties.detachAll(on: db)
        }

        for county in counties {
            try await $counties.attach(county, method: .ifNotExists, on: db)
        }
        try await $counties.load(on: db)
        return counties
    }
}

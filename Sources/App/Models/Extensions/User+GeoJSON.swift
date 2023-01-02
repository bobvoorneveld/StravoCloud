//
//  User+GeoJSON.swift
//
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import GeoJSON
import Fluent
import FluentKit
import Vapor

extension User {
    func getFeatureCollection(req: Request) async throws -> FeatureCollection {
        req.logger.info("loading tiles")
        let tiles = try await ActivityTile.query(on: req.db)
            .join(StravaActivity.self, on: \ActivityTile.$activity.$id == \StravaActivity.$id)
            .filter(StravaActivity.self, \.$user.$id == id!)
            .field(\.$x)
            .field(\.$y)
            .field(\.$z)
            .unique()
            .all()
        
        req.logger.info("getting tile features")
        let tileFeatues = tiles.map { $0.feature }
        
        req.logger.info("loading activities")
        let activities = try await $activities.get(on: req.db)
        
        req.logger.info("getting activity features")
        let activityFeatures = try await $activities.get(on: req.db).map { $0.summaryFeature }
        
        req.logger.info("loading county features")
        var counties = Set<County>()
        for activity in activities {
            try await activity.$counties.load(on: req.db)
            counties.formUnion(activity.counties)
        }

        req.logger.info("getting county features")
        let countyFeatures = counties.map { $0.feature }
        
        req.logger.info("reeturning collection")
        return FeatureCollection(features: tileFeatues + activityFeatures + countyFeatures)
    }
}

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
import FluentPostGIS
import FluentSQL


extension User {
    func getFilteredActivities(req: Request, filter: ActivityFilter) -> QueryBuilder<StravaActivity> {
        
        // tiles are 256 px, a high def screen is 3456 pixels wide (lets do 1.5x) -> ~ 20 tiles
        let tileWidth = (360 / Double(pow(2, filter.zoom)))
        let delta = ((3456 * 1.5) / 256) * tileWidth / 2
        let box = GeometricPolygon2D(exteriorRing: .init(points: [
            GeometricPoint2D(x: filter.lat - delta, y: filter.lng - delta),
            GeometricPoint2D(x: filter.lat + delta, y: filter.lng - delta),
            GeometricPoint2D(x: filter.lat + delta, y: filter.lng + delta),
            GeometricPoint2D(x: filter.lat - delta, y: filter.lng + delta),
            GeometricPoint2D(x: filter.lat - delta, y: filter.lng - delta),
        ]))
        
        return $activities.query(on: req.db)
            .with(\.$counties)
            .filterGeometryCrosses(\.$summaryLine, box)
    }

    func getFeatureCollection(req: Request, filter: ActivityFilter? = nil) async throws -> FeatureCollection {
        
        req.logger.info("loading activities")
        let acts: [StravaActivity]
        if let filter {
            acts = try await getFilteredActivities(req: req, filter: filter).all()
        } else {
            acts = try await $activities.query(on: req.db).all()
        }
        
        req.logger.info("number: \(acts.count)")

        req.logger.info("getting activity features")
        let activityFeatures = acts.map { $0.summaryFeature }
        
        req.logger.info("loading tiles")
        var tileQuery = ActivityTile.query(on: req.db)
            .join(StravaActivity.self, on: \ActivityTile.$activity.$id == \StravaActivity.$id)
            .filter(StravaActivity.self, \.$user.$id == id!)
        
        if let filter {
            // tiles are 256 px, a high def screen is 3456 pixels wide (lets do 1.5x) -> 28 tiles
            let tileWidth = (360 / Double(pow(2, filter.zoom)))
            let delta = ((3456 * 1.5) / 256) * tileWidth / 2
            let upperLeft = tranformCoordinate(filter.lng - delta, filter.lat - delta, withZoom: 14)
            let downRight = tranformCoordinate(filter.lng + delta, filter.lat + delta, withZoom: 14)
            
            tileQuery = tileQuery
                .filter(\.$x >= upperLeft.x)
                .filter(\.$x <= downRight.x)
                .filter(\.$y <= upperLeft.y)
                .filter(\.$y >= downRight.y)
        }
        
        let tiles = try await tileQuery
            .field(\.$x)
            .field(\.$y)
            .field(\.$z)
            .unique()
            .all()
        
        req.logger.info("getting tile features")
        let tileFeatues = tiles.map { $0.feature }
        
        req.logger.info("loading county features")
        var counties = Set<County>()
        for activity in try await $activities.query(on: req.db).with(\.$counties).all() {
            counties.formUnion(activity.counties)
        }

        req.logger.info("getting county features")
        let countyFeatures = counties.map { $0.feature }
        
        req.logger.info("returning collection")
        return FeatureCollection(features: countyFeatures + tileFeatues + activityFeatures)
    }
}

struct ActivityFilter {
    let lat: Double
    let lng: Double
    let zoom: Float
}

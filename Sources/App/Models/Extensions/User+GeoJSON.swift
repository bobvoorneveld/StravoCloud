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


extension User {
    func getFeatureCollection(req: Request, filter: ActivityFilter? = nil) async throws -> FeatureCollection {
        
        var query = $activities.query(on: req.db)
            .with(\.$counties)

        if let filter {
            let zoom = (360 / Double(pow(2, filter.zoom))) / 2
            let box = GeometricPolygon2D(exteriorRing: .init(points: [
                GeometricPoint2D(x: filter.lat - zoom, y: filter.lng - zoom),
                GeometricPoint2D(x: filter.lat + zoom, y: filter.lng - zoom),
                GeometricPoint2D(x: filter.lat + zoom, y: filter.lng + zoom),
                GeometricPoint2D(x: filter.lat - zoom, y: filter.lng + zoom),
                GeometricPoint2D(x: filter.lat - zoom, y: filter.lng - zoom),
            ]))
            
            query = query.filterGeometryCrosses(\.$summaryLine, box)
        }
        
        req.logger.info("loading activities")
        let activities = try await query.all()

        req.logger.info("getting activity features")
        let activityFeatures = activities.map { $0.summaryFeature }
        
        req.logger.info("loading tiles")
        var tileQuery = ActivityTile.query(on: req.db)
            .join(StravaActivity.self, on: \ActivityTile.$activity.$id == \StravaActivity.$id)
            .filter(StravaActivity.self, \.$user.$id == id!)
        
        if let filter {
            let zoom = (360 / Double(pow(2, filter.zoom)))
            let upperLeft = tranformCoordinate(filter.lng - zoom, filter.lat - zoom, withZoom: 14)
            let downRight = tranformCoordinate(filter.lng + zoom, filter.lat + zoom, withZoom: 14)
            
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

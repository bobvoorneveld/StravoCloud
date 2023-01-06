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
import Polyline


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
        
        var tileFeatures = [Feature]()
        if let data = geoJSONTiles?.data(using: .utf8) {
            let decoder = JSONDecoder()
            do {
                let geometry = try decoder.decode(Geometry.self, from: data)
                print(geometry)
                tileFeatures.append(Feature(geometry: geometry))
            } catch {
                print(error)
            }
        }
        
        req.logger.info("loading county features")
        var counties = Set<County>()
        for activity in try await $activities.query(on: req.db).with(\.$counties).all() {
            counties.formUnion(activity.counties)
        }

        req.logger.info("getting county features")
        let countyFeatures = counties.map { $0.feature }
        
        req.logger.info("returning collection")
        return FeatureCollection(features: countyFeatures + tileFeatures + activityFeatures)
    }
    
    func updateGeoJSONTiles(on db: Database) async throws {
        // Creating geojson for every user
        guard let sql = db as? SQLDatabase, let id else {
            return
        }
        
        _ = try await sql.raw("""
            WITH
                tiles AS (
                    SELECT DISTINCT
                        ST_AsGeoJSON(ST_Simplify(ST_Union(geom), 0.001)) as geojson
                    FROM
                        "activity_tiles"
                    WHERE
                        user_id = '\(raw: id.uuidString)'
                )

            UPDATE
                users
            SET
                geojson_tiles = t.geojson

            FROM
                tiles as t
            WHERE
                id = '\(raw: id.uuidString)'
            """).all()
    }
    
    func getGeoJSONTiles(for polyline: String, on db: Database) async throws -> String {
        guard let sql = db as? SQLDatabase else {
            throw Abort(.internalServerError)
        }
        
        let polyline = Polyline(encodedPolyline: polyline)
        guard let coordinates = polyline.coordinates else {
            throw Abort(.badRequest)
        }
        
        let geometryDescription: String
        
        if coordinates.count == 1 {
            geometryDescription = GeometricPoint2D(x: coordinates[0].longitude, y: coordinates[0].latitude).description
        } else {
            geometryDescription = GeometricLineString2D(
                points: coordinates.compactMap {
                    GeometricPoint2D(x: $0.longitude, y: $0.latitude)
                }
            ).description
        }

        
        guard let geoJSONRow = try await sql.raw("""
            WITH
              -- parameter injection, for convenience
              zoom(lvl, csize) AS (
                VALUES ( 14, (2*PI()*6378137)/POW(2, 14) )
              ),

              line AS (SELECT ST_SubDivide(ST_TRANSFORM(ST_GeomFromEWKT('\(raw: geometryDescription)'), 3857), 64) as geom)

            -- get all covering tile indices for each POI
            SELECT DISTINCT
                ST_AsGeoJSON(ST_TRANSFORM(ST_Simplify(ST_Union(grid.geom), 0.001), 4326)) AS geojson
            FROM
              zoom as z,
              line as l,
            LATERAL ST_SquareGrid(z.csize, l.geom) AS grid

            -- filter for those that actually intersect any of the subdivisions
            WHERE
              ST_Intersects(l.geom, grid.geom)
            ;
            """).first(decoding: GeoJSONRow.self) else {
            throw Abort(.internalServerError)
        }
        
        return geoJSONRow.geojson
    }
}

struct ActivityFilter {
    let lat: Double
    let lng: Double
    let zoom: Float
}

struct GeoJSONRow: Decodable {
    let geojson: String
}

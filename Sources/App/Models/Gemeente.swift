//
//  Gemeente.swift
//  
//
//  Created by Bob Voorneveld on 30/12/2022.
//

import Fluent
import Vapor
import FluentPostGIS
import GeoJSON


final class Gemeente: Model, Content {
    static let schema = "gemeente_gegeneraliseerd"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "statnaam")
    var naam: String
    
    @Field(key: "geom")
    var geom: GeometricMultiPolygon2D

    @Field(key: "geom2")
    var geom2: GeometricMultiPolygon2D

    init() { }
}

extension Gemeente {
    var feature: Feature {
        let polygons = geom2.polygons.compactMap { poly in
            let exteriorPoints = poly.exteriorRing.points.map { Position(longitude: $0.x, latitude: $0.y) }
            let interiorPoints = poly.interiorRings.map { $0.points.map { Position(longitude: $0.x, latitude: $0.y) } }
            let positions = [exteriorPoints] + interiorPoints
            return try? Polygon(coordinates: positions)
        }
        let multi = MultiPolygon(coordinates: polygons)
        return Feature(geometry: .multiPolygon(multi), id: "\(naam)", properties: ["name": "\(naam)"])
    }
}

extension FeatureCollection: Content {}

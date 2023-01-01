//
//  County+GeoJSON.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import GeoJSON


extension County {
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

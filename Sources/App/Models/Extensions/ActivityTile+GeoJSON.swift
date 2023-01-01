//
//  ActivityTile.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Foundation
import GeoJSON

extension ActivityTile {
    var cornerPositions: [Position] {
        var positions = [Position]()
        positions.append(tileToLatLon(tileX: x, tileY: y, mapZoom: z))
        positions.append(tileToLatLon(tileX: x+1, tileY: y, mapZoom: z))
        positions.append(tileToLatLon(tileX: x+1, tileY: y-1, mapZoom: z))
        positions.append(tileToLatLon(tileX: x, tileY: y-1, mapZoom: z))
        positions.append(tileToLatLon(tileX: x, tileY: y, mapZoom: z))
        return positions
    }
    
    var feature: Feature {
        Feature(geometry: .polygon(try! Polygon(coordinates: [cornerPositions])))
    }
}

func tileToLatLon(tileX : Int, tileY : Int, mapZoom: Int) -> Position {
    let n : Double = pow(2.0, Double(mapZoom))
    let lon = (Double(tileX) / n) * 360.0 - 180.0
    let lat = atan( sinh (.pi - (Double(tileY) / n) * 2 * Double.pi)) * (180.0 / .pi)
    
    return Position(longitude: lon, latitude: lat)
}

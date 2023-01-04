//
//  ActivityTile.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Fluent
import Vapor
import FluentPostGIS

final class ActivityTile: Model, Content {
    static let schema = "activity_tiles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "activity_id")
    var activity: StravaActivity
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "geom")
    var geom: GeometricPolygon2D

    @Field(key: "x")
    var x: Int

    @Field(key: "y")
    var y: Int
    
    @Field(key: "z")
    var z: Int
    
    var url: String {
        "https://tile.openstreetmap.org/\(z)/\(x)/\(y).png"
    }

    init() { }

    init(activityID: UUID, userID: UUID, x: Int, y: Int, z: Int) {
        self.$activity.id = activityID
        self.$user.id = userID
        self.x = x
        self.y = y
        self.z = z
        
        createGeom()
    }
    
    func createGeom() {
        self.geom = GeometricPolygon2D(exteriorRing: .init(points: [
            tileToGeometricPoint(tileX: x, tileY: y, mapZoom: z),
            tileToGeometricPoint(tileX: x+1, tileY: y, mapZoom: z),
            tileToGeometricPoint(tileX: x+1, tileY: y-1, mapZoom: z),
            tileToGeometricPoint(tileX: x, tileY: y-1, mapZoom: z),
            tileToGeometricPoint(tileX: x, tileY: y, mapZoom: z)
        ]))
    }
    
    func tileToGeometricPoint(tileX : Int, tileY : Int, mapZoom: Int) -> GeometricPoint2D {
        let n : Double = pow(2.0, Double(mapZoom))
        let lon = (Double(tileX) / n) * 360.0 - 180.0
        let lat = atan( sinh (.pi - (Double(tileY) / n) * 2 * Double.pi)) * (180.0 / .pi)
        
        return GeometricPoint2D(x: lon, y: lat)
    }
}

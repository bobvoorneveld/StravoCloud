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


final class County: Model, Content {
    static let schema = "gemeente_gegeneraliseerd"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "statnaam")
    var naam: String
    
    @Field(key: "geom")
    var geom: GeometricMultiPolygon2D

    @Field(key: "geom2")
    var geom2: GeometricMultiPolygon2D

    @Siblings(through: ActivityCounty.self, from: \.$county, to: \.$activity)
    var activities: [StravaActivity]
    
    init() { }
}

extension County: Equatable, Hashable {
    static func == (lhs: County, rhs: County) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id!)
    }
}

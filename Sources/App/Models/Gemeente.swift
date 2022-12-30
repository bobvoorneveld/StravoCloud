//
//  Gemeente.swift
//  
//
//  Created by Bob Voorneveld on 30/12/2022.
//

import Fluent
import Vapor
import FluentPostGIS


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

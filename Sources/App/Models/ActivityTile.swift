//
//  ActivityTile.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Fluent
import Vapor

final class ActivityTile: Model, Content {
    static let schema = "activity_tiles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "activity_id")
    var activity: StravaActivity

    @Field(key: "x")
    var x: Int

    @Field(key: "y")
    var y: Int
    
    @Field(key: "z")
    var z: Int
    
    init() { }

    init(activityID: UUID, x: Int, y: Int, z: Int) {
        self.$activity.id = activityID
        self.x = x
        self.y = y
        self.z = z
    }
}

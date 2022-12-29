//
//  StravaActivity.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Fluent
import Vapor


final class LatLng: Fields {
    @Field(key: "lat")
    var lat: Double

    @Field(key: "lng")
    var lng: Double

    init() { }
}


final class StravaActivity: Model, Content {
    static let schema = "strava_activities"

    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Field(key: "strava_id")
    var stravaID: Int
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "start_date")
    var startDate: Date

    @Parent(key: "user_id")
    var user: User

    init() { }

    init(id: UUID? = nil, stravaID: Int, name: String, startDate: Date, userID: User.IDValue) {
        self.id = id
        self.stravaID = stravaID
        self.name = name
        self.startDate = startDate
        self.$user.id = userID
    }
}

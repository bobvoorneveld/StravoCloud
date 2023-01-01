//
//  ActivityCounty.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Fluent

final class ActivityCounty: Model {
    static let schema = "activity+county"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "activity_id")
    var activity: StravaActivity

    @Parent(key: "county_id")
    var county: County

    init() { }
}

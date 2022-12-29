//
//  StravaToken.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//


import Fluent
import Vapor

final class StravaToken: Model, Content {
    static let schema = "strava_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "access_token")
    var accessToken: String?
    
    @Field(key: "expires_at")
    var expiresAt: Date?
    
    @Field(key: "refresh_token")
    var refreshToken: String

    @Parent(key: "user_id")
    var user: User

    init() { }

    init(id: UUID? = nil, refreshToken: String, accessToken: String? = nil, expiresAt: Date? = nil, userID: User.IDValue) {
        self.id = id
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.$user.id = userID
    }
}

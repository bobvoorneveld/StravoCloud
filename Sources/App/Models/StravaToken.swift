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

extension StravaToken {

    struct NewAccessTokenResponse: Content {
        let accessToken: String
        let expiresAt: TimeInterval
    }
    func renewToken(req: Request) async throws {
        guard let clientID = Environment.get("STRAVA_CLIENT_ID"), let clientSecret = Environment.get("STRAVA_CLIENT_SECRET") else {
            throw Abort(.preconditionFailed)
        }

        if let expires = expiresAt, expires > Date() {
            let res = try await req.client.post("https://www.strava.com/oauth/token?client_id=\(clientID)&client_secret=\(clientSecret)&grant_type=refresh_token&refresh_token=\(refreshToken)")
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let newToken = try res.content.decode(NewAccessTokenResponse.self, using: decoder)
            
            accessToken = newToken.accessToken
            expiresAt = Date(timeIntervalSince1970: newToken.expiresAt)
            try await update(on: req.db)
        }
    }
}

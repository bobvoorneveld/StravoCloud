//
//  StravaController.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Vapor


struct StravaController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let strava = routes.grouped("strava")
        
        let sessionAuth = strava.grouped([User.sessionAuthenticator(), User.redirectMiddleware(path: "/users/login")])
        sessionAuth.get("authenticate", use: authenticate)
        sessionAuth.get("exchange_token", use: exchangeToken)
    }
    
    func authenticate(req: Request) async throws -> Response {
        
        guard let clientID = Environment.get("STRAVA_CLIENT_ID") else {
            throw Abort(.preconditionFailed)
        }

        return req.redirect(to: "http://www.strava.com/oauth/authorize?client_id=\(clientID)&response_type=code&redirect_uri=http://localhost:8080/strava/exchange_token&approval_prompt=force&scope=read_all,profile:read_all,activity:read_all")
    }
    
    struct Token: Content {
        let code: String
    }
    
    struct StravaTokenResponse: Content {
        let tokenType: String?
        let expiresAt: TimeInterval
        let expiresIn: Int
        let refreshToken: String
        let accessToken: String
        let athlete: Athlete
    }

    // MARK: - Athlete
    struct Athlete: Content {
        let id: Int
        let username: String
        let resourceState: Int
        let firstname: String
        let lastname: String
        let bio: String
        let city: String
        let state: String
        let country: String
        let sex: String
        let premium: Bool
        let summit: Bool
        let createdAt: Date
        let updatedAt: Date
        let badgeTypeId: Int
        let weight: Double
        let profileMedium: String
        let profile: String
        let friend: Int?
        let follower: Int?
    }

    
    func exchangeToken(req: Request) async throws -> StravaToken {
        let token = try req.query.decode(Token.self)
        let user = try req.auth.require(User.self)
        
        guard let clientID = Environment.get("STRAVA_CLIENT_ID"), let clientSecret = Environment.get("STRAVA_CLIENT_SECRET") else {
            throw Abort(.preconditionFailed)
        }
        
        let res = try await req.client.post("https://www.strava.com/oauth/token?client_id=\(clientID)&client_secret=\(clientSecret)&code=\(token.code)&grant_type=authorization_code")
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let tokenData = try res.content.decode(StravaTokenResponse.self, using: decoder)
        
        let stravaToken = StravaToken(refreshToken: tokenData.refreshToken, accessToken: tokenData.accessToken, expiresAt: Date(timeIntervalSince1970: tokenData.expiresAt), userID: user.id!)
        try await stravaToken.create(on: req.db)
        return stravaToken
    }
}

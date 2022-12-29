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

        sessionAuth.get("sync", use: sync)
    }

    func authenticate(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)

        guard let clientID = Environment.get("STRAVA_CLIENT_ID") else {
            throw Abort(.preconditionFailed)
        }

        guard let token = try await user.$stravaToken.get(on: req.db) else {
            return req.redirect(to: "https://www.strava.com/oauth/authorize?client_id=\(clientID)&response_type=code&redirect_uri=http://localhost:8080/strava/exchange_token&approval_prompt=force&scope=read_all,profile:read_all,activity:read_all")
        }
        
        try await token.renewToken(req: req)
        
        return try await user.stravaToken!.encodeResponse(for: req)
    }
    
    func sync(req: Request) async throws -> Response {
        guard let _ = try await req.auth.require(User.self).$stravaToken.get(on: req.db) else {
            return req.redirect(to: "/strava/authenticate")
        }
        let activities = try await loadActivities(req: req)
        return try await activities.encodeResponse(for: req)
    }
    
    struct Token: Content {
        let code: String
    }
    struct StravaTokenResponse: Content {
        let expiresAt: TimeInterval
        let refreshToken: String
        let accessToken: String
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

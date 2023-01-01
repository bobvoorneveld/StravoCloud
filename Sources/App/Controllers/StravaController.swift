//
//  StravaController.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Vapor
import FluentPostGIS
import GeoJSON
import FluentSQL


struct StravaController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let strava = routes.grouped("strava")
        
        let sessionAuth = strava.grouped([User.sessionAuthenticator(), User.redirectMiddleware(path: "/users/login")])
        sessionAuth.get("authenticate", use: authenticate)
        sessionAuth.get("exchange_token", use: exchangeToken)

        sessionAuth.get("sync", use: sync)
        let activitiesRoutes = sessionAuth.grouped("activities")
        activitiesRoutes.get(use: activities)
        let activityRoute = activitiesRoutes.grouped(":activityID")
        activityRoute.get(use: activity)
        activityRoute.get("tiles", use: tiles)
        activityRoute.get("feature-collection", use: featureCollection)
    }
    
    func activity(req: Request) async throws -> StravaActivity {
        let user = try req.auth.require(User.self)
        guard let id: UUID = req.parameters.get("activityID") else {
            throw Abort(.badRequest)
        }
        guard let activity = try await user.$activities.query(on: req.db).filter(\.$id, .equal, id).first() else {
            throw Abort(.notFound)
        }
        
        return activity
    }

    struct GetAllActivity: Content {
        let id: UUID
        let name: String
        let startDate: Date
        let distance: Double
        let averageSpeed: Double
        let averageWatts: Double?
        let movingTime: TimeInterval
        let weightedAverageWatts: Int?
        let averageCadence: Double?
        let elapsedTime: TimeInterval
        let totalElevationGain: Double
        let kilojoules: Double?
        let sufferScore: Int?
        let url: URL
    }
    func activities(req: Request) async throws -> [GetAllActivity] {
        let user = try req.auth.require(User.self)
        
        return try await user.$activities.query(on: req.db)
            .sort(\.$startDate, .descending)
            .all()
            .compactMap { a in
                GetAllActivity(
                    id: a.id!,
                    name: a.name,
                    startDate: a.startDate,
                    distance: a.distance,
                    averageSpeed: a.averageSpeed,
                    averageWatts: a.averageWatts,
                    movingTime: TimeInterval(a.movingTime),
                    weightedAverageWatts: a.weightedAverageWatts,
                    averageCadence: a.averageCadence,
                    elapsedTime: TimeInterval(a.elapsedTime),
                    totalElevationGain: a.totalElevationGain,
                    kilojoules: a.kilojoules,
                    sufferScore: a.sufferScore,
                    url: URL(string: "/strava/activities/\(a.id!)")!
                )
        }
    }
    
    struct GetTile: Content {
        let x: Int
        let y: Int
        let z: Int
        let url: String
    }
    func tiles(req: Request) async throws -> [GetTile] {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityID", as: UUID.self),
              let activity = try await user.$activities.query(on: req.db).filter(\.$id, .equal, activityId).first() else {
            throw Abort(.notFound)
        }
        
        return try await activity.getTiles(on: req.db).map { .init(x: $0.x, y: $0.y, z: $0.z, url: $0.url) }
    }
    
    func featureCollection(req: Request) async throws -> FeatureCollection {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityID", as: UUID.self),
              let activity = try await user.$activities.query(on: req.db).filter(\.$id, .equal, activityId).first() else {
            throw Abort(.notFound)
        }
        
        try await activity.getTiles(on: req.db)
        
        return activity.featureCollection
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
        try await loadActivities(req: req)
        return req.redirect(to: "/strava/activities")
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

extension Feature: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

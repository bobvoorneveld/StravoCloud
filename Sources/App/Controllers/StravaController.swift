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
    }
    
    func activity(req: Request) async throws -> FeatureCollection {
        let user = try req.auth.require(User.self)
        guard let id: UUID = req.parameters.get("activityID") else {
            throw Abort(.badRequest)
        }
        guard let activity = try await user.$activities.query(on: req.db).filter(\.$id, .equal, id).first() else {
            throw Abort(.notFound)
        }
        
        let gemeentes = try await Gemeente.query(on: req.db).filterGeometryIntersects(\.$geom2, activity.summaryLine).all()
        return FeatureCollection(features: gemeentes.map { $0.feature } + [activity.feature])
    }

    func activities(req: Request) async throws -> FeatureCollection {
        let user = try req.auth.require(User.self)
        
        let activities = try await user.$activities.query(on: req.db).all()
        var features = [Feature]()
        
        var gemeenteFeatures = Set<Feature>()
        
        for activity in activities {
            let gemeentes = try await Gemeente.query(on: req.db).filterGeometryIntersects(\.$geom2, activity.summaryLine).all()
            if !gemeentes.isEmpty {
                gemeenteFeatures.formUnion(gemeentes.map { $0.feature })
                features.append(activity.feature)
            }
        }
        
        return FeatureCollection(features: features + gemeenteFeatures)
    }
    
    struct Tile: Content {
        let x: Int
        let y: Int
        let z: Int
        
        let url: String?
    }
    func tiles(req: Request) async throws -> [Tile] {
        let user = try req.auth.require(User.self)
        
        guard let sql = req.db as? SQLDatabase, let activityId = req.parameters.get("activityID", as: UUID.self),
              let _ = try await user.$activities.query(on: req.db).filter(\.$id, .equal, activityId).first() else {
            throw Abort(.notFound)
        }
        
        // 24d2e128-3ef4-411c-9453-99acf67ae670
        var tiles = try await sql.raw("""
WITH
  -- parameter injection, for convenience
  zoom(lvl, csize) AS (
    VALUES ( 14, (2*PI()*6378137)/POW(2, 14) )
  ),

  -- subdivide your polygons to minimize per-geometry vertex count
  poi AS (
    SELECT
      id, sdv AS geom
    FROM
      strava_activities AS ply,
      LATERAL ST_SubDivide(
        ST_Transform(ply.map_summary_line, 3857),
        64
      ) AS sdv
      WHERE id='\(activityId.uuidString)'
  )

-- get all covering tile indices for each POI
SELECT DISTINCT
  grid.i as x, grid.j as y, z.lvl as z
FROM
  zoom as z,
  poi AS t,
  LATERAL ST_SquareGrid(z.csize, t.geom) AS grid

-- filter for those that actually intersect any of the subdivisions
WHERE
  ST_Intersects(t.geom, grid.geom)
;
""").all(decoding: Tile.self)
        
        tiles = tiles.map {
            let x = $0.x + 8192
            let y = 8192 - $0.y
            return Tile(x: x, y: y, z: $0.z, url: "https://tile.openstreetmap.org/\($0.z)/\(x)/\(y).png")
        }
        return tiles
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

extension Feature: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

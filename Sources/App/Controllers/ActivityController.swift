//
//  ActivityController.swift
//
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Vapor
import GeoJSON
import FluentKit
import FluentPostGIS

struct ActivityController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let sessionAuth = routes.grouped([User.sessionAuthenticator(), UserToken.authenticator(), User.guardMiddleware()])
        let activitiesRoutes = sessionAuth.grouped("activities")
        activitiesRoutes.get(use: activities)
        activitiesRoutes.get("sync", use: sync)
        activitiesRoutes.get("tiles", use: allTiles)

        let featureCollectionRoutes = activitiesRoutes.grouped("feature-collection")
        featureCollectionRoutes.get(use: featureCollectionForUser)
        featureCollectionRoutes.get(":filter", use: featureCollectionForUser)
        
        let activityRoute = activitiesRoutes.grouped(":activityID")
        activityRoute.get(use: activity)
        activityRoute.get("tiles", use: tiles)
        activityRoute.get("counties", use: counties)
        activityRoute.get("sync", use: detailedSync)
        activityRoute.get("feature-collection", use: featureCollection)
    }
}

// MARK: - Tiles routes

extension ActivityController {
    func allTiles(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        
        guard let json = user.geoJSONTiles else {
            throw Abort(.notFound)
        }
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        
        return try await json.encodeResponse(status: .ok, headers: headers, for: req)
    }

    struct GetTile: Content {
        let x: Int
        let y: Int
        let z: Int
        let url: String
        let geom: GeometricPolygon2D
    }
    func tiles(req: Request) async throws -> [GetTile] {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityID", as: UUID.self),
              let activity = try await user.$activities.query(on: req.db).filter(\.$id == activityId).first() else {
            throw Abort(.notFound)
        }
        
        return try await activity.getTiles(on: req.db).map { .init(x: $0.x, y: $0.y, z: $0.z, url: $0.url, geom: $0.geom) }
    }
}

// MARK: - Sync routes

func sync(req: Request) async throws -> Response {
    let user = try req.auth.require(User.self)

    guard let _ = try await user.$stravaToken.get(on: req.db) else {
        return req.redirect(to: "/strava/authenticate")
    }
    try await req.queue.dispatch(
            SyncActivities.self,
            .init(userID: user.requireID()))
    return try await "syncing".encodeResponse(for: req)
}

func detailedSync(req: Request) async throws -> Response {
    let user = try req.auth.require(User.self)

    guard let _ = try await user.$stravaToken.get(on: req.db) else {
        return req.redirect(to: "/strava/authenticate")
    }
    
    guard let activityID = req.parameters.get("activityID", as: UUID.self),
            let activity = try await user.$activities.query(on: req.db).filter(\.$id == activityID).first() else {
        throw Abort(.notFound)
    }

    let forced = (try? req.query.get(at: "forced")) ?? false
    try await req.queue.dispatch(
        SyncDetailedActivity.self,
        .init(activityID: activityID, forced: forced)
    )
    return try await "\(forced ? "Forced " : "")syncing activity \(activity.name)".encodeResponse(for: req)
}

// MARK: Feature collection routes

extension ActivityController {
    
    func featureCollection(req: Request) async throws -> FeatureCollection {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityID", as: UUID.self),
              let activity = try await user.$activities.query(on: req.db).filter(\.$id == activityId).first() else {
            throw Abort(.notFound)
        }
        
        try await activity.getTiles(on: req.db)
        try await activity.getCounties(on: req.db)
        
        return activity.featureCollection
    }
    
    func featureCollectionForUser(req: Request) async throws -> FeatureCollection {
        let user = try req.auth.require(User.self)
        
        guard let filter: String = try? req.query.get(at: "filter") else {
            return try await user.getFeatureCollection(req: req)
        }

        req.logger.info("Filter: \(filter)")
        let regex = #/(?<lng>\d+.\d+),(?<lat>\d+.\d+),(?<zoom>\d+(.\d+)?)/#
        guard let match = filter.firstMatch(of: regex) else {
            throw Abort(.badRequest)
        }
        
        return try await user.getFeatureCollection(
            req: req,
            filter: .init(
                lat: Double(match.lat)!,
                lng: Double(match.lng)!,
                zoom: Float(match.zoom)!
            )
        )
    }
}

// MARK: Activity routes

extension ActivityController {
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
        
        let query: QueryBuilder<StravaActivity>
        
        if let filter: String = try? req.query.get(at: "filter") {
            req.logger.info("Filter: \(filter)")
            let regex = #/(?<lng>\d+.\d+),(?<lat>\d+.\d+),(?<zoom>\d+(.\d+)?)/#
            guard let match = filter.firstMatch(of: regex) else {
                throw Abort(.badRequest)
            }

            query = user.getFilteredActivities(req: req, filter: .init(lat: Double(match.lat)!, lng: Double(match.lng)!, zoom: Float(match.zoom)!))
        } else {
            query = user.$activities.query(on: req.db)
        }
        
        return try await query
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
                    url: URL(string: "/activities/\(a.id!)")!
                )
        }
    }
}

// MARK: County routes

extension ActivityController {
    func counties(req: Request) async throws -> [County] {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityID", as: UUID.self),
              let activity = try await user.$activities.query(on: req.db).filter(\.$id == activityId).first() else {
            throw Abort(.notFound)
        }
        
        return try await activity.getCounties(on: req.db)
    }
}

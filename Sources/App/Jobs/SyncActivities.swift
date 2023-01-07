//
//  SyncActivities.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Vapor
import Foundation
import Queues
import Fluent

struct UserToSync: Codable {
    let userID: UUID
}

struct SyncActivities: AsyncJob {
    typealias Payload = UserToSync

    func dequeue(_ context: QueueContext, _ payload: UserToSync) async throws {
        context.logger.info("syncing")
        try await loadActivities(userID: payload.userID, context: context)
    }
}

enum StravaError: Error {
    case noUser, noActivity, invalidToken, tooManyRequests
}

extension SyncActivities {
    func loadActivities(userID: UUID, context: QueueContext) async throws {
        guard let user = try await User.find(userID, on: context.application.db) else {
            throw StravaError.noUser
        }
        
        let lastRideStartDate = try await user.$activities.query(on: context.application.db)
            .sort(\.$startDate, .descending)
            .first()?
            .startDate

        if let lastRideStartDate {
            context.logger.info("Last start date? \(lastRideStartDate)")
        } else {
            context.logger.info("No sync before, loading all")
        }

        try await user.$stravaToken.load(on: context.application.db)

        guard let accessToken = try await user.stravaToken?.getAccessToken(app: context.application) else {
            throw StravaError.invalidToken
        }
        
        var activities = [SummaryActivity]()
        var page = 1
        while true {
            context.logger.info("Loading page: \(page)")
            let response = try await context.application.client.get("https://www.strava.com/api/v3/athlete/activities") { req in
                var query = [
                    "page": "\(page)",
                    "per_page": "30"
                ]
                if let date = lastRideStartDate {
                    query["after"] = "\(Int(date.timeIntervalSince1970))"
                }
                try req.query.encode(query)
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }
            
            if response.status == .tooManyRequests {
                throw StravaError.tooManyRequests
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let newAct = try response.content.decode([SummaryActivity].self, using: decoder)
            if !newAct.isEmpty {
                activities.append(contentsOf: newAct)
                page += 1
            } else {
                break
            }
        }

        let existingIDs = Set(try await StravaActivity.query(on: context.application.db).field(\.$stravaID).all().map { $0.stravaID })

        context.logger.info("Existing ids in database: \(existingIDs.count)")

        let stravaActivities = activities
            .filter { !existingIDs.contains($0.id) }
            .map { StravaActivity(activity: $0, userID: user.id!) }

        context.logger.info("Adding activities to database: \(stravaActivities.count)")

        try await stravaActivities.create(on: context.application.db)
        
        context.logger.info("Syncing details of every activity")
        
        for activity in try await user.$activities.query(on: context.application.db).all() {
            try await context.queue.dispatch(
                SyncDetailedActivity.self,
                .init(activityID: try activity.requireID(), forced: false)
            )
        }
    }
}


extension User {
    func loadActivities(req: Request) async throws {
        let lastRideStartDate = try await $activities.query(on: req.db)
            .sort(\.$startDate, .descending)
            .first()?
            .startDate

        if let lastRideStartDate {
            req.logger.info("Last start date? \(lastRideStartDate)")
        } else {
            req.logger.info("No sync before, loading all")
        }

        try await $stravaToken.load(on: req.db)

        guard let accessToken = try await stravaToken?.getAccessToken(app: req.application) else {
            throw StravaError.invalidToken
        }
        
        var activities = [SummaryActivity]()
        var page = 1
        while true {
            req.logger.info("Loading page: \(page)")
            let response = try await req.client.get("https://www.strava.com/api/v3/athlete/activities") { req in
                var query = [
                    "page": "\(page)",
                    "per_page": "30"
                ]
                if let date = lastRideStartDate {
                    query["after"] = "\(Int(date.timeIntervalSince1970))"
                }
                try req.query.encode(query)
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }
            
            if response.status == .tooManyRequests {
                throw StravaError.tooManyRequests
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let newAct = try response.content.decode([SummaryActivity].self, using: decoder)
            if !newAct.isEmpty {
                activities.append(contentsOf: newAct)
                page += 1
            } else {
                break
            }
        }

        let existingIDs = Set(try await StravaActivity.query(on: req.db).field(\.$stravaID).all().map { $0.stravaID })

        req.logger.info("Existing ids in database: \(existingIDs.count)")

        let stravaActivities = activities
            .filter { !existingIDs.contains($0.id) }
            .map { StravaActivity(activity: $0, userID: id!) }

        req.logger.info("Adding activities to database: \(stravaActivities.count)")

        try await stravaActivities.create(on: req.db)
        
        req.logger.info("Syncing details of every activity")
        
        for activity in try await $activities.query(on: req.db).all() {
            try await req.queue.dispatch(
                SyncDetailedActivity.self,
                .init(activityID: try activity.requireID(), forced: false)
            )
        }
    }
}

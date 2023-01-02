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
        context.application.logger.info("syncing")
        try await loadActivities(userID: payload.userID, app: context.application)
    }
}

enum SyncActivitiesError: Error {
    case noUser
}

extension SyncActivities {
    func loadActivities(userID: UUID, app: Application) async throws {
        guard let user = try await User.find(userID, on: app.db) else {
            throw SyncActivitiesError.noUser
        }
        
        let lastRideStartDate = try await user.$activities.query(on: app.db)
            .sort(\.$startDate, .descending)
            .first()?
            .startDate

        if let lastRideStartDate {
            app.logger.info("Last start date? \(lastRideStartDate)")
        } else {
            app.logger.info("No sync before, loading all")
        }

        try await user.$stravaToken.load(on: app.db)

        guard let accessToken = try await user.stravaToken?.getAccessToken(app: app) else {
            throw StravaError.invalidToken
        }
        
        var activities = [SummaryActivity]()
        var page = 1
        while true {
            app.logger.info("Loading page: \(page)")
            let response = try await app.client.get("https://www.strava.com/api/v3/athlete/activities") { req in
                var query = [
                    "page": "\(page)",
                    "per_page": "30"
                ]
                if let date = lastRideStartDate {
                    query["after"] = "\(Int(date.timeIntervalSince1970) - 10)"
                }
                try req.query.encode(query)
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
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

        let existingIDs = Set(try await StravaActivity.query(on: app.db).field(\.$stravaID).all().map { $0.stravaID })

        app.logger.info("Existing ids in database: \(existingIDs.count)")

        let stravaActivities = activities
            .filter { !existingIDs.contains($0.id) }
            .map { StravaActivity(activity: $0, userID: user.id!) }

        app.logger.info("Adding activities to database: \(stravaActivities.count)")

        try await stravaActivities.create(on: app.db)
    }
}

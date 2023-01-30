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

        let connector = StravaConnector(user: user, client: context.application.client, db: context.application.db)

        try await user.loadActivities(connector: connector, app: context.application)

    }
}

extension User {
    
    func loadActivities(connector: StravaConnector, app: Application) async throws {
        let lastRideStartDate = try await $activities.query(on: connector.db)
            .sort(\.$startDate, .descending)
            .first()?
            .startDate

        if let lastRideStartDate {
            connector.logger.info("Last start date? \(lastRideStartDate)")
        } else {
            connector.logger.info("No sync before, loading all")
        }
       
        var activities = [SummaryActivity]()
        var page = 1
        while true {
            connector.logger.info("Loading page: \(page)")
            var query = [
                "page": "\(page)",
                "per_page": "30"
            ]
            if let date = lastRideStartDate {
                query["after"] = "\(Int(date.timeIntervalSince1970))"
            }

            let newActivities: [SummaryActivity] = try await connector.get(path: "api/v3/athlete/activities", query: query)
            
            guard !newActivities.isEmpty else { break }

            activities.append(contentsOf: newActivities)
            page += 1
        }

        let existingIDs = Set(try await StravaActivity.query(on: connector.db).field(\.$stravaID).all().map { $0.stravaID })

        connector.logger.info("Existing ids in database: \(existingIDs.count)")

        let stravaActivities = activities
            .filter { !existingIDs.contains($0.id) }
            .map { StravaActivity(activity: $0, userID: id!) }

        connector.logger.info("Adding activities to database: \(stravaActivities.count)")

        try await stravaActivities.create(on: connector.db)
        
        connector.logger.info("Syncing details of every activity")
        
        for activity in try await $activities.query(on: connector.db).all() {
            try await app.queues.queue.dispatch(SyncDetailedActivity.self, .init(activityID: activity.id!, forced: false))
        }
    }
}

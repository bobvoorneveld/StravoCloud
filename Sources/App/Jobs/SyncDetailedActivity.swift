//
//  File.swift
//  
//
//  Created by Bob Voorneveld on 02/01/2023.
//

import Foundation
import Queues
import FluentKit
import Vapor


struct DetailedActivityPayload: Codable {
    let activityID: UUID
    let forced: Bool
}

struct SyncDetailedActivity: AsyncJob {
    typealias Payload = DetailedActivityPayload

    func dequeue(_ context: QueueContext, _ payload: DetailedActivityPayload) async throws {
        context.logger.info("fetching details of activity: \(payload.activityID)")
        
        guard let activity = try await StravaActivity.query(on: context.application.db)
            .filter(\.$id == payload.activityID)
            .with(\.$user, { user in
                user.with(\.$stravaToken)
            })
            .first() else {
            throw StravaError.noActivity
        }
        
        guard payload.forced || activity.detailedLine == nil else {
            context.logger.info("Already fetched, not forced, done")
            return
        }
        
        guard let accessToken = try await activity.user.stravaToken?.getAccessToken(app: context.application) else {
            throw StravaError.invalidToken
        }
        
        let response = try await context.application.client.get("https://www.strava.com/api/v3/activities/\(activity.stravaID)") { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }
        
        if response.status == .tooManyRequests {
            // go again after 15 minutes
            try await context.queue.dispatch(
                SyncDetailedActivity.self,
                payload,
                delayUntil: Date(timeIntervalSinceNow: 60 * 15) // Rate limit of 100 every 15 minutes
            )
            throw StravaError.tooManyRequests
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let newAct = try response.content.decode(SummaryActivity.self, using: decoder)
        
        try await activity.update(with: newAct, on: context.application.db)
        
        context.logger.info("Getting the tiles for activity: \(payload.activityID)")
        try await activity.getTiles(on: context.application.db, forced: true)

        context.logger.info("Getting the counties for activity: \(payload.activityID)")
        try await activity.getCounties(on: context.application.db, forced: true)

        context.logger.info("Details saved of activity: \(payload.activityID)")
    }
}

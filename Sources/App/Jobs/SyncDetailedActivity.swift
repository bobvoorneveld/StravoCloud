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
        
        guard let accessToken = try await activity.user.stravaToken?.getAccessToken(app: context.application) else {
            throw StravaError.invalidToken
        }
        
        let response = try await context.application.client.get("https://www.strava.com/api/v3/activities/\(activity.stravaID)") { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
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

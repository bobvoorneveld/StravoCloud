//
//  jobs.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Vapor
import QueuesRedisDriver


func setupJobs(app: Application) throws {
    try app.queues.use(.redis(url: "redis://127.0.0.1:6379"))    

    app.queues.add(SyncActivities())
    app.queues.add(SyncDetailedActivity())
    
    if app.environment == .development {
        try app.queues.startInProcessJobs(on: .default)
    }

}

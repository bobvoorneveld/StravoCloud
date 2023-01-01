//
//  StravaMap.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Foundation

struct StravaMap: Codable, Identifiable {
    let id: String
    let summaryPolyline: String
    let polyline: String?
}

//
//  StravaActivity+GeoJSON.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import GeoJSON

extension StravaActivity {
    var summaryFeature: Feature {
        return Feature(geometry:
                .lineString(
                    try! .init(coordinates:
                                summaryLine.points.map {
                                .init(longitude: $0.x, latitude: $0.y)
                            }
                         )
                ), properties: [
                    "name": "\(name)",
                    "stroke": "#f60909",
                    "stroke-width": 2,
                    "stroke-opacity": 1
                ]
        )
    }
    
    var feature: Feature {
        let line = detailedLine ?? summaryLine
        return Feature(geometry:
                .lineString(
                    try! .init(coordinates:
                            line.points.map {
                                .init(longitude: $0.x, latitude: $0.y)
                            }
                         )
                ), properties: [
                    "name": "\(name)",
                    "stroke": "#f60909",
                    "stroke-width": 2,
                    "stroke-opacity": 1
                ]
        )
    }
    
    var tileFeatures: [Feature] {
        tiles.map { $0.feature }
    }
    
    var countyFeatures: [Feature] {
        counties.map { $0.feature }
    }
    
    var features: [Feature] {
        countyFeatures + tileFeatures + [feature]
    }
    
    var featureCollection: FeatureCollection {
        FeatureCollection(features: features)
    }
}

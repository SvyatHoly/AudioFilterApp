//
//  FilterPreset.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import Foundation

struct FilterPreset: Identifiable, Equatable {
    static func == (lhs: FilterPreset, rhs: FilterPreset) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    
    struct Distortion {
        var value: Float = -6
        var mix: Float = 0
    }
    
    let name: String
    let reverberation: Float
    let pitch: Float
    let speed: Float
    let distortion: Distortion
    
    init(name: String, reverberation: Float = 0, pitch: Float = 0, speed: Float = 1, distortion: FilterPreset.Distortion = .init()) {
        self.name = name
        self.reverberation = reverberation
        self.pitch = pitch
        self.speed = speed
        self.distortion = distortion
    }
}

enum DefaultFilterPresets: RawRepresentable, CaseIterable {
    
    typealias RawValue = FilterPreset
    
    case clear
    case man
    case monster
    case girl
    case hall
    
    init?(rawValue: FilterPreset) {
        switch rawValue.name {
        case "clear": self = .clear
        case "man": self = .man
        case "monster": self = .monster
        case "girl": self = .girl
        case "hall": self = .hall
        default:
            self = .clear
        }
    }
    
    var rawValue: FilterPreset {
        switch self {
        case .clear: return .init(name: "clear")
        case .man: return .init(name: "man", pitch:  -500)
        case .monster: return .init(name: "monster", reverberation: 100, pitch: -500, distortion: .init(value: 10, mix: 10))
        case .girl: return .init(name: "girl", reverberation: 0, pitch: 500)
        case .hall: return .init(name: "hall", reverberation: 500)
        }
    }
}

//
//  SecretsDecoder.swift
//  weatherapp
//
//  Created by tope akintola on 16/12/2025.
//

import Foundation

enum Secrets {
    static var weatherAPIKey : String {
        guard let Mainkey = Bundle.main.infoDictionary?["apiKey"] as? String else {
            fatalError("Weather API key is not found in CHeck .xcconfig")
        }
        return Mainkey
    }
}

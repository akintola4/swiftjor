//
//  Decoder.swift
//  cryptoApp
//
//  Created by tope akintola on 16/12/2025.
//

import SwiftUI


enum  Secerts{
    static var ThisApiKey : String  {
        guard let MainKey = Bundle.main.infoDictionary?["apiKey"] as? String else {
            fatalError("Api Key Not Found")
        }
        return MainKey
    }
}

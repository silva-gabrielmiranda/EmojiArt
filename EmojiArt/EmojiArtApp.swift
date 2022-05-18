//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Gabriel Miranda on 10/04/22.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    
    let document = EmojiArtDocument()
    
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: document)
        }
    }
}

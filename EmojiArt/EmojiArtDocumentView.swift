//
//  ContentView.swift
//  EmojiArt
//
//  Created by Gabriel Miranda on 10/04/22.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    
    @ObservedObject var document: EmojiArtDocument
    
    let defaultEmojiFontSize: CGFloat = 40
    var body: some View {
        VStack(spacing: 0){
            documentBody
            palette
        }
    }
    
    var documentBody: some View{
        GeometryReader{ geometry in
            ZStack{
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .position(convertFromEmojiCoordinates((0,0), in: geometry))
                )
                    .gesture(doubleTapToZoom(in: geometry.size))
                    .gesture(singleTapToDeselectAll())
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView()
                        .scaleEffect(2)
                }
                else {
                    ForEach(document.emojis) { emoji in
                        emojiHandler(emoji, in: geometry)
                    }
                }
            }
                .clipped()
                .onDrop(of: [.plainText, .url, .image], isTargeted: nil){ providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
                .gesture(panGesture().simultaneously(with: zoomGesture()))
        }
    }
    
    @ViewBuilder
    private func emojiHandler(_ emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> some View{
        if let _ = selectedEmojis.firstIndex(of: emoji){
            Text(emoji.text)
                .font(.system(size: fontSize(for: emoji)))
                .underline()
                .scaleEffect(zoomScale)
                .position(position(for: emoji, in: geometry))
                .gesture(singleTapToSelect(emoji))
        } else {
            Text(emoji.text)
                .font(.system(size: fontSize(for: emoji)))
                .scaleEffect(zoomScale)
                .position(position(for: emoji, in: geometry))
                .gesture(singleTapToSelect(emoji))
        }
    }
    
    private func singleTapToSelect(_ emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded{
                selectEmoji(emoji)
            }
    }
    
    private func singleTapToDeselectAll() -> some Gesture {
        TapGesture(count: 1)
            .onEnded{
                selectedEmojis.removeAll()
            }
    }
    
    @State private var selectedEmojis = Set<EmojiArtModel.Emoji>()
    
    private func selectEmoji(_ emoji: EmojiArtModel.Emoji){
        if let _ = selectedEmojis.firstIndex(of: emoji){
            selectedEmojis.remove(emoji)
        }
        else {
            selectedEmojis.insert(emoji)
        }
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(EmojiArtModel.Background.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0){
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji{
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        
        return found
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    @State var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset){ lastestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = lastestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    @State var steadyStateZoomScale: CGFloat = 1
    @GestureState var gestureZoomScale: CGFloat = 1
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, transaction in
                gestureZoomScale = latestGestureScale
                
            }
            .onEnded { gestureScaleAtEnd in
                steadyStateZoomScale *= gestureScaleAtEnd
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation{
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?,in size: CGSize){
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    var palette: some View{
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    let testEmojis = "😊☺️🚀🙂🥲﹕😇🤣🔥🗼🎠🏡🤬💩🦾✌🏻🤟🏻🤘🏻👌🏻🤌🏻🤏🏻👈🏻💄💋👄🖕🏼✍🏻🦶🏻👃🏻👁👀"
}

struct ScrollingEmojisView: View{
    let emojis: String
    
    var body: some View{
        ScrollView(.horizontal){
            HStack{
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}

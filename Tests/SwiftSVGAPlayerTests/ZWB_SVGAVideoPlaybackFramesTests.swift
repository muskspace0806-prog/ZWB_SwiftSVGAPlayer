import CoreGraphics
import XCTest
@testable import SwiftSVGAPlayer

final class SVGAVideoPlaybackFramesTests: XCTestCase {

    func test_playbackFrames_trimTrailingEmptyFrames_whenSpriteFramesExceedDeclaredFrames() {
        var frames = Array(repeating: SVGAFrame(), count: 37)
        frames[34] = visibleFrame()

        let video = makeVideo(declaredFrames: 36, spriteFrames: frames)

        XCTAssertEqual(video.frames, 36)
        XCTAssertEqual(video.playbackFrames, 35)
    }

    func test_playbackFrames_keepsDeclaredFrames_whenLastDeclaredFrameIsRenderable() {
        var frames = Array(repeating: SVGAFrame(), count: 36)
        frames[35] = visibleFrame()

        let video = makeVideo(declaredFrames: 36, spriteFrames: frames)

        XCTAssertEqual(video.playbackFrames, 36)
    }

    func test_playbackFrames_keepsDeclaredFrames_whenThereIsNoRenderableContent() {
        let frames = Array(repeating: SVGAFrame(), count: 36)

        let video = makeVideo(declaredFrames: 36, spriteFrames: frames)

        XCTAssertEqual(video.playbackFrames, 36)
    }

    func test_playbackFrames_ignoresRenderableFramesBeyondDeclaredFrameCount() {
        var frames = Array(repeating: SVGAFrame(), count: 38)
        frames[35] = visibleFrame()
        frames[37] = visibleFrame()

        let video = makeVideo(declaredFrames: 36, spriteFrames: frames)

        XCTAssertEqual(video.playbackFrames, 36)
    }

    func test_playbackFrames_countsVectorShapesAsRenderable() {
        var frames = Array(repeating: SVGAFrame(), count: 12)
        let shape = SVGAShape(
            type: .rect,
            style: SVGAShapeStyle(fillColor: nil),
            rectArgs: CGRect(x: 0, y: 0, width: 12, height: 12)
        )
        frames[9] = SVGAFrame(shapes: [shape])

        let video = makeVideo(declaredFrames: 12, spriteFrames: frames)

        XCTAssertEqual(video.playbackFrames, 10)
    }

    private func makeVideo(declaredFrames: Int, spriteFrames: [SVGAFrame]) -> SVGAVideo {
        let sprite = SVGASprite(imageKey: "image", matteKey: nil, frames: spriteFrames)
        return SVGAVideo(
            size: CGSize(width: 400, height: 400),
            fps: 18,
            frames: declaredFrames,
            sprites: [sprite],
            images: [:],
            audios: []
        )
    }

    private func visibleFrame() -> SVGAFrame {
        SVGAFrame(layout: SVGALayout(x: 0, y: 0, width: 20, height: 20))
    }
}

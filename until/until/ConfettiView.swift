//
//  ConfettiView.swift
//  until
//
//  A lightweight one-shot confetti burst drawn in a Canvas. Pieces fall, sway, and
//  spin, then exit the bottom — no external assets.
//

import SwiftUI

struct ConfettiView: View {
    var colors: [Color] = [
        Color(red: 0.91, green: 0.27, blue: 0.13),
        Color(red: 0.95, green: 0.62, blue: 0.07),
        Color(red: 0.20, green: 0.65, blue: 0.33),
        Color(red: 0.15, green: 0.39, blue: 0.92),
        Color(red: 0.49, green: 0.23, blue: 0.93),
    ]

    @State private var start = Date()
    private let pieces: [Piece] = (0..<80).map { _ in Piece.random() }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            Canvas { g, size in
                for p in pieces {
                    let age = t - p.delay
                    guard age > 0 else { continue }
                    let y = age * p.speed * size.height - 30
                    guard y < size.height + 40 else { continue }
                    let x = p.x * size.width + sin(age * p.sway + p.phase) * 26
                    let w = p.size, h = p.size * 0.5

                    var layer = g
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(age * p.spin + p.phase))
                    let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                    layer.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(colors[p.colorIndex % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private struct Piece {
        let x, delay, speed, sway, phase, spin, size: Double
        let colorIndex: Int

        static func random() -> Piece {
            Piece(
                x: .random(in: 0...1),
                delay: .random(in: 0...0.5),
                speed: .random(in: 0.28...0.5),
                sway: .random(in: 1.5...3.5),
                phase: .random(in: 0...(2 * .pi)),
                spin: .random(in: -4...4),
                size: .random(in: 7...12),
                colorIndex: Int.random(in: 0...4)
            )
        }
    }
}

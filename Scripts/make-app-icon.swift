#!/usr/bin/env swift
//
// Zeichnet das App-Zeichen.
//
// Ein Skript und keine abgelegte Bilddatei: so ist nachvollziehbar, woraus das
// Zeichen besteht, und eine Aenderung ist eine Zeile statt einer Sitzung in einem
// Bildprogramm. Aufruf:
//
//     swift Scripts/make-app-icon.swift App/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// ## Was es zeigt, und warum
//
// Die Karte mit dem gerahmten Ziffernfeld unten rechts - dasselbe Motiv, das die
// Eingabemaske zeigt, und die einzige Angabe, um die es beim Aufschliessen der
// CIE geht. Kein Text: bei 60 Punkten waere er unleserlich, und was dann noch
// bleibt, ist ein Fleck. Uebrig bleibt hier eine Karte, und das ist richtig.
//
// Kein Siegel und kein Haken. Beides sind in dieser App **Urteile** ueber ein
// einzelnes Dokument - ein gruener Haken auf dem Zeichen wuerde behaupten, es
// sei etwas bestaetigt, bevor irgendetwas gelesen wurde.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0
let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "icon-1024.png")

guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else { fatalError("Kein Zeichenkontext") }

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// --- Grund: das Blau der Identitaetskarte, von oben nach unten vertieft -------
// Dieselben Werte wie `DocumentPalette.cardLight.primary` und der Kopfbereich des
// Lesescreens. Das Zeichen soll aussehen wie der Anfang dieser App.
let gradient = CGGradient(
    colorsSpace: space,
    colors: [colour(0x0B5CB0), colour(0x073C74)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: side),
    end: CGPoint(x: side, y: 0),
    options: []
)

// --- Die Karte ----------------------------------------------------------------
// ID-1 nach ISO/IEC 7810, also dieselbe Form wie die Grafik in der Maske. Sie
// steht leicht ueber der Mitte: unter ihr braucht das Ziffernfeld Luft.
// Die Karte nimmt drei Viertel der Breite. Kleiner gedacht war sie zuerst und
// verlor damit bei 60 Punkten ihre Form - ein Zeichen wird in der Uebersicht
// gesehen und nicht in der Vorschau.
let cardWidth = side * 0.74
let cardHeight = cardWidth / (85.60 / 53.98)
let card = CGRect(
    x: (side - cardWidth) / 2,
    y: (side - cardHeight) / 2 - side * 0.015,
    width: cardWidth,
    height: cardHeight
)
let cardPath = CGPath(
    roundedRect: card,
    cornerWidth: side * 0.035,
    cornerHeight: side * 0.035,
    transform: nil
)

// Ein Schatten, damit die Karte auf dem Blau aufliegt und nicht darin verschwindet.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -side * 0.012), blur: side * 0.03,
                  color: colour(0x000000, 0.28))
context.addPath(cardPath)
context.setFillColor(colour(0xF4F8FE))
context.fillPath()
context.restoreGState()

// --- Lichtbild links ----------------------------------------------------------
let unit = card.height / 10
let photo = CGRect(
    x: card.minX + unit * 0.9,
    y: card.minY + unit * 3.1,
    width: unit * 2.4,
    height: unit * 3.2
)
context.addPath(CGPath(roundedRect: photo, cornerWidth: unit * 0.3,
                       cornerHeight: unit * 0.3, transform: nil))
context.setFillColor(colour(0xCBB56B, 0.55))
context.fillPath()

// --- Angedeutete Zeilen rechts daneben ---------------------------------------
context.setFillColor(colour(0x454A52, 0.30))
for (index, width) in [4.6, 3.8, 3.0].enumerated() {
    let line = CGRect(
        x: photo.maxX + unit * 0.9,
        y: photo.maxY - unit * 0.55 - CGFloat(index) * unit * 0.95,
        width: unit * width,
        height: unit * 0.42
    )
    context.addPath(CGPath(roundedRect: line, cornerWidth: line.height / 2,
                           cornerHeight: line.height / 2, transform: nil))
    context.fillPath()
}

// --- Das gerahmte Ziffernfeld unten rechts ------------------------------------
// Die eigentliche Aussage des Zeichens: hier steht die Zahl, mit der sich der
// Chip oeffnen laesst. Die Ziffern sind Balken und keine Schrift - bei 60 Punkten
// waere eine echte Ziffer ohnehin nicht zu lesen, und ein Balkenmuster bleibt als
// Muster erkennbar.
let box = CGRect(
    x: card.maxX - unit * 4.6,
    y: card.minY + unit * 0.95,
    width: unit * 3.7,
    height: unit * 1.55
)
context.addPath(CGPath(roundedRect: box, cornerWidth: unit * 0.22,
                       cornerHeight: unit * 0.22, transform: nil))
context.setStrokeColor(colour(0x0B5CB0))
context.setLineWidth(unit * 0.17)
context.strokePath()

context.setFillColor(colour(0x0B5CB0, 0.85))
let digitWidth = unit * 0.34
let gap = (box.width - unit * 0.5 - digitWidth * 6) / 5
for index in 0..<6 {
    let digit = CGRect(
        x: box.minX + unit * 0.25 + CGFloat(index) * (digitWidth + gap),
        y: box.midY - unit * 0.42,
        width: digitWidth,
        height: unit * 0.84
    )
    context.addPath(CGPath(roundedRect: digit, cornerWidth: digitWidth / 2,
                           cornerHeight: digitWidth / 2, transform: nil))
    context.fillPath()
}

// --- Schreiben ----------------------------------------------------------------
guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        output as CFURL, UTType.png.identifier as CFString, 1, nil
      )
else { fatalError("Kein Bild") }

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Nicht geschrieben") }
print("geschrieben: \(output.path) (\(Int(side))x\(Int(side)))")

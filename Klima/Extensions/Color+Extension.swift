//
//  Color+Extension.swift
//  Klima
//
//  Created by Jesse Rubio on 4/20/26.
//

import SwiftUI

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let klimaWhite = Color.white
    static let klimaBlack = Color.black

    static func klimaWhite(_ opacity: Double) -> Color {
        .white.opacity(opacity)
    }

    static func klimaBlack(_ opacity: Double) -> Color {
        .black.opacity(opacity)
    }

    // City List
    static let klimaListDayBase = Color(hex: 0xD1E6FA)
    static let klimaListDayTop = Color(hex: 0xEBF5FF)
    static let klimaListDayMid = Color(hex: 0xBDDDF9)
    static let klimaListDayBottom = Color(hex: 0xA8CCF2)
    static let klimaListSunGlow = Color(hex: 0xFFECC2)
    static let klimaListNightBase = Color(hex: 0x1A212B)
    static let klimaListNightTop = Color(hex: 0x2E3647)
    static let klimaListNightBottom = Color(hex: 0x1C212B)
    static let klimaMenuOverlay = Color(hex: 0x171A24)
    static let klimaSearchSurface = Color(hex: 0x171C26)
    static let klimaCardDayTop = Color(hex: 0xBAD9F7)
    static let klimaCardDayBottom = Color(hex: 0x8AB8ED)
    static let klimaCardNightTop = Color(hex: 0x4A4778)
    static let klimaCardNightBottom = Color(hex: 0x2B2E4D)

    // Weather Symbols
    static let klimaStormLightningDay = Color(hex: 0xFBC233)
    static let klimaStormLightningNight = Color(hex: 0xFDD761)
    static let klimaRainBlueDay = Color(hex: 0x2E61B8)
    static let klimaRainBlueNight = Color(hex: 0x9EC7F5)
    static let klimaSunOrangeDay = Color(hex: 0xF29E24)
    static let klimaSunOrangeNight = Color(hex: 0xFCCA59)
    static let klimaCloudSteelBlue = Color(hex: 0xCCDBE3)
    static let klimaWarmCloudAccent = Color(hex: 0xF2C757)
    static let klimaWarmAccentDay = Color(hex: 0xF09C2B)
    static let klimaWarmAccentNight = Color(hex: 0xFACC59)
    static let klimaHeavyRainCloudDay = Color(hex: 0x325057)
    static let klimaRainCloudDay = Color(hex: 0x576B85)
    static let klimaRainCloudNight = Color(hex: 0xB3C2DB)
    static let klimaThunderstormTeal = Color(hex: 0x0D3F47)
    static let klimaSnowWhite = Color(hex: 0xFCFBF5)
    static let klimaOvercastGray = Color(hex: 0xA7B8C4)
    static let klimaFogCloud = Color(hex: 0xF7F5F9)
    static let klimaCloudyDay = Color(hex: 0xACC2D9)
    static let klimaMoonlitCloud = Color(hex: 0xF7F7FE)
    static let klimaSunHighlightDay = Color(hex: 0xFDD14D)
    static let klimaSunHighlightNight = Color(hex: 0xFDE080)
    static let klimaAccentSlateDay = Color(hex: 0x66758F)
    static let klimaAccentSlateNight = Color(hex: 0xB8C7E0)
    static let klimaStormRainDay = Color(hex: 0x3B8AD6)
    static let klimaStormRainNight = Color(hex: 0x94CCFA)
    static let klimaRainDropDay = Color(hex: 0x0A84FF)
    static let klimaRainDropNight = Color(hex: 0x0A84FF)
    static let klimaRainAnimationGray = Color(hex: 0x6F7A86)

    // Lightning and Moon
    static let klimaLightningFlashBlue = Color(hex: 0xD1E0FF)
    static let klimaStormFlashGlow = Color(hex: 0xEBF5FF)
    static let klimaMoonTint = Color(hex: 0xF2E6B8)
    static let klimaMoonHighlight = Color(hex: 0xFFF4CF)

    // Backdrop
    static let klimaBackdropNightTop = Color(hex: 0x0D1221)
    static let klimaBackdropNightMid = Color(hex: 0x141C33)
    static let klimaBackdropNightBottom = Color(hex: 0x1A213B)
    static let klimaBackdropSunriseTop = Color(hex: 0x85739E)
    static let klimaBackdropSunriseMid = Color(hex: 0xF5B57A)
    static let klimaBackdropSunriseBottom = Color(hex: 0xFFE3AB)
    static let klimaBackdropDayTop = Color(hex: 0xF0F2F7)
    static let klimaBackdropDayMid = Color(hex: 0xE3EBF5)
    static let klimaBackdropDayBottom = Color(hex: 0xD1E0F5)
    static let klimaBackdropDayBlueTop = Color(hex: 0x3674AF)
    static let klimaBackdropDayBlueBottom = Color(hex: 0x5498D8)
    static let klimaBackdropRainBase = Color(hex: 0x64808E)
    static let klimaBackdropThunderBase = Color(hex: 0x3F5564)
    static let klimaBackdropDrizzleBase = Color(hex: 0xB8C1C8)
    static let klimaBackdropSunsetTop = Color(hex: 0xFFBD7A)
    static let klimaBackdropSunsetMid = Color(hex: 0xC9758A)
    static let klimaBackdropSunsetBottom = Color(hex: 0x382E5C)
    static let klimaTopGlowBlue = Color(hex: 0x546BC2)
    static let klimaStormCeilingTopDay = Color(hex: 0x2D3B46)
    static let klimaStormCeilingLowerDay = Color(hex: 0x4C6170)
    static let klimaStormCeilingTopNight = Color(hex: 0x0D1420)
    static let klimaStormCeilingLowerNight = Color(hex: 0x1D2A38)
    static let klimaStormCeilingMistDay = Color(hex: 0x9FB4C5)
    static let klimaStormCeilingMistNight = Color(hex: 0x5F7894)

    // Sunrise and Sunset
    static let klimaSunriseIconDay = Color(hex: 0xEB782E)
    static let klimaSunriseIconNight = Color(hex: 0xFABD54)
    static let klimaSunsetIconDay = Color(hex: 0xDB5C38)
    static let klimaSunsetIconNight = Color(hex: 0xF5AD59)
    static let klimaSunScheduleIconDay = Color(hex: 0xF09E2E)
    static let klimaSunScheduleIconNight = Color(hex: 0xFAC757)

    // Text and Dividers
    static let klimaTextDayPrimary = Color.black.opacity(0.92)
    static let klimaTextDaySecondary = Color.black.opacity(0.55)
    static let klimaTextDayTertiary = Color.black.opacity(0.45)
    static let klimaTextNightPrimary = Color.white.opacity(0.95)
    static let klimaTextNightEmphasis = Color.white.opacity(0.78)
    static let klimaTextNightSecondary = Color.white.opacity(0.62)
    static let klimaTextNightTertiary = Color.white.opacity(0.54)
    static let klimaDividerDay = Color.black.opacity(0.06)
    static let klimaDividerNight = Color.white.opacity(0.09)
}

pragma Singleton
import QtQuick

QtObject {
    id: root

    // Theme Mode: true = Night (Dark), false = Day (Light)
    property bool isDarkMode: true

    function toggleTheme() {
        isDarkMode = !isDarkMode;
    }

    // Windows 11 Fluent typography stack
    readonly property string fontFamily: "Segoe UI, Segoe UI Variable Text, Aptos, Inter, sans-serif"
    readonly property string iconFontFamily: "Material Icons Round"

    // Background Layers (Windows 11 Mica / Acrylic / Card Hierarchy)
    // Dark Theme: Sleek, deeper dark neutral grays
    readonly property color bgMain:       isDarkMode ? "#111215" : "#f3f3f5"
    readonly property color bgSurface:    isDarkMode ? "#18191d" : "#ffffff"
    readonly property color bgCard:       isDarkMode ? "#1f2025" : "#fbfbfd"
    readonly property color bgElevated:   isDarkMode ? "#282930" : "#ebebf0"
    readonly property color bgInput:      isDarkMode ? "#141518" : "#f6f6f8"
    readonly property color bgHover:      isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color bgActive:     isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)

    // Dark Shade Gray Accent Range (#444, #555) for Background Surfaces & Borders
    readonly property color bgAccent:         isDarkMode ? "#444448" : "#e6e6ea"
    readonly property color bgAccentHover:    isDarkMode ? "#55555c" : "#d8d8de"
    readonly property color bgAccentActive:   isDarkMode ? "#38383c" : "#ceced6"
    readonly property color bgAccentBorder:   isDarkMode ? "#55555c" : "#c4a768"

    // Vibrant Gold Accents (Popups, Buttons, Icons, Badges)
    readonly property color goldPrimary:    isDarkMode ? "#e5c158" : "#b0821e"
    readonly property color goldHover:      isDarkMode ? "#ebd480" : "#986f16"
    readonly property color goldDark:       isDarkMode ? "#6b5314" : "#7d5d12"
    readonly property color goldLight:      isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.15) : Qt.rgba(0.69, 0.51, 0.12, 0.12)
    readonly property color goldLightHover: isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.25) : Qt.rgba(0.69, 0.51, 0.12, 0.22)
    readonly property color goldBorder:     isDarkMode ? "#3c3422" : "#dfd5bd"
    readonly property color goldBorderHi:   isDarkMode ? "#7a653c" : "#c4a768"
    readonly property color borderFocus:    isDarkMode ? "#c4a768" : "#986f16"
    readonly property color textOnGold:     isDarkMode ? "#0d0e11" : "#ffffff"

    // Semantic Aliases for Modern UI
    readonly property color accentPrimary:    goldPrimary
    readonly property color accentHover:      goldHover
    readonly property color accentDark:       goldDark
    readonly property color accentLight:      goldLight
    readonly property color accentLightHover: goldLightHover
    readonly property color accentBorder:     goldBorder
    readonly property color accentBorderHi:   goldBorderHi
    readonly property color textOnAccent:     textOnGold

    // Typography
    readonly property color textMain:     isDarkMode ? "#f4f4f6" : "#1a1b1f"
    readonly property color textMuted:    isDarkMode ? "#8e919e" : "#5d616e"
    readonly property color textSubtle:   isDarkMode ? "#636776" : "#8a8e9d"

    // Fluent System Structural Elements
    readonly property color borderSubtle: isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color borderCard:   isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.22) : Qt.rgba(0.69, 0.51, 0.12, 0.25)
    readonly property color divider:      isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color overlayModal: isDarkMode ? Qt.rgba(0, 0, 0, 0.70) : Qt.rgba(0, 0, 0, 0.35)
    readonly property color shadowColor:  isDarkMode ? Qt.rgba(0, 0, 0, 0.50) : Qt.rgba(0, 0, 0, 0.08)

    // Alert & Diagnostic Colors (Errors, Warnings, Success)
    readonly property color errorColor:   isDarkMode ? "#ef4444" : "#dc2626"
    readonly property color errorBg:      isDarkMode ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.18) : Qt.rgba(220 / 255, 38 / 255, 38 / 255, 0.12)
    readonly property color errorBorder:  isDarkMode ? Qt.rgba(0.9, 0.32, 0.32, 0.5) : Qt.rgba(0.85, 0.25, 0.25, 0.6)
    readonly property color warningColor: isDarkMode ? "#fbbf24" : "#d97706"
    readonly property color successColor: isDarkMode ? "#10b981" : "#059669"

    // Job / MultiPart Status Colors (Moved from MultiPartProgressBar.qml)
    readonly property color statusIdle:     isDarkMode ? "#475569" : "#838b99"
    readonly property color statusPending:  isDarkMode ? "#5c6b84" : "#64748b"
    readonly property color statusRunning:  isDarkMode ? "#2e8b57" : "#228b50"
    readonly property color statusPaused:   isDarkMode ? goldPrimary : goldHover
    readonly property color statusAborted:  isDarkMode ? "#c86541" : "#b05232"
    readonly property color statusFailed:   isDarkMode ? "#cd5c5c" : "#b23a3a"
    readonly property color statusFinished: isDarkMode ? "#236d43" : "#1a6b3e"

    // Recovery Tool Diagnostics & States (Moved from ArchiveRecoveryTools.qml)
    readonly property color recoverySeaGreen:       "#10B981"
    readonly property color recoverySeaGreenBg:     isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.20) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14)
    readonly property color recoverySeaGreenBorder: isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.45) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35)

    readonly property color recoveryTruncatedHatch:  isDarkMode ? Qt.rgba(0.55, 0.58, 0.68, 0.30) : Qt.rgba(0.40, 0.45, 0.55, 0.24)
    readonly property color recoveryTruncatedBg:     isDarkMode ? Qt.rgba(0.35, 0.38, 0.45, 0.14) : Qt.rgba(0.50, 0.55, 0.65, 0.10)
    readonly property color recoveryTruncatedBorder: isDarkMode ? Qt.rgba(0.55, 0.58, 0.68, 0.40) : Qt.rgba(0.40, 0.45, 0.55, 0.30)

    readonly property color recoveryNotFoundHatch:  isDarkMode ? Qt.rgba(0.95, 0.30, 0.30, 0.35) : Qt.rgba(0.85, 0.20, 0.20, 0.28)
    readonly property color recoveryNotFoundBg:     isDarkMode ? Qt.rgba(0.90, 0.20, 0.20, 0.16) : Qt.rgba(0.90, 0.15, 0.15, 0.08)
    readonly property color recoveryNotFoundBorder: isDarkMode ? Qt.rgba(0.95, 0.30, 0.30, 0.45) : Qt.rgba(0.85, 0.20, 0.20, 0.35)

    // Graph & Progress Speed Themes (Moved from SpeedGraph.qml and ProgressWindow.qml)
    readonly property color graphThemeColor:       isDarkMode ? "#2e8b57" : "#228b50"
    readonly property color graphThemeColorLight:  isDarkMode ? "#3cb371" : "#2e8b57"
    readonly property color graphThemeColorAccent: isDarkMode ? "#4ade80" : "#22c55e"
    readonly property color seaGreenPrimary:       graphThemeColor
    readonly property color seaGreenLight:         graphThemeColorLight

    // Indicators (Moved from MainWindow.qml)
    readonly property color indicatorGreen:        "#10B981"
}
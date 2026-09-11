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
    readonly property color bgMain:       isDarkMode ? "#0c0e12" : "#f3f3f5"
    readonly property color bgSurface:    isDarkMode ? "#141720" : "#ffffff"
    readonly property color bgCard:       isDarkMode ? "#1a1e28" : "#fbfbfd"
    readonly property color bgElevated:   isDarkMode ? "#222735" : "#ebebf0"
    readonly property color bgInput:      isDarkMode ? "#0e1016" : "#f6f6f8"
    readonly property color bgHover:      isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color bgActive:     isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)

    // Premium Gold Accents (High contrast in both Day & Night modes)
    readonly property color goldPrimary:    isDarkMode ? "#e5c158" : "#b0821e"
    readonly property color goldHover:      isDarkMode ? "#ebd480" : "#986f16"
    readonly property color goldDark:       isDarkMode ? "#6b5314" : "#7d5d12"
    readonly property color goldLight:      isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.15) : Qt.rgba(0.69, 0.51, 0.12, 0.12)
    readonly property color goldLightHover: isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.25) : Qt.rgba(0.69, 0.51, 0.12, 0.22)
    readonly property color goldBorder:     isDarkMode ? "#3c3422" : "#dfd5bd"
    readonly property color goldBorderHi:   isDarkMode ? "#7a653c" : "#c4a768"
    readonly property color borderFocus:    isDarkMode ? "#c4a768" : "#986f16"
    readonly property color textOnGold:     isDarkMode ? "#0d0e11" : "#ffffff"

    // Typography
    readonly property color textMain:     isDarkMode ? "#f4f4f6" : "#1a1b1f"
    readonly property color textMuted:    isDarkMode ? "#8e919e" : "#5d616e"
    readonly property color textSubtle:   isDarkMode ? "#636776" : "#8a8e9d"

    // Fluent System Structural Elements
    readonly property color borderSubtle: isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color borderCard:   isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.22) : Qt.rgba(0.69, 0.51, 0.12, 0.25)
    readonly property color divider:      isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color overlayModal: isDarkMode ? Qt.rgba(0, 0, 0, 0.65) : Qt.rgba(0, 0, 0, 0.35)
    readonly property color shadowColor:  isDarkMode ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.08)
}
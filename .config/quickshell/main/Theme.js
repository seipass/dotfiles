.pragma library

var color = {
    surface: "#11151a",
    surfaceContainer: "#1c2027",
    surfaceContainerHigh: "#272c35",
    primary: "#b6c8e2",
    primaryContainer: "#374c6c",
    onPrimary: "#1b2636",
    onSurface: "#e1e5ea",
    onSurfaceVariant: "#bbc3ce",
    outlineVariant: "#404854",
    error: "#ffb4ab",
    errorContainer: "#93000a",
    scrim: "#80000000"
};

var shape = {
    railReservation: 60,
    railWidth: 60,
    frameEdge: 10,
    frameOuterRadius: 25,
    frameInnerRadius: 25,
    islandReservation: 44,
    islandInset: 0,
    islandHeight: 40,
    islandRadius: 16,
    islandWidth: 560,
    dialogRadius: 28,
    fullRadius: 9999
};

var spacing = {
    extraSmall: 4,
    small: 8,
    medium: 12
};

var motion = {
    // Effects (opacity / color: no overshoot)
    fast: 150,
    standard: 260,
    emphasized: 360,
    exit: 200,

    // Spatial (M3 Expressive Spring-like OutBack physics)
    spatialFast: 210,
    spatial: 340,
    spatialSlow: 440,
    overshootFast: 1.35,
    overshootStandard: 1.18,
    overshootGentle: 0.72,

    // 2-Spring stretch highlight parameters
    springLead: 6.4,
    dampingLead: 0.46,
    springTrail: 2.9,
    dampingTrail: 0.52
};

function resolveEmojiFont() {
    if (typeof Qt === "undefined") return "emoji";
    var families = Qt.fontFamilies();
    var candidates = ["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", "Twemoji", "EmojiOne Color", "Noto Emoji"];
    for (var i = 0; i < candidates.length; ++i) {
        if (families.indexOf(candidates[i]) >= 0) return candidates[i];
    }
    return "emoji";
}

var font = {
    display: (typeof Qt !== "undefined" && Qt.fontFamilies().indexOf("Ndot 55") >= 0) ? "Ndot 55" : "Doto",
    ui: "Google Sans Flex",
    mono: "Ioskeley Mono Term",
    emoji: resolveEmojiFont()
};

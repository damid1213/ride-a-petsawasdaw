local NS = getgenv().Vanguard or getgenv().EggsESP

NS.Config = {
    Version = "1.0.0",

    ESPFillTransparency = 0.45,
    ESPOutlineTransparency = 0.1,
    ESPNameSize = 13,
    ESPDistanceSize = 11,

    ESPPalette = {
        Color3.fromRGB( 80, 200, 255), Color3.fromRGB(140, 100, 255),
        Color3.fromRGB(  0, 235, 130), Color3.fromRGB(255, 130,  60),
        Color3.fromRGB(255,  80, 180), Color3.fromRGB( 60, 220, 180),
        Color3.fromRGB(200, 255,  70), Color3.fromRGB(255, 200,  60),
        Color3.fromRGB( 80, 160, 255), Color3.fromRGB(220,  90, 255),
        Color3.fromRGB(255, 100, 100), Color3.fromRGB( 60, 255, 220),
    },
    ESPRareColor = Color3.fromRGB(255, 215, 0),

    TPHeight = 3,
    MovementSpeed = 350,
    HomeDepositWait = 1.3,
    AntiStuckThreshold = 2.2,
    MovementTimeBuffer = 5.0,   -- Extra seconds added on top of travel-time estimate

    ESPMaxDistance = 2500,      -- Billboards hidden beyond this stud distance

    BestEggName = "cherub",
    AutoEggHoldTime = 2.5,
    AutoFarmHoldTime = 2.0,
    AutoEggDelay = 0.4,
    EggCooldownSeconds = 12,

    RareKeywords = {
        "cherub", "huge", "exclusive", "secret", "titan",
        "mythic", "golden", "diamond", "dark", "rainbow", "celestial"
    },
    AlertDuration = 6.5,
    MaxAlerts = 3,
    AlertDedupeSeconds = 3,

    PCWidth = 760, PCHeight = 480,
    MobileWidth = 620, MobileHeight = 400,
    AnimationTime = 0.18,

    Radius2XL = 16, RadiusXL = 12, RadiusLG = 8,
    RadiusMD = 6, RadiusSM = 4,

    TextTitle = 14, TextHeader = 11, TextBody = 11,
    TextCaption = 9, TextMicro = 8,

    PadXS = 4, PadSM = 6, PadMD = 8, PadLG = 12, PadXL = 16,

    SidebarWidth = 160,
    SidebarItemHeight = 40,
    MaxHistoryLogs = 50,

    BgColor = Color3.fromHex("#171717"),
    BgTransparency = 0.02,
    OuterCardBg = Color3.fromHex("#1F1F1F"),
    OuterCardTransparency = 0.02,
    NestedCardBg = Color3.fromHex("#242424"),
    NestedCardTransparency = 0.02,
    RecessedBg = Color3.fromHex("#1A1A1A"),
    CardBorder = Color3.fromHex("#2C2C2C"),
    BorderInner = Color3.fromHex("#333333"),
    BorderTransparency = 0.35,

    AccentGreen = Color3.fromRGB(0, 230, 118),
    AccentBlue = Color3.fromRGB(0, 150, 255),
    AccentGold = Color3.fromRGB(255, 215, 0),
    AccentRed = Color3.fromRGB(255, 61, 87),

    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(163, 163, 163),
    TextMuted = Color3.fromRGB(110, 110, 110),
}

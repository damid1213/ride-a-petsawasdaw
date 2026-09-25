--[[
    LuxuryXHUB - Pull An Egg
    Config.lua - Centralized Configuration & Defaults
]]

local Config = {
    GameName = "Pull An Egg",
    PlaceId  = 70640255604878,
    GameId   = 10649255304,

    -- ── Automation Defaults ─────────────────────────────────────────
    AutoTrain        = false,
    TrainInterval    = 0.1,  -- Delay between Dumbbell clicks (seconds)

    AutoSell         = false,
    SellInterval     = 2,    -- Delay between sell attempts (seconds)

    AutoRebirth      = false,
    RebirthInterval  = 1,    -- Delay between rebirth attempts (seconds)

    AutoBuyDumbell   = false,
    AutoUpgradeCarry = false,

    AutoRevive       = true, -- Instantly click Yes on the revive prompt

    AutoBuyGear      = false,
    BuyGearId        = "6",  -- Gear ID to purchase
    BuyGearInterval  = 1,    -- Seconds between buy attempts

    AutoPullEgg      = false,
    TargetEggTier    = "Celestial",
    FlyHeight        = 16,   -- Studs above the egg spawn to hover
    SafeHover        = true, -- Float mid-air to dodge ground boss attacks

    EggESP           = true,

    -- ── Tiers (matches workspace.Map.SpawnParts folder names) ────────
    TIERS = {
        "Celestial",
        "Transcendent",
        "Divine",
        "OG",
        "Brainrot God",
        "Secret",
        "Mythic",
        "Legendary",
        "Epic",
        "Rare",
        "Common",
    },

    -- ── ESP Tier Colors ───────────────────────────────────────────────
    TIER_COLORS = {
        ["Celestial"]    = Color3.fromRGB(  0, 240, 255),
        ["Transcendent"] = Color3.fromRGB(255,   0, 128),
        ["Divine"]       = Color3.fromRGB(255, 215,   0),
        ["OG"]           = Color3.fromRGB(138,  43, 226),
        ["Brainrot God"] = Color3.fromRGB(255,  69,   0),
        ["Secret"]       = Color3.fromRGB( 75,   0, 130),
        ["Mythic"]       = Color3.fromRGB(255,  50,  50),
        ["Legendary"]    = Color3.fromRGB(255, 165,   0),
        ["Epic"]         = Color3.fromRGB(186,  85, 211),
        ["Rare"]         = Color3.fromRGB( 30, 144, 255),
        ["Common"]       = Color3.fromRGB(180, 180, 180),
    },

    -- ── UI Theme ──────────────────────────────────────────────────────
    THEME = {
        Background = Color3.fromRGB( 16,  18,  26),
        Sidebar    = Color3.fromRGB( 12,  14,  20),
        Card       = Color3.fromRGB( 24,  27,  39),
        Accent     = Color3.fromRGB(255, 170,   0), -- Golden amber
        AccentDark = Color3.fromRGB(180, 120,   0),
        Text       = Color3.fromRGB(240, 242, 245),
        SubText    = Color3.fromRGB(150, 155, 170),
        Success    = Color3.fromRGB( 46, 204, 113),
        Danger     = Color3.fromRGB(231,  76,  60),
    },
}

return Config

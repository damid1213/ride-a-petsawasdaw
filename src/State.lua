--[[
    Vanguard — State.lua
    Global reactive state store.
    Rewritten: added eggData clear in reset(), consistent naming, cleaner structure.
]]

local NS = getgenv().EggsESP
local AppConfig  = NS.Config
local S          = NS.Services

local StateStore = {
    -- ESP
    mainESPActive       = false,

    -- Auto-Farm
    autoFarmActive      = false,
    autoFarmThread      = nil,
    autoFarmEggs        = {},               -- [eggName] = true/false (selected)
    autoFarmProcessed   = setmetatable({}, {__mode = "k"}),

    -- Best Egg
    autoBestEggActive   = false,
    autoBestEggThread   = nil,

    -- Rebirth
    autoRebirthActive   = false,
    autoRebirthThread   = nil,
    missingRebirthEggs  = {},

    -- Movement
    movementActive      = false,
    movementHumanoid    = nil,
    movementMode        = "AutoFarm",       -- "AutoFarm" | "Teleport"
    noclipConnection    = nil,

    -- Egg data (weak — GC'd when egg is removed)
    eggData             = setmetatable({}, {__mode = "k"}),
    eggCooldowns        = setmetatable({}, {__mode = "k"}),

    -- Anti-AFK
    antiAFKActive       = true,
    antiAFKConnection   = nil,

    -- UI state
    isMobileMode        = false,
    isMinimized         = false,
    listeningForKey     = false,
    windowMode          = "PC",
    screenGui           = nil,
    currentSearchQuery  = "",
    sortMode            = "Name",
    tpKeybind           = Enum.KeyCode.T,

    -- Session stats
    sessionStartTime    = os.time(),
    totalEggsCollected  = 0,
    farmHistory         = {},
    onHistoryUpdated    = nil,
    onTimeUpdated       = nil,

    -- Alerts
    recentAlerts        = {},

    -- Connection tracker
    _connections        = {},

    -- UI slider counter (unique IDs for slider instances)
    _sliderCounter      = 0,
}

-- ── Track a RBXScriptConnection for bulk cleanup ─────────────────────
function StateStore.track(conn)
    if not conn then return conn end
    table.insert(StateStore._connections, conn)
    return conn
end

-- ── Disconnect all tracked connections ───────────────────────────────
function StateStore.disconnectAll()
    for _, conn in ipairs(StateStore._connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(StateStore._connections)
end

-- ── Add an egg to the farm history log ───────────────────────────────
function StateStore.addHistoryRecord(eggName)
    local lower = eggName:lower()
    local isRare = false
    for _, kw in ipairs(AppConfig.RareKeywords) do
        if lower:find(kw, 1, true) then isRare = true; break end
    end

    table.insert(StateStore.farmHistory, 1, {
        name  = eggName,
        time  = os.date("%H:%M:%S"),
        isRare = isRare,
    })

    if #StateStore.farmHistory > AppConfig.MaxHistoryLogs then
        StateStore.farmHistory[AppConfig.MaxHistoryLogs + 1] = nil
    end

    StateStore.totalEggsCollected += 1

    if StateStore.onHistoryUpdated then StateStore.onHistoryUpdated() end

    -- Webhook notification (fire-and-forget — never blocks the caller)
    if NS.Webhook and NS.Webhook.Config and NS.Webhook.Config.Enabled then
        task.spawn(function()
            pcall(function() NS.Webhook.NotifyEggCollected(eggName, isRare) end)
        end)
    end
end

-- ── Deduplication guard for rare-egg alerts ──────────────────────────
function StateStore.shouldAlert(eggName)
    local now = os.clock()
    local last = StateStore.recentAlerts[eggName]
    if last and (now - last) < AppConfig.AlertDedupeSeconds then return false end
    StateStore.recentAlerts[eggName] = now
    return true
end

-- ── Full reset (called on cleanup / re-injection) ────────────────────
function StateStore.reset()
    StateStore.mainESPActive      = false
    StateStore.autoFarmActive     = false
    StateStore.autoBestEggActive  = false
    StateStore.autoRebirthActive  = false
    StateStore.movementActive     = false
    StateStore.isMinimized        = false
    StateStore.listeningForKey    = false

    -- Nil out thread handles (task.cancel is caller's responsibility)
    StateStore.autoFarmThread     = nil
    StateStore.autoBestEggThread  = nil
    StateStore.autoRebirthThread  = nil
    StateStore.movementHumanoid   = nil

    -- Nil out callbacks
    StateStore.onHistoryUpdated   = nil
    StateStore.onTimeUpdated      = nil
    StateStore.screenGui          = nil

    -- Clear tables (including eggData to prevent stale ESP billboard refs)
    table.clear(StateStore.autoFarmEggs)
    table.clear(StateStore.farmHistory)
    table.clear(StateStore.recentAlerts)
    table.clear(StateStore.missingRebirthEggs)
    table.clear(StateStore.eggData)
    table.clear(StateStore.eggCooldowns)
    table.clear(StateStore.autoFarmProcessed)
end

NS.StateStore = StateStore
NS.State      = StateStore  -- alias required by loader health check

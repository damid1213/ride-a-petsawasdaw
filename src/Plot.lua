--[[
    Vanguard — Plot.lua
    Player base/plot detection and home deposit routines.
    Rewritten:
        • findHomePlot() caches result — no workspace walk every 0.5s
        • isOwner() refactored to a single helper, no duplicated logic
        • Cache invalidated on CharacterAdded
]]

local NS          = getgenv().EggsESP
local AppConfig   = NS.Config
local S           = NS.Services
local StateStore  = NS.StateStore
local Utils       = NS.Utils
local Movement    = NS.Movement
local Interaction = NS.Interaction

local Plot = {}

-- ── Cached plot reference ────────────────────────────────────────────
local _cachedPlot = nil

local function invalidatePlotCache()
    _cachedPlot = nil
end

-- Invalidate on respawn so the new character gets a fresh lookup
S.LocalPlayer.CharacterAdded:Connect(invalidatePlotCache)

-- ── Single-pass owner check ──────────────────────────────────────────
local function matchesPlayer(value)
    if not value then return false end
    local lp = S.LocalPlayer
    local v  = value.Value
    if value:IsA("StringValue") then
        return v == lp.Name or v == lp.DisplayName
    elseif value:IsA("ObjectValue") then
        return v == lp
    elseif value:IsA("IntValue") then
        return v == lp.UserId
    end
    return tostring(v) == lp.Name or tostring(v) == tostring(lp.UserId)
end

function Plot.isOwner(plot)
    if not plot then return false end
    local lp = S.LocalPlayer

    -- 1. Data sub-folder
    local dataFolder = plot:FindFirstChild("Data")
    if dataFolder then
        for _, name in ipairs({"Owner","Player"}) do
            local val = dataFolder:FindFirstChild(name)
            if val and matchesPlayer(val) then return true end
        end
    end

    -- 2. Direct children
    for _, name in ipairs({"Owner","Player"}) do
        local val = plot:FindFirstChild(name)
        if val and matchesPlayer(val) then return true end
    end

    -- 3. Attributes
    local attrOwner = plot:GetAttribute("Owner") or plot:GetAttribute("Player")
    if attrOwner and (attrOwner == lp.Name or attrOwner == lp.DisplayName) then return true end
    local attrId = plot:GetAttribute("OwnerId") or plot:GetAttribute("UserId")
    if attrId and (attrId == lp.UserId or tostring(attrId) == tostring(lp.UserId)) then return true end

    -- 4. Plot name
    if plot.Name == lp.Name or plot.Name == tostring(lp.UserId) then return true end

    -- 5. Sign label
    local sign = plot:FindFirstChild("Sign", true) or plot:FindFirstChild("PlotSign", true)
    if sign then
        for _, obj in ipairs(sign:GetDescendants()) do
            if obj:IsA("TextLabel") and
               (obj.Text:find(lp.Name, 1, true) or obj.Text:find(lp.DisplayName, 1, true)) then
                return true
            end
        end
    end

    return false
end

-- ── Plot discovery ────────────────────────────────────────────────────
local PLOT_FOLDER_NAMES = {"Plots","PlayerPlots","Bases","Islands","Tycoons"}

function Plot.findHomePlot()
    -- Return cached result if still valid
    if _cachedPlot and _cachedPlot.Parent then
        return _cachedPlot
    end
    _cachedPlot = nil

    local ws = S.Workspace

    -- Check known folder names first
    for _, folderName in ipairs(PLOT_FOLDER_NAMES) do
        local folder = ws:FindFirstChild(folderName)
        if folder then
            for _, plot in ipairs(folder:GetChildren()) do
                if Plot.isOwner(plot) then
                    _cachedPlot = plot
                    return plot
                end
            end
        end
    end

    -- Fallback: scan top-level models with "Plot" or "Base" in name
    for _, child in ipairs(ws:GetChildren()) do
        if child:IsA("Model") and (child.Name:find("Plot") or child.Name:find("Base")) then
            if Plot.isOwner(child) then
                _cachedPlot = child
                return child
            end
        end
    end

    return nil
end

-- ── Teleport to plot and deposit ─────────────────────────────────────
function Plot.teleportAndDeposit()
    local plot = Plot.findHomePlot()
    if not plot then return false end

    Movement.stop()
    Utils.resetVelocity(Utils.getRootPart())

    -- Prefer labelled deposit points, fall back gracefully
    local depositPoint = plot:FindFirstChild("Deposit", true)
        or plot:FindFirstChild("EggDeposit", true)
        or plot:FindFirstChild("Clear", true)
        or plot:FindFirstChild("Spawn", true)
        or plot:FindFirstChild("Base", true)
        or plot:FindFirstChild("Center", true)
        or plot.PrimaryPart
        or plot:FindFirstChildWhichIsA("BasePart")
        or plot

    local arrived = Movement.moveTo(depositPoint)
    Utils.resetVelocity(Utils.getRootPart())

    if arrived then
        task.wait(0.25)
        Interaction.trigger(depositPoint, AppConfig.HomeDepositWait)
    end

    return arrived
end

NS.Plot = Plot

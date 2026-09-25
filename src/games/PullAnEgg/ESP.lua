--[[
    Vanguard - Pull An Egg
    ESP.lua - Dynamic 3D Billboards for Egg Spawn Tiers

    Fixes vs previous version:
    · Dead-part pruning in the update loop (no more orphaned entries)
    · setEnabled() also cleans up dead entries
    · destroy() disconnects the RenderStepped connection and removes all billboards
    · Billboard creation is idempotent (guards against duplicates)
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled    = true,
    Billboards = {},  -- { Part, DistLabel, Billboard }
    Connection = nil,
}

local Config = nil

-- ── Init ─────────────────────────────────────────────────────────────

function ESP.init(cfg)
    Config = cfg or {}
    if not Config.TIER_COLORS then
        Config.TIER_COLORS = {
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
        }
    end
    ESP.setupVisuals()
end

-- ── Billboard Factory ─────────────────────────────────────────────────

function ESP.createBillboard(part, tierName, color)
    if part:FindFirstChild("Vanguard_ESP") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name          = "Vanguard_ESP"
    billboard.Adornee       = part
    billboard.Size          = UDim2.new(0, 180, 0, 50)
    billboard.StudsOffset   = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop   = true
    billboard.ResetOnSpawn  = false

    local frame = Instance.new("Frame")
    frame.Size                    = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3        = Color3.fromRGB(15, 17, 24)
    frame.BackgroundTransparency  = 0.35
    frame.BorderSizePixel         = 0
    frame.Parent                  = billboard

    local corner  = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local bstroke = Instance.new("UIStroke")
    bstroke.Color     = color or Color3.fromRGB(255, 255, 255)
    bstroke.Thickness = 1.5
    bstroke.Parent    = frame

    local title = Instance.new("TextLabel")
    title.Size                 = UDim2.new(1, 0, 0.55, 0)
    title.BackgroundTransparency = 1
    title.Text                 = "🥚 " .. string.upper(tierName)
    title.TextColor3           = color or Color3.fromRGB(255, 255, 255)
    title.Font                 = Enum.Font.GothamBold
    title.TextSize             = 13
    title.Parent               = frame

    local distLabel = Instance.new("TextLabel")
    distLabel.Name                 = "DistLabel"
    distLabel.Position             = UDim2.new(0, 0, 0.55, 0)
    distLabel.Size                 = UDim2.new(1, 0, 0.45, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text                 = "... studs"
    distLabel.TextColor3           = Color3.fromRGB(200, 205, 220)
    distLabel.Font                 = Enum.Font.Gotham
    distLabel.TextSize             = 11
    distLabel.Parent               = frame

    billboard.Parent = part
    table.insert(ESP.Billboards, {
        Part      = part,
        DistLabel = distLabel,
        Billboard = billboard,
    })
end

-- ── Setup: scan SpawnParts and attach billboards ──────────────────────

function ESP.setupVisuals()
    local map        = workspace:FindFirstChild("Map")
    local spawnParts = map and map:FindFirstChild("SpawnParts")
    if not spawnParts then return end

    for _, tierFolder in ipairs(spawnParts:GetChildren()) do
        local tierName = tierFolder.Name
        local color    = (Config.TIER_COLORS and Config.TIER_COLORS[tierName])
                         or Color3.fromRGB(255, 255, 255)
        for _, part in ipairs(tierFolder:GetChildren()) do
            if part:IsA("BasePart") then
                ESP.createBillboard(part, tierName, color)
            end
        end
    end

    if ESP.Connection then return end  -- already running

    ESP.Connection = RunService.RenderStepped:Connect(function()
        if not ESP.Enabled then return end

        local char    = LocalPlayer.Character
        local root    = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local rootPos = root.Position
        local live    = {}

        for _, item in ipairs(ESP.Billboards) do
            -- Prune entries whose part or billboard has been destroyed
            if item.Part and item.Part.Parent and item.Billboard and item.Billboard.Parent then
                local dist = math.floor((item.Part.Position - rootPos).Magnitude)
                if item.DistLabel then
                    item.DistLabel.Text = dist .. " studs"
                end
                live[#live + 1] = item
            else
                -- Clean up the billboard if it somehow survived its parent
                if item.Billboard then
                    pcall(function() item.Billboard:Destroy() end)
                end
            end
        end

        ESP.Billboards = live
    end)
end

-- ── Enable / Disable ─────────────────────────────────────────────────

function ESP.setEnabled(state)
    ESP.Enabled = state
    local live = {}
    for _, item in ipairs(ESP.Billboards) do
        if item.Billboard and item.Billboard.Parent then
            item.Billboard.Enabled = state
            live[#live + 1] = item
        end
    end
    ESP.Billboards = live
end

-- ── Cleanup ───────────────────────────────────────────────────────────

function ESP.destroy()
    if ESP.Connection then
        ESP.Connection:Disconnect()
        ESP.Connection = nil
    end
    for _, item in ipairs(ESP.Billboards) do
        if item.Billboard then
            pcall(function() item.Billboard:Destroy() end)
        end
    end
    ESP.Billboards = {}
    ESP.Enabled    = true  -- reset for potential re-init
end

return ESP

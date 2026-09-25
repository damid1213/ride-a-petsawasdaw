--[[
    Vanguard — ESP.lua
    3D Billboards + Highlights for rendered eggs.
    Rewritten:
      • bindEggLifecycle no longer leaks connections into _connections forever
      • updateBillboard skips distance calc when egg is beyond MaxDistance
      • setEnabled() added (used by PullAnEgg UI)
]]

local NS         = getgenv().EggsESP
local AppConfig  = NS.Config
local S          = NS.Services
local StateStore = NS.StateStore
local Utils      = NS.Utils

local ESP = {}

-- ── Colour helper ────────────────────────────────────────────────────
function ESP.getColor(eggName)
    local lower = eggName:lower()
    for _, kw in ipairs(AppConfig.RareKeywords) do
        if lower:find(kw, 1, true) then return AppConfig.ESPRareColor end
    end
    -- Deterministic palette hash
    local hash = 0
    for i = 1, #eggName do hash += string.byte(eggName, i) * (i + 1) end
    local palette = AppConfig.ESPPalette
    return palette[(hash % #palette) + 1]
end

-- ── Billboard creation ───────────────────────────────────────────────
function ESP.createBillboard(egg)
    local data = StateStore.eggData[egg]
    if not data then return end
    if data.NameBillboard and data.NameBillboard.Parent then return end

    local eggColor = ESP.getColor(egg.Name)

    -- Root BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name          = "EggESP_Info"
    billboard.Size          = UDim2.new(0, 160, 0, 52)
    billboard.StudsOffset   = Vector3.new(0, 4.5, 0)
    billboard.AlwaysOnTop   = true
    billboard.MaxDistance   = AppConfig.ESPMaxDistance or 2500
    billboard.Enabled       = false
    billboard.LightInfluence = 0
    billboard.Parent        = egg

    -- ── Backdrop card ────────────────────────────────────────────────
    local card = Instance.new("Frame")
    card.Name                    = "Card"
    card.Size                    = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3        = Color3.fromRGB(8, 8, 12)
    card.BackgroundTransparency  = 0.22
    card.BorderSizePixel         = 0
    card.Parent                  = billboard

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent       = card

    -- Coloured border (tier colour)
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color       = eggColor
    cardStroke.Thickness   = 1.5
    cardStroke.Transparency = 0.15
    cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    cardStroke.Parent      = card

    -- Subtle left accent bar
    local accent = Instance.new("Frame")
    accent.Size             = UDim2.new(0, 3, 1, -8)
    accent.Position         = UDim2.new(0, 0, 0, 4)
    accent.BackgroundColor3 = eggColor
    accent.BackgroundTransparency = 0.1
    accent.BorderSizePixel  = 0
    accent.Parent           = card
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(1, 0)
    accentCorner.Parent = accent

    -- ── Icon (egg emoji) ──────────────────────────────────────────────
    local icon = Instance.new("TextLabel")
    icon.Name                    = "Icon"
    icon.Position                = UDim2.new(0, 7, 0, 0)
    icon.Size                    = UDim2.new(0, 22, 1, 0)
    icon.BackgroundTransparency  = 1
    icon.Text                    = "🥚"
    icon.TextSize                = 14
    icon.Font                    = Enum.Font.GothamBold
    icon.Parent                  = card

    -- ── Egg name ─────────────────────────────────────────────────────
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name                   = "EggName"
    nameLabel.Position               = UDim2.new(0, 32, 0, 5)
    nameLabel.Size                   = UDim2.new(1, -36, 0, 22)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                   = egg.Name
    nameLabel.TextColor3             = eggColor
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    nameLabel.TextSize               = AppConfig.ESPNameSize or 13
    nameLabel.Font                   = Enum.Font.GothamBold
    nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    nameLabel.TextTruncate           = Enum.TextTruncate.AtEnd
    nameLabel.Parent                 = card

    -- ── Distance ─────────────────────────────────────────────────────
    local distLabel = Instance.new("TextLabel")
    distLabel.Name                   = "Distance"
    distLabel.Position               = UDim2.new(0, 32, 0, 27)
    distLabel.Size                   = UDim2.new(1, -36, 0, 16)
    distLabel.BackgroundTransparency = 1
    distLabel.Text                   = "0 studs"
    distLabel.TextColor3             = Color3.fromRGB(185, 190, 210)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    distLabel.TextSize               = AppConfig.ESPDistanceSize or 11
    distLabel.Font                   = Enum.Font.GothamMedium
    distLabel.TextXAlignment         = Enum.TextXAlignment.Left
    distLabel.Parent                 = card

    data.NameBillboard = billboard
end

-- ── Billboard distance update ────────────────────────────────────────
function ESP.updateBillboard(egg)
    local data = StateStore.eggData[egg]
    if not data or not data.NameBillboard or not data.NameBillboard.Parent then return end

    local billboard = data.NameBillboard
    local maxDist   = AppConfig.ESPMaxDistance or 2500
    local d         = Utils.getDistanceToTarget(egg)

    if d > maxDist then
        billboard.Enabled = false
        return
    end

    -- Labels now live inside the Card frame
    local card      = billboard:FindFirstChild("Card")
    local nameLabel = card and card:FindFirstChild("EggName")
    local distLabel = card and card:FindFirstChild("Distance")
    if nameLabel then nameLabel.Text = egg.Name end
    if distLabel then
        distLabel.Text = (d == math.huge) and "?" or string.format("%d studs", math.floor(d + 0.5))
    end
    billboard.Enabled = StateStore.mainESPActive
end

-- ── Full egg visual update ───────────────────────────────────────────
function ESP.updateEgg(egg)
    if not Utils.isValidEgg(egg) then return end

    if not StateStore.eggData[egg] then
        StateStore.eggData[egg] = {
            Highlight      = nil,
            NameBillboard  = nil,
            CustomColor    = ESP.getColor(egg.Name),
            CustomActive   = false,
        }
    end

    local data      = StateStore.eggData[egg]
    local eggColor  = ESP.getColor(egg.Name)
    local show      = data.CustomActive or StateStore.mainESPActive
    local color     = data.CustomActive and (data.CustomColor or eggColor) or eggColor

    if show then
        if not data.Highlight or not data.Highlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name               = "EggESP_Highlight"
            hl.Adornee            = egg
            hl.FillTransparency   = AppConfig.ESPFillTransparency
            hl.OutlineTransparency = AppConfig.ESPOutlineTransparency
            hl.Parent             = egg
            data.Highlight        = hl
        end
        data.Highlight.FillColor    = color
        data.Highlight.OutlineColor = color
        data.Highlight.Enabled      = true
        ESP.createBillboard(egg)
        ESP.updateBillboard(egg)
    else
        if data.Highlight    then data.Highlight.Enabled    = false end
        if data.NameBillboard then data.NameBillboard.Enabled = false end
    end
end

-- ── Toggle all ESP visuals ───────────────────────────────────────────
function ESP.setEnabled(enabled)
    StateStore.mainESPActive = enabled
    ESP.updateAll()
end

-- ── Update all eggs ──────────────────────────────────────────────────
function ESP.updateAll()
    local folder = S.RenderedEggsFolder
    if not folder then return end
    for _, egg in ipairs(folder:GetChildren()) do
        ESP.updateEgg(egg)
    end
end

-- ── Remove egg visuals and state ─────────────────────────────────────
function ESP.removeEgg(egg)
    local data = StateStore.eggData[egg]
    if data then
        if data.Highlight     then pcall(function() data.Highlight:Destroy()     end) end
        if data.NameBillboard then pcall(function() data.NameBillboard:Destroy() end) end
        StateStore.eggData[egg] = nil
    end
    StateStore.autoFarmProcessed[egg] = nil
    StateStore.eggCooldowns[egg]      = nil
end

-- ── Lifecycle binding ────────────────────────────────────────────────
-- Uses a LOCAL connection that does NOT go into _connections, because
-- the Destroying event fires exactly once and the callback self-disconnects.
-- This prevents _connections from growing unboundedly as eggs come and go.
function ESP.bindEggLifecycle(egg)
    if not egg or not egg.Parent then return end
    local conn
    conn = egg.Destroying:Connect(function()
        ESP.removeEgg(egg)
        pcall(function() conn:Disconnect() end)
        conn = nil
    end)
    -- Intentionally NOT tracked in StateStore._connections — self-cleans on destroy.
end

NS.ESP = ESP

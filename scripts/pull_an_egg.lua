--[[
    Vanguard — Pull An Egg
    pull_an_egg.lua — Single-file Automation Suite

    Changes vs previous version:
    · BodyVelocity replaced with LinearVelocity (non-deprecated)
    · Duplicate colour-table (C / BG0…) merged into one canonical table
    · hookAutoRevive() replaced by Heartbeat loop that exits on Unload
    · Runtime.Running is set to false on Unload so all loops exit cleanly
    · dragging=true dragging=true typo fixed
    · ESP dead-part pruning added to the RenderStepped loop
    · AutoRevive, AutoBuyGear toggles added to UI
    · BuyGearId, BuyGearInterval, AutoRevive added to Config
    · Remotes folder cached with a validity check (re-fetches if destroyed)
    · Toggle hover closure reads live `state` (no stale-colour flash)
    · Universal.setLowGraphics no longer calls deprecated Set3dRenderingEnabled
    · Ctrl shortcut connection tracked and disconnected on Unload
    · Unload is complete: stops all flags, floats, noclip, ESP, GUI, connections
]]

-- ── 0. Cleanup previous instance ─────────────────────────────────────
if getgenv().Vanguard_PullAnEgg
and typeof(getgenv().Vanguard_PullAnEgg.Unload) == "function" then
    pcall(function() getgenv().Vanguard_PullAnEgg.Unload() end)
end

-- ── Services ─────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")
local LocalPlayer       = Players.LocalPlayer

-- ── Runtime tracker ──────────────────────────────────────────────────
local Runtime = {
    Running     = true,
    Connections = {},
    Instances   = {},
}
function Runtime.trackConn(conn)
    table.insert(Runtime.Connections, conn)
    return conn
end

-- ── 1. Configuration ─────────────────────────────────────────────────
local Config = {
    -- Automation
    AutoTrain        = false,
    TrainInterval    = 0.1,

    AutoSell         = false,
    SellInterval     = 2,

    AutoRebirth      = false,
    RebirthInterval  = 1,

    AutoBuyDumbell   = false,
    AutoUpgradeCarry = false,

    AutoRevive       = true,  -- Instantly click Yes on the revive prompt

    AutoBuyGear      = false,
    BuyGearId        = "6",
    BuyGearInterval  = 1,

    AutoPullEgg      = false,
    TargetEggTier    = "Celestial",
    FlyHeight        = 16,
    SafeHover        = true,

    EggESP           = true,

    -- Universal
    AntiAFK          = true,
    LowGraphics      = false,
    SpeedBoost       = false,
    WalkSpeed        = 100,
    JumpPower        = 80,

    TIERS = {
        "Celestial", "Transcendent", "Divine", "OG", "Brainrot God",
        "Secret", "Mythic", "Legendary", "Epic", "Rare", "Common",
    },
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
}

-- ── 2. Remotes ───────────────────────────────────────────────────────
local Remotes = {}
local _remotesFolder = nil

local function getRemotesFolder()
    if _remotesFolder and _remotesFolder.Parent then return _remotesFolder end
    local shared  = ReplicatedStorage:FindFirstChild("SharedModules")
    local network = shared and shared:FindFirstChild("Network")
    _remotesFolder = network and network:FindFirstChild("Remotes")
    return _remotesFolder
end

function Remotes.fire(name, ...)
    local folder = getRemotesFolder()
    if not folder then return false end
    local r = folder:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then r:FireServer(...) return true end
    return false
end

function Remotes.invoke(name, ...)
    local folder = getRemotesFolder()
    if not folder then return nil end
    local r = folder:FindFirstChild(name)
    if r and r:IsA("RemoteFunction") then return r:InvokeServer(...) end
    return nil
end

function Remotes.buyDumbell(nameOrIndex)
    local id = typeof(nameOrIndex) == "number"
        and ("Dumbell_" .. nameOrIndex)
        or  tostring(nameOrIndex)
    return Remotes.fire("Buy Dumbell", id)
end

-- ── 3. Farm & Movement ───────────────────────────────────────────────
local Farm = { Threads = {}, _conns = {} }

-- Float via LinearVelocity (BodyVelocity is deprecated)
local _lvAttach, _lvInst = nil, nil
function Farm.setFloat(enabled)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if enabled then
        if _lvAttach and _lvAttach.Parent == root then return end
        _lvAttach        = Instance.new("Attachment")
        _lvAttach.Name   = "Vanguard_FloatAttach"
        _lvAttach.Parent = root
        _lvInst                     = Instance.new("LinearVelocity")
        _lvInst.Name                = "Vanguard_Float"
        _lvInst.Attachment0         = _lvAttach
        _lvInst.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        _lvInst.MaxForce            = 1e6
        _lvInst.VectorVelocity      = Vector3.new(0, 0, 0)
        _lvInst.Parent              = root
    else
        if _lvInst   then pcall(function() _lvInst:Destroy()   end) _lvInst   = nil end
        if _lvAttach then pcall(function() _lvAttach:Destroy() end) _lvAttach = nil end
        -- Clean up any leftovers
        if root then
            for _, n in ipairs({"Vanguard_Float","Vanguard_FloatAttach"}) do
                local old = root:FindFirstChild(n)
                if old then old:Destroy() end
            end
        end
    end
end

local _noclipConn = nil
function Farm.setNoclip(enabled)
    if _noclipConn then _noclipConn:Disconnect() _noclipConn = nil end
    if enabled then
        _noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end)
        Runtime.trackConn(_noclipConn)
    else
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
            end
        end
    end
end

function Farm.teleportTo(cf, h)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (root and cf) then return end
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.CFrame = cf + Vector3.new(0, h or 3, 0)
end

function Farm.getPartForTier(tierName)
    local map  = workspace:FindFirstChild("Map")
    local sp   = map and map:FindFirstChild("SpawnParts")
    if not sp then return nil end
    local folder = sp:FindFirstChild(tierName)
    if folder then
        for _, p in ipairs(folder:GetChildren()) do
            if p:IsA("BasePart") then return p end
        end
    end
    return nil
end

function Farm.teleportToTier(tierName)
    local part = Farm.getPartForTier(tierName)
    if not part then return false end
    Farm.teleportTo(part.CFrame, Config.FlyHeight or 16)
    if Config.SafeHover then Farm.setFloat(true) end
    return true
end

function Farm.teleportToSpawn()
    local map   = workspace:FindFirstChild("Map")
    local spawn = map and map:FindFirstChild("SpawnLocation")
    if spawn and spawn:IsA("BasePart") then Farm.teleportTo(spawn.CFrame) end
end

function Farm.teleportToShop(shopName)
    local map   = workspace:FindFirstChild("Map")
    local shops = map and map:FindFirstChild("ShopStands")
    if shops then
        local t = shops:FindFirstChild(shopName)
        if t then
            local r = t:FindFirstChildWhichIsA("BasePart", true)
            if r then Farm.teleportTo(r.CFrame) end
        end
    end
end

-- Auto-revive loop (exits when Runtime.Running is false)
do
    Runtime.trackConn(RunService.Heartbeat:Connect(function()
        if not Runtime.Running then return end
        if not Config.AutoRevive then return end
        local pgui   = LocalPlayer:FindFirstChild("PlayerGui")
        local revGui = pgui and pgui:FindFirstChild("Revive")
        if not (revGui and revGui.Enabled) then return end
        local main = revGui:FindFirstChild("Main")
        local yes  = main and main:FindFirstChild("Yes")
        if not yes then return end
        if firesignal then
            firesignal(yes.MouseButton1Click)
        else
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                local pos = yes.AbsolutePosition + yes.AbsoluteSize * 0.5
                vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true,  game, 0)
                vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
            end)
        end
    end))
end

-- Generic loop helper
local function loop(key, condFn, bodyFn, cleanupFn)
    if Farm.Threads[key] then return end
    Farm.Threads[key] = task.spawn(function()
        while Runtime.Running and condFn() do bodyFn() end
        if cleanupFn then cleanupFn() end
        Farm.Threads[key] = nil
    end)
end

function Farm.startAutoTrain()
    loop("AutoTrain", function() return Config.AutoTrain end, function()
        Remotes.fire("Activate Dumbell")
        task.wait(Config.TrainInterval or 0.1)
    end)
end
function Farm.stopAutoTrain()   Config.AutoTrain        = false end

function Farm.startAutoSell()
    loop("AutoSell", function() return Config.AutoSell end, function()
        Remotes.fire("Sell All Friends")
        task.wait(Config.SellInterval or 2)
    end)
end
function Farm.stopAutoSell()    Config.AutoSell         = false end

function Farm.startAutoRebirth()
    loop("AutoRebirth", function() return Config.AutoRebirth end, function()
        Remotes.fire("Rebirth")
        task.wait(Config.RebirthInterval or 1)
    end)
end
function Farm.stopAutoRebirth() Config.AutoRebirth      = false end

function Farm.startAutoBuyDumbell()
    loop("AutoBuyDumbell", function() return Config.AutoBuyDumbell end, function()
        for i = 1, 30 do
            if not (Runtime.Running and Config.AutoBuyDumbell) then break end
            Remotes.buyDumbell(i)
            task.wait(0.05)
        end
        task.wait(1)
    end)
end
function Farm.stopAutoBuyDumbell() Config.AutoBuyDumbell = false end

function Farm.startAutoUpgradeCarry()
    loop("AutoUpgradeCarry", function() return Config.AutoUpgradeCarry end, function()
        Remotes.fire("Upgrade Carry Limit")
        task.wait(1)
    end)
end
function Farm.stopAutoUpgradeCarry() Config.AutoUpgradeCarry = false end

function Farm.startAutoBuyGear()
    loop("AutoBuyGear", function() return Config.AutoBuyGear end, function()
        Remotes.fire("Buy Gear", tostring(Config.BuyGearId or "6"), "Buy")
        task.wait(Config.BuyGearInterval or 1)
    end)
end
function Farm.stopAutoBuyGear() Config.AutoBuyGear      = false end

function Farm.startAutoPullEgg()
    if Farm.Threads["AutoPullEgg"] then return end
    Farm.Threads["AutoPullEgg"] = task.spawn(function()
        if Config.SafeHover then Farm.setFloat(true) Farm.setNoclip(true) end
        while Runtime.Running and Config.AutoPullEgg do
            local tier = Config.TargetEggTier or "Celestial"
            local part = Farm.getPartForTier(tier)
            if part then
                local flyH = Config.FlyHeight or 16
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local target = part.Position + Vector3.new(0, flyH, 0)
                    if (root.Position - target).Magnitude > 8 then
                        Farm.teleportTo(part.CFrame, flyH)
                        task.wait(0.15)
                    end
                end
                Remotes.invoke("Strange: Claim Egg", tier)
                Remotes.fire("Activate Dumbell")
            end
            task.wait(0.1)
        end
        Farm.setFloat(false)
        Farm.setNoclip(false)
        Farm.Threads["AutoPullEgg"] = nil
    end)
end
function Farm.stopAutoPullEgg()
    Config.AutoPullEgg = false
    Farm.setFloat(false)
    Farm.setNoclip(false)
end

-- ── 4. ESP ───────────────────────────────────────────────────────────
local ESP = { Enabled = true, Billboards = {}, Connection = nil }

function ESP.createBillboard(part, tierName, color)
    if part:FindFirstChild("Vanguard_ESP") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name         = "Vanguard_ESP"
    billboard.Adornee      = part
    billboard.Size         = UDim2.new(0, 180, 0, 50)
    billboard.StudsOffset  = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop  = true
    billboard.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size                   = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3       = Color3.fromRGB(15, 17, 24)
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel        = 0
    frame.Parent                 = billboard

    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
    local fs = Instance.new("UIStroke") fs.Color = color or Color3.fromRGB(255,255,255) fs.Thickness = 1.5 fs.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size                 = UDim2.new(1, 0, 0.55, 0)
    title.BackgroundTransparency = 1
    title.Text                 = "🥚 " .. string.upper(tierName)
    title.TextColor3           = color or Color3.fromRGB(255, 255, 255)
    title.Font                 = Enum.Font.GothamBold
    title.TextSize             = 13
    title.Parent               = frame

    local distLbl = Instance.new("TextLabel")
    distLbl.Name                 = "DistLabel"
    distLbl.Position             = UDim2.new(0, 0, 0.55, 0)
    distLbl.Size                 = UDim2.new(1, 0, 0.45, 0)
    distLbl.BackgroundTransparency = 1
    distLbl.Text                 = "... studs"
    distLbl.TextColor3           = Color3.fromRGB(200, 205, 220)
    distLbl.Font                 = Enum.Font.Gotham
    distLbl.TextSize             = 11
    distLbl.Parent               = frame

    billboard.Parent = part
    table.insert(ESP.Billboards, { Part = part, DistLabel = distLbl, Billboard = billboard })
end

function ESP.init()
    local map  = workspace:FindFirstChild("Map")
    local sp   = map and map:FindFirstChild("SpawnParts")
    if not sp then return end
    for _, tf in ipairs(sp:GetChildren()) do
        local color = Config.TIER_COLORS[tf.Name] or Color3.fromRGB(255,255,255)
        for _, p in ipairs(tf:GetChildren()) do
            if p:IsA("BasePart") then ESP.createBillboard(p, tf.Name, color) end
        end
    end
    if ESP.Connection then return end
    ESP.Connection = RunService.RenderStepped:Connect(function()
        if not ESP.Enabled then return end
        local char    = LocalPlayer.Character
        local root    = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local rootPos = root.Position
        local live    = {}
        for _, item in ipairs(ESP.Billboards) do
            if item.Part and item.Part.Parent and item.Billboard and item.Billboard.Parent then
                if item.DistLabel then
                    item.DistLabel.Text = math.floor((item.Part.Position - rootPos).Magnitude) .. " studs"
                end
                live[#live+1] = item
            else
                pcall(function() if item.Billboard then item.Billboard:Destroy() end end)
            end
        end
        ESP.Billboards = live
    end)
    Runtime.trackConn(ESP.Connection)
end

function ESP.setEnabled(state)
    ESP.Enabled = state
    local live = {}
    for _, item in ipairs(ESP.Billboards) do
        if item.Billboard and item.Billboard.Parent then
            item.Billboard.Enabled = state
            live[#live+1] = item
        end
    end
    ESP.Billboards = live
end

function ESP.destroy()
    if ESP.Connection then ESP.Connection:Disconnect() ESP.Connection = nil end
    for _, item in ipairs(ESP.Billboards) do
        pcall(function() if item.Billboard then item.Billboard:Destroy() end end)
    end
    ESP.Billboards = {}
end

-- ── 5. Universal Utilities ───────────────────────────────────────────
local Universal = {}

do
    local TeleportService = game:GetService("TeleportService")
    local HttpService     = game:GetService("HttpService")
    local LOADER_URL      = "https://raw.githubusercontent.com/LostInSyntaxx/RideAPet/main/loader.lua"

    local _afkConn   = nil
    local _speedConn = nil
    local _origQual  = nil

    local function queueReload()
        pcall(function()
            local qot = (syn and syn.queue_on_teleport)
                or (typeof(queue_on_teleport) == "function" and queue_on_teleport)
                or (Fluxus and Fluxus.queue_on_teleport)
            if qot then
                qot(('task.wait(3) pcall(function() loadstring(game:HttpGet("%s"))() end)'):format(LOADER_URL))
            end
        end)
    end

    function Universal.setAntiAFK(enable)
        if _afkConn then pcall(function() _afkConn:Disconnect() end) _afkConn = nil end
        if enable then
            _afkConn = Runtime.trackConn(LocalPlayer.Idled:Connect(function()
                pcall(function()
                    local vu = game:GetService("VirtualUser")
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new())
                end)
            end))
        end
    end
    function Universal.stopAntiAFK() Universal.setAntiAFK(false) end

    local function applySpeed()
        pcall(function()
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.WalkSpeed = Config.WalkSpeed hum.JumpPower = Config.JumpPower end
        end)
    end

    function Universal.setSpeed(enable)
        if _speedConn then pcall(function() _speedConn:Disconnect() end) _speedConn = nil end
        if enable then
            applySpeed()
            _speedConn = Runtime.trackConn(LocalPlayer.CharacterAdded:Connect(function()
                task.wait(0.5)
                applySpeed()
            end))
        else
            pcall(function()
                local char = LocalPlayer.Character
                local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
                if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
            end)
        end
    end
    function Universal.stopSpeed() Universal.setSpeed(false) end

    function Universal.setLowGraphics(enable)
        pcall(function()
            local lighting = game:GetService("Lighting")
            if enable then
                lighting.GlobalShadows = false
                lighting.FogEnd        = 9e4
                lighting.FogStart      = 9e4
            else
                lighting.GlobalShadows = true
                lighting.FogEnd        = 100000
                lighting.FogStart      = 0
            end
        end)
        pcall(function()
            local gs = UserSettings():GetService("UserGameSettings")
            if enable then
                _origQual = gs.SavedQualityLevel
                gs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            elseif _origQual then
                gs.SavedQualityLevel = _origQual
                _origQual = nil
            end
        end)
    end

    function Universal.rejoin()
        queueReload()
        task.wait(0.5)
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end

    function Universal.serverHop()
        queueReload()
        local placeId = game.PlaceId
        local jobId   = game.JobId
        task.spawn(function()
            local ok, servers = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(placeId)))
            end)
            if ok and servers and servers.data then
                for _, srv in ipairs(servers.data) do
                    if srv.id ~= jobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                        if pcall(function() TeleportService:TeleportToPlaceInstance(placeId, srv.id, LocalPlayer) end) then return end
                    end
                end
            end
            pcall(function() TeleportService:Teleport(placeId, LocalPlayer) end)
        end)
    end
end

-- ── 6. GUI ───────────────────────────────────────────────────────────

local function getGuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    if pcall(function() return CoreGui:GetChildren() end) then return CoreGui end
    -- Wait for LocalPlayer / PlayerGui with a timeout
    local player = Players.LocalPlayer
    if not player then
        local ok2, lp = pcall(function()
            return Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        end)
        if ok2 then player = lp end
    end
    if player then
        local ok3, pgui = pcall(function() return player:WaitForChild("PlayerGui", 10) end)
        if ok3 and pgui then return pgui end
    end
    return CoreGui  -- last-resort, never nil
end

-- Single canonical colour palette
local C = {
    bg0       = Color3.fromRGB( 17,  17,  17),
    bg1       = Color3.fromRGB( 31,  31,  31),
    bg2       = Color3.fromRGB( 36,  36,  36),
    bg3       = Color3.fromRGB( 26,  26,  26),
    border0   = Color3.fromRGB( 50,  50,  50),
    border1   = Color3.fromRGB( 45,  45,  45),
    border2   = Color3.fromRGB( 38,  38,  38),
    gold      = Color3.fromRGB(255, 185,  50),
    goldDim   = Color3.fromRGB( 60,  42,   8),
    goldGlow  = Color3.fromRGB(255, 200,  80),
    green     = Color3.fromRGB( 52, 211, 153),
    greenDim  = Color3.fromRGB( 15,  60,  40),
    red       = Color3.fromRGB(239,  68,  68),
    blue      = Color3.fromRGB( 59, 130, 246),
    purple    = Color3.fromRGB(139,  92, 246),
    textPri   = Color3.fromRGB(230, 230, 230),
    textSec   = Color3.fromRGB(130, 130, 130),
    textMuted = Color3.fromRGB( 70,  70,  70),
    white     = Color3.fromRGB(255, 255, 255),
}

local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.14, Enum.EasingStyle.Quad), props):Play()
end
local function corner(p, r) local c=Instance.new("UICorner") c.CornerRadius=r or UDim.new(0,12) c.Parent=p return c end
local function mkstroke(p, col, th)
    local s=Instance.new("UIStroke") s.Color=col or C.border1 s.Thickness=th or 1
    s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border s.Parent=p return s end
local function mklist(p, px, dir)
    local l=Instance.new("UIListLayout") l.Padding=UDim.new(0,px or 8)
    l.SortOrder=Enum.SortOrder.LayoutOrder l.FillDirection=dir or Enum.FillDirection.Vertical l.Parent=p return l end
local function mkpad(p, x, y)
    local u=Instance.new("UIPadding") u.PaddingLeft=UDim.new(0,x or 12) u.PaddingRight=UDim.new(0,x or 12)
    u.PaddingTop=UDim.new(0,y or 10) u.PaddingBottom=UDim.new(0,y or 10) u.Parent=p return u end

local function buildUI()
    local parent = getGuiParent()
    if not parent then
        warn("[Vanguard] UI: could not resolve a GUI parent — aborting build.")
        return
    end
    for _, n in ipairs({"Vanguard_PullAnEgg","Vanguard_FloatingBtn"}) do
        local old = parent:FindFirstChild(n)
        if old then old:Destroy() end
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "Vanguard_PullAnEgg"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder   = 999

    local toggleGui = Instance.new("ScreenGui")
    toggleGui.Name           = "Vanguard_FloatingBtn"
    toggleGui.ResetOnSpawn   = false
    toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toggleGui.DisplayOrder   = 1000

    -- Floating Button
    local fabFrame = Instance.new("Frame")
    fabFrame.Size             = UDim2.new(0, 52, 0, 52)
    fabFrame.Position         = UDim2.new(0, 16, 0.5, -26)
    fabFrame.BackgroundColor3 = C.bg1
    fabFrame.BorderSizePixel  = 0
    fabFrame.Parent           = toggleGui
    corner(fabFrame, UDim.new(0, 14))
    local fabStroke = mkstroke(fabFrame, C.gold, 1.5)

    local fabBtn = Instance.new("TextButton")
    fabBtn.Size               = UDim2.new(1, 0, 1, 0)
    fabBtn.BackgroundTransparency = 1
    fabBtn.Text               = "🐾"
    fabBtn.TextSize           = 24
    fabBtn.Font               = Enum.Font.GothamBold
    fabBtn.Parent             = fabFrame

    local fabDrag, fabDragInput, fabDragStart, fabDragPos
    fabFrame.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            fabDrag=true fabDragStart=i.Position fabDragPos=fabFrame.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then fabDrag=false end end)
        end
    end)
    fabFrame.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then fabDragInput=i end
    end)

    -- Main Window Shell
    local shell = Instance.new("Frame")
    shell.Name             = "MainFrame"
    shell.Size             = UDim2.new(0, 660, 0, 460)
    shell.Position         = UDim2.new(0.5, -330, 0.5, -230)
    shell.BackgroundColor3 = C.bg0
    shell.BorderSizePixel  = 0
    shell.ClipsDescendants = true
    shell.Parent           = screenGui
    corner(shell, UDim.new(0, 16))
    mkstroke(shell, C.border0, 1)

    local stripe = Instance.new("Frame")
    stripe.Size=UDim2.new(1,0,0,2) stripe.BackgroundColor3=C.gold stripe.BorderSizePixel=0 stripe.ZIndex=3 stripe.Parent=shell

    local main = Instance.new("Frame")
    main.Size=UDim2.new(1,-2,1,-2) main.Position=UDim2.new(0,1,0,1)
    main.BackgroundColor3=C.bg1 main.BorderSizePixel=0 main.ClipsDescendants=true main.Parent=shell
    corner(main, UDim.new(0,15))

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name=  "TitleBar" titleBar.Size=UDim2.new(1,0,0,56)
    titleBar.BackgroundColor3=C.bg0 titleBar.BorderSizePixel=0 titleBar.Parent=main

    local logoBox = Instance.new("Frame")
    logoBox.Position=UDim2.new(0,14,0.5,-16) logoBox.Size=UDim2.new(0,32,0,32)
    logoBox.BackgroundColor3=C.goldDim logoBox.BorderSizePixel=0 logoBox.Parent=titleBar
    corner(logoBox, UDim.new(0,8))
    local logoTxt=Instance.new("TextLabel") logoTxt.Size=UDim2.new(1,0,1,0)
    logoTxt.BackgroundTransparency=1 logoTxt.Text="🐾" logoTxt.TextSize=16
    logoTxt.Font=Enum.Font.GothamBold logoTxt.Parent=logoBox

    local titleLbl=Instance.new("TextLabel")
    titleLbl.Position=UDim2.new(0,54,0,10) titleLbl.Size=UDim2.new(0,200,0,20)
    titleLbl.BackgroundTransparency=1 titleLbl.Text="Vanguard"
    titleLbl.TextColor3=C.goldGlow titleLbl.Font=Enum.Font.GothamBold titleLbl.TextSize=16
    titleLbl.TextXAlignment=Enum.TextXAlignment.Left titleLbl.Parent=titleBar

    local subLbl=Instance.new("TextLabel")
    subLbl.Position=UDim2.new(0,54,0,32) subLbl.Size=UDim2.new(0,260,0,14)
    subLbl.BackgroundTransparency=1 subLbl.Text="Pull An Egg  ·  Automation Suite"
    subLbl.TextColor3=C.textMuted subLbl.Font=Enum.Font.Gotham subLbl.TextSize=10
    subLbl.TextXAlignment=Enum.TextXAlignment.Left subLbl.Parent=titleBar

    local function winBtn(col, sym, xOff)
        local b=Instance.new("TextButton")
        b.Position=UDim2.new(1,xOff,0.5,-13) b.Size=UDim2.new(0,26,0,26)
        b.BackgroundColor3=col b.Text=sym b.TextColor3=C.white
        b.TextSize=11 b.Font=Enum.Font.GothamBold b.AutoButtonColor=false b.Parent=titleBar
        corner(b, UDim.new(0,6))
        b.MouseEnter:Connect(function() tw(b,{BackgroundTransparency=0.3}) end)
        b.MouseLeave:Connect(function() tw(b,{BackgroundTransparency=0})   end)
        return b
    end
    local closeBtn = winBtn(C.red,                      "✕", -38)
    local minBtn   = winBtn(Color3.fromRGB(55,55,55),   "─", -72)

    local tbRule=Instance.new("Frame") tbRule.Position=UDim2.new(0,0,1,-1) tbRule.Size=UDim2.new(1,0,0,1)
    tbRule.BackgroundColor3=C.border0 tbRule.BorderSizePixel=0 tbRule.Parent=titleBar

    -- Title bar drag
    local wDrag, wDragInput, wDragStart, wDragPos
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            wDrag=true wDragStart=i.Position wDragPos=shell.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then wDrag=false end end)
        end
    end)
    titleBar.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then wDragInput=i end
    end)

    Runtime.trackConn(UserInputService.InputChanged:Connect(function(i)
        if i==wDragInput and wDrag then
            local d=i.Position-wDragStart
            shell.Position=UDim2.new(wDragPos.X.Scale,wDragPos.X.Offset+d.X,wDragPos.Y.Scale,wDragPos.Y.Offset+d.Y)
        end
        if i==fabDragInput and fabDrag then
            local d=i.Position-fabDragStart
            fabFrame.Position=UDim2.new(fabDragPos.X.Scale,fabDragPos.X.Offset+d.X,fabDragPos.Y.Scale,fabDragPos.Y.Offset+d.Y)
        end
    end))

    local function toggleShell()
        shell.Visible=not shell.Visible
        tw(fabStroke,{Color=shell.Visible and C.goldGlow or C.gold})
        tw(fabFrame, {BackgroundColor3=shell.Visible and C.goldDim or C.bg1})
    end
    fabBtn.MouseButton1Click:Connect(toggleShell)
    closeBtn.MouseButton1Click:Connect(function() shell.Visible=false tw(fabStroke,{Color=C.gold}) tw(fabFrame,{BackgroundColor3=C.bg1}) end)
    minBtn.MouseButton1Click:Connect(function()   shell.Visible=false tw(fabStroke,{Color=C.gold}) tw(fabFrame,{BackgroundColor3=C.bg1}) end)

    Runtime.trackConn(UserInputService.InputBegan:Connect(function(i, gpe)
        if not gpe and (i.KeyCode==Enum.KeyCode.LeftControl or i.KeyCode==Enum.KeyCode.RightControl) then toggleShell() end
    end))

    -- Ribbon
    local ribbon=Instance.new("Frame")
    ribbon.Name="Ribbon" ribbon.Position=UDim2.new(0,0,0,56) ribbon.Size=UDim2.new(1,0,0,46)
    ribbon.BackgroundColor3=C.bg0 ribbon.BorderSizePixel=0 ribbon.Parent=main

    local ribbonRow=Instance.new("Frame")
    ribbonRow.Position=UDim2.new(0,14,0,4) ribbonRow.Size=UDim2.new(1,-14,1,-4)
    ribbonRow.BackgroundTransparency=1 ribbonRow.Parent=ribbon
    mklist(ribbonRow, 4, Enum.FillDirection.Horizontal)

    local rRule=Instance.new("Frame") rRule.Position=UDim2.new(0,0,1,-1) rRule.Size=UDim2.new(1,0,0,1)
    rRule.BackgroundColor3=C.border0 rRule.BorderSizePixel=0 rRule.Parent=ribbon

    local contentArea=Instance.new("Frame")
    contentArea.Position=UDim2.new(0,0,0,102) contentArea.Size=UDim2.new(1,0,1,-102)
    contentArea.BackgroundTransparency=1 contentArea.Parent=main

    -- Component builders
    local function outerCard(p, h)
        local o=Instance.new("Frame") o.Size=UDim2.new(1,0,0,h or 66)
        o.BackgroundColor3=C.bg2 o.BorderSizePixel=0 o.Parent=p
        corner(o,UDim.new(0,12)) mkstroke(o,C.border1,1) return o end

    local function innerCard(outer, mx, my)
        mx=mx or 5 my=my or 5
        local i=Instance.new("Frame") i.Size=UDim2.new(1,-mx*2,1,-my*2)
        i.Position=UDim2.new(0,mx,0,my) i.BackgroundColor3=C.bg3
        i.BorderSizePixel=0 i.Parent=outer
        corner(i,UDim.new(0,8)) mkstroke(i,C.border2,1) return i end

    local function createToggle(page, labelText, defaultState, onToggle)
        local o   = outerCard(page, 62)
        local inn = innerCard(o)

        local dot=Instance.new("Frame") dot.Position=UDim2.new(0,12,0.5,-4) dot.Size=UDim2.new(0,8,0,8)
        dot.BackgroundColor3=defaultState and C.green or C.textMuted dot.BorderSizePixel=0 dot.Parent=inn
        corner(dot,UDim.new(1,0))

        local lbl=Instance.new("TextLabel") lbl.Position=UDim2.new(0,28,0,0) lbl.Size=UDim2.new(1,-96,1,0)
        lbl.BackgroundTransparency=1 lbl.Text=labelText lbl.TextColor3=C.textPri
        lbl.Font=Enum.Font.GothamMedium lbl.TextSize=13
        lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.TextTruncate=Enum.TextTruncate.AtEnd lbl.Parent=inn

        local track=Instance.new("Frame") track.Position=UDim2.new(1,-60,0.5,-12) track.Size=UDim2.new(0,48,0,24)
        track.BackgroundColor3=defaultState and C.greenDim or C.bg0 track.BorderSizePixel=0 track.Parent=inn
        corner(track,UDim.new(1,0))
        local trackS=mkstroke(track, defaultState and C.green or C.border1, 1)

        local knob=Instance.new("Frame") knob.Size=UDim2.new(0,16,0,16)
        knob.Position=defaultState and UDim2.new(1,-20,0.5,-8) or UDim2.new(0,4,0.5,-8)
        knob.BackgroundColor3=defaultState and C.green or C.textMuted knob.BorderSizePixel=0 knob.Parent=track
        corner(knob,UDim.new(1,0))

        local hit=Instance.new("TextButton") hit.Size=UDim2.new(1,0,1,0)
        hit.BackgroundTransparency=1 hit.Text="" hit.Parent=inn

        local state=defaultState
        hit.MouseButton1Click:Connect(function()
            state=not state
            tw(knob, {Position=state and UDim2.new(1,-20,0.5,-8) or UDim2.new(0,4,0.5,-8),
                      BackgroundColor3=state and C.green or C.textMuted})
            tw(track, {BackgroundColor3=state and C.greenDim or C.bg0})
            tw(trackS,{Color=state and C.green or C.border1})
            tw(dot,   {BackgroundColor3=state and C.green or C.textMuted})
            if onToggle then onToggle(state) end
        end)
        -- Hover reads live `state` — no stale colour flash
        hit.MouseEnter:Connect(function() tw(o,{BackgroundColor3=Color3.fromRGB(42,42,42)}) end)
        hit.MouseLeave:Connect(function() tw(o,{BackgroundColor3=C.bg2}) end)
        return o
    end

    local function createButton(page, labelText, accentCol, onClick)
        local o=outerCard(page,52)
        local inn=Instance.new("TextButton") inn.Size=UDim2.new(1,-10,1,-10) inn.Position=UDim2.new(0,5,0,5)
        inn.BackgroundColor3=C.bg3 inn.Text="" inn.AutoButtonColor=false inn.BorderSizePixel=0 inn.Parent=o
        corner(inn,UDim.new(0,8)) mkstroke(inn,C.border2,1)

        local bar=Instance.new("Frame") bar.Size=UDim2.new(0,3,0.55,0) bar.Position=UDim2.new(0,10,0.225,0)
        bar.BackgroundColor3=accentCol or C.gold bar.BorderSizePixel=0 bar.Parent=inn corner(bar,UDim.new(1,0))

        local lbl=Instance.new("TextLabel") lbl.Position=UDim2.new(0,22,0,0) lbl.Size=UDim2.new(1,-40,1,0)
        lbl.BackgroundTransparency=1 lbl.Text=labelText lbl.TextColor3=C.textPri
        lbl.Font=Enum.Font.GothamMedium lbl.TextSize=13
        lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.TextTruncate=Enum.TextTruncate.AtEnd lbl.Parent=inn

        local arr=Instance.new("TextLabel") arr.Position=UDim2.new(1,-26,0,0) arr.Size=UDim2.new(0,18,1,0)
        arr.BackgroundTransparency=1 arr.Text="›" arr.TextColor3=C.textMuted
        arr.Font=Enum.Font.GothamBold arr.TextSize=18 arr.Parent=inn

        inn.MouseEnter:Connect(function()
            tw(inn,{BackgroundColor3=Color3.fromRGB(38,38,38)})
            tw(lbl,{TextColor3=accentCol or C.gold}) tw(arr,{TextColor3=accentCol or C.gold})
        end)
        inn.MouseLeave:Connect(function()
            tw(inn,{BackgroundColor3=C.bg3}) tw(lbl,{TextColor3=C.textPri}) tw(arr,{TextColor3=C.textMuted})
        end)
        inn.MouseButton1Click:Connect(function() if onClick then onClick() end end)
        return o
    end

    local function sectionLabel(page, text)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,26) row.BackgroundTransparency=1 row.Parent=page
        local line=Instance.new("Frame") line.Position=UDim2.new(0,0,0.5,0) line.Size=UDim2.new(1,0,0,1)
        line.BackgroundColor3=C.border1 line.BorderSizePixel=0 line.Parent=row
        local bg=Instance.new("Frame") bg.BackgroundColor3=C.bg1 bg.BorderSizePixel=0
        bg.Position=UDim2.new(0,0,0,4) bg.Size=UDim2.new(0,#text*7+20,0,18) bg.Parent=row
        local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1
        lbl.Text="  "..text lbl.TextColor3=C.textSec lbl.Font=Enum.Font.GothamBold lbl.TextSize=9
        lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=bg return row
    end

    -- Tab system
    local tabDefs={}

    local function createTab(name, icon, col)
        local tabCol=col or C.gold
        local isFirst=#tabDefs==0

        local btn=Instance.new("TextButton") btn.Size=UDim2.new(0,0,1,-8) btn.Position=UDim2.new(0,0,0,4)
        btn.AutomaticSize=Enum.AutomaticSize.X btn.BackgroundColor3=tabCol
        btn.BackgroundTransparency=isFirst and 0.88 or 1
        btn.Text="" btn.AutoButtonColor=false btn.Parent=ribbonRow
        corner(btn,UDim.new(0,8))
        local bp=Instance.new("UIPadding") bp.PaddingLeft=UDim.new(0,12) bp.PaddingRight=UDim.new(0,12)
        bp.PaddingTop=UDim.new(0,4) bp.PaddingBottom=UDim.new(0,4) bp.Parent=btn
        local brow=Instance.new("Frame") brow.Size=UDim2.new(1,0,1,0) brow.BackgroundTransparency=1 brow.Parent=btn
        mklist(brow,5,Enum.FillDirection.Horizontal)
        local ic=Instance.new("TextLabel") ic.Size=UDim2.new(0,16,1,0) ic.BackgroundTransparency=1
        ic.Text=icon ic.TextSize=13 ic.Font=Enum.Font.GothamBold
        ic.TextColor3=isFirst and tabCol or C.textSec ic.Parent=brow
        local nm=Instance.new("TextLabel") nm.Size=UDim2.new(0,0,1,0) nm.AutomaticSize=Enum.AutomaticSize.X
        nm.BackgroundTransparency=1 nm.Text=name nm.Font=Enum.Font.GothamBold nm.TextSize=12
        nm.TextColor3=isFirst and tabCol or C.textSec nm.Parent=brow
        local ind=Instance.new("Frame") ind.Size=UDim2.new(isFirst and 1 or 0,0,0,2)
        ind.Position=UDim2.new(0,0,1,-2) ind.BackgroundColor3=tabCol ind.BorderSizePixel=0 ind.Parent=btn
        corner(ind,UDim.new(1,0))

        local page=Instance.new("ScrollingFrame")
        page.Size=UDim2.new(1,0,1,0) page.BackgroundTransparency=1 page.BorderSizePixel=0
        page.ScrollBarThickness=3 page.ScrollBarImageColor3=C.border1
        page.CanvasSize=UDim2.new(0,0,0,0) page.AutomaticCanvasSize=Enum.AutomaticSize.Y
        page.Visible=isFirst page.Parent=contentArea
        mkpad(page,14,12) mklist(page,8)

        tabDefs[#tabDefs+1]={name=name,btn=btn,ic=ic,nm=nm,ind=ind,page=page,col=tabCol}
        return page
    end

    local function selectTab(targetName)
        for _, t in ipairs(tabDefs) do
            local a=(t.name==targetName)
            t.page.Visible=a
            tw(t.btn, {BackgroundTransparency=a and 0.88 or 1})
            tw(t.ic,  {TextColor3=a and t.col or C.textSec})
            tw(t.nm,  {TextColor3=a and t.col or C.textSec})
            tw(t.ind, {Size=UDim2.new(a and 1 or 0,0,0,2)})
        end
    end

    -- ── Tab 1: Auto Farm ──────────────────────────────────────────────
    local farmPage = createTab("Auto Farm", "🌾", C.green)
    sectionLabel(farmPage, "CORE AUTOMATION")
    createToggle(farmPage, "Auto Train  —  Activate Dumbell",    Config.AutoTrain,    function(s) Config.AutoTrain=s;    if s then Farm.startAutoTrain()    else Farm.stopAutoTrain()    end end)
    createToggle(farmPage, "Auto Sell  —  Sell All Friends",     Config.AutoSell,     function(s) Config.AutoSell=s;     if s then Farm.startAutoSell()     else Farm.stopAutoSell()     end end)
    createToggle(farmPage, "Auto Rebirth",                       Config.AutoRebirth,  function(s) Config.AutoRebirth=s;  if s then Farm.startAutoRebirth()  else Farm.stopAutoRebirth()  end end)
    sectionLabel(farmPage, "UPGRADES")
    createToggle(farmPage, "Auto Buy Dumbbells",                 Config.AutoBuyDumbell,  function(s) Config.AutoBuyDumbell=s;  if s then Farm.startAutoBuyDumbell()  else Farm.stopAutoBuyDumbell()  end end)
    createToggle(farmPage, "Auto Upgrade Carry Limit",           Config.AutoUpgradeCarry,function(s) Config.AutoUpgradeCarry=s; if s then Farm.startAutoUpgradeCarry() else Farm.stopAutoUpgradeCarry() end end)
    createToggle(farmPage, "Auto Buy Gear",                      Config.AutoBuyGear,  function(s) Config.AutoBuyGear=s;  if s then Farm.startAutoBuyGear()  else Farm.stopAutoBuyGear()  end end)
    sectionLabel(farmPage, "EGG PULLING")
    createToggle(farmPage, "Auto Pull Egg  —  Target Tier",      Config.AutoPullEgg,  function(s) Config.AutoPullEgg=s;  if s then Farm.startAutoPullEgg()  else Farm.stopAutoPullEgg()  end end)
    createToggle(farmPage, "Safe Fly / Hover  —  Dodge Boss",    Config.SafeHover,    function(s) Config.SafeHover=s;    if not s then Farm.setFloat(false) Farm.setNoclip(false) end end)
    sectionLabel(farmPage, "SAFETY")
    createToggle(farmPage, "Auto Revive (Instant)",              Config.AutoRevive,   function(s) Config.AutoRevive=s end)

    -- ── Tab 2: Eggs & ESP ─────────────────────────────────────────────
    local eggPage = createTab("Eggs & ESP", "🥚", C.purple)
    sectionLabel(eggPage, "VISUAL")
    createToggle(eggPage, "Egg 3D Billboard ESP", Config.EggESP, function(s) Config.EggESP=s; ESP.setEnabled(s) end)
    sectionLabel(eggPage, "TELEPORT TO TIER")
    for _, tier in ipairs(Config.TIERS) do
        local col = Config.TIER_COLORS[tier] or C.textSec
        createButton(eggPage, "📍  " .. tier .. " Egg", col, function()
            Config.TargetEggTier = tier
            Farm.teleportToTier(tier)
        end)
    end

    -- ── Tab 3: Misc ───────────────────────────────────────────────────
    local miscPage = createTab("Misc", "⚙️", C.blue)
    sectionLabel(miscPage, "REWARDS")
    createButton(miscPage, "Claim Daily & Group Rewards", C.green, function()
        Remotes.fire("Claim Daily Reward") Remotes.fire("Claim Group Reward") end)
    createButton(miscPage, "Sell All Friends (Manual)",   C.gold,  function() Remotes.fire("Sell All Friends") end)
    sectionLabel(miscPage, "QUICK TELEPORT")
    createButton(miscPage, "Teleport to Spawn",           C.textSec, function() Farm.teleportToSpawn() end)
    createButton(miscPage, "Teleport to Sell Shop",       C.textSec, function() Farm.teleportToShop("Sell") end)
    createButton(miscPage, "Teleport to Strength Shop",   C.textSec, function() Farm.teleportToShop("ShopSpeed") end)
    createButton(miscPage, "Teleport to Carry Shop",      C.textSec, function() Farm.teleportToShop("ShopCarry") end)
    sectionLabel(miscPage, "SYSTEM")
    createButton(miscPage, "Unload Script", C.red, function() Runtime.Unload() end)

    -- ── Tab 4: Universal ──────────────────────────────────────────────
    local uniPage = createTab("Universal", "🌐", C.gold)
    sectionLabel(uniPage, "PROTECTION")
    createToggle(uniPage, "Anti-AFK  —  Kick Prevention",     Config.AntiAFK,     function(s) Config.AntiAFK=s;     Universal.setAntiAFK(s)    end)
    sectionLabel(uniPage, "PERFORMANCE")
    createToggle(uniPage, "Low Graphics Mode  —  Better FPS", Config.LowGraphics, function(s) Config.LowGraphics=s; Universal.setLowGraphics(s) end)
    createToggle(uniPage, "Speed Boost  —  WalkSpeed " .. Config.WalkSpeed, Config.SpeedBoost, function(s) Config.SpeedBoost=s; Universal.setSpeed(s) end)
    sectionLabel(uniPage, "SERVER")
    createButton(uniPage, "Rejoin Same Server",   C.blue,   function() Universal.rejoin()    end)
    createButton(uniPage, "Server Hop",           C.purple, function() Universal.serverHop() end)

    -- Wire tab buttons and activate first
    for _, t in ipairs(tabDefs) do
        local name = t.name
        t.btn.MouseButton1Click:Connect(function() selectTab(name) end)
    end
    if #tabDefs > 0 then selectTab(tabDefs[1].name) end

    screenGui.Parent = parent
    toggleGui.Parent = parent
    table.insert(Runtime.Instances, screenGui)
    table.insert(Runtime.Instances, toggleGui)
end

-- ── 7. Startup ───────────────────────────────────────────────────────

Universal.setAntiAFK(Config.AntiAFK)

task.spawn(function()
    task.wait(2)
    if Runtime.Running then
        Remotes.fire("Claim Daily Reward")
        Remotes.fire("Claim Group Reward")
    end
end)

ESP.init()
buildUI()

-- ── 8. Unload ────────────────────────────────────────────────────────

function Runtime.Unload()
    Runtime.Running = false

    -- Stop all automation flags
    Config.AutoTrain        = false
    Config.AutoSell         = false
    Config.AutoRebirth      = false
    Config.AutoBuyDumbell   = false
    Config.AutoUpgradeCarry = false
    Config.AutoPullEgg      = false
    Config.AutoBuyGear      = false

    -- Universal cleanup
    Universal.stopAntiAFK()
    Universal.stopSpeed()
    if Config.LowGraphics then Universal.setLowGraphics(false) end

    -- Physics
    Farm.setFloat(false)
    Farm.setNoclip(false)

    -- All threads exit naturally via Runtime.Running guard
    Farm.Threads = {}

    -- Disconnect every tracked connection
    for _, conn in ipairs(Runtime.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Runtime.Connections = {}

    -- ESP
    ESP.destroy()

    -- GUI instances
    for _, inst in ipairs(Runtime.Instances) do
        pcall(function() inst:Destroy() end)
    end
    Runtime.Instances = {}

    -- Belt-and-suspenders GUI cleanup
    local parent = getGuiParent()
    for _, n in ipairs({"Vanguard_PullAnEgg","Vanguard_FloatingBtn"}) do
        local old = parent:FindFirstChild(n)
        if old then old:Destroy() end
    end

    getgenv().Vanguard_PullAnEgg = nil
    print("[Vanguard] ♻️  Pull An Egg unloaded successfully.")
end

getgenv().Vanguard_PullAnEgg = Runtime
print("[Vanguard] ✓ Pull An Egg Suite loaded. Press [LeftControl] or tap 🐾 to open.")

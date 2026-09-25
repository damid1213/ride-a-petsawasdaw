--[[
    Vanguard - Pull An Egg
    Farm.lua - Core Automation Loops (Train, Pull Egg, Sell, Rebirth, etc.)

    Fixes vs previous version:
    · BodyVelocity replaced with LinearVelocity (non-deprecated)
    · hookAutoRevive respects a Running flag so it exits cleanly on Unload
    · All loops guard on Farm.Running in addition to the config flag
    · setNoclip connection is stored for proper Unload cleanup
    · destroy() tears down every live connection and thread
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ── Module ───────────────────────────────────────────────────────────

local Farm = {
    Running = false,
    Threads = {},
    _conns  = {},   -- tracked RBXScriptConnections
}

local Config  = nil
local Remotes = nil

-- ── Init ─────────────────────────────────────────────────────────────

function Farm.init(cfg, rems)
    Config        = cfg
    Remotes       = rems
    Farm.Running  = true
    Farm._hookAutoRevive()
end

-- ── Auto-Revive (internal, started by init) ──────────────────────────

function Farm._hookAutoRevive()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not Farm.Running then
            conn:Disconnect()
            return
        end
        if not (Config and Config.AutoRevive) then return end

        local pgui     = LocalPlayer:FindFirstChild("PlayerGui")
        local revGui   = pgui and pgui:FindFirstChild("Revive")
        if not (revGui and revGui.Enabled) then return end

        local main = revGui:FindFirstChild("Main")
        local yes  = main and main:FindFirstChild("Yes")
        if not yes then return end

        -- Prefer firesignal (executor API) → fallback VirtualInputManager
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
    end)
    table.insert(Farm._conns, conn)
end

-- ── Float / Hover (LinearVelocity, replaces deprecated BodyVelocity) ─

local _lvAttachment = nil
local _lvInstance   = nil

function Farm.setFloat(enabled)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if enabled then
        -- Only create once; skip if still valid
        if _lvAttachment and _lvAttachment.Parent == root then return end

        _lvAttachment = Instance.new("Attachment")
        _lvAttachment.Name   = "Vanguard_FloatAttach"
        _lvAttachment.Parent = root

        _lvInstance = Instance.new("LinearVelocity")
        _lvInstance.Name           = "Vanguard_Float"
        _lvInstance.Attachment0    = _lvAttachment
        _lvInstance.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        _lvInstance.MaxForce       = 1e6
        _lvInstance.VectorVelocity = Vector3.new(0, 0, 0)
        _lvInstance.Parent         = root
    else
        if _lvInstance   then _lvInstance:Destroy()   _lvInstance   = nil end
        if _lvAttachment then _lvAttachment:Destroy() _lvAttachment = nil end
        -- Clean up any leftovers from a previous session
        if root then
            local old = root:FindFirstChild("Vanguard_Float")
            if old then old:Destroy() end
            local oldA = root:FindFirstChild("Vanguard_FloatAttach")
            if oldA then oldA:Destroy() end
        end
    end
end

-- ── No-Clip ───────────────────────────────────────────────────────────

local _noclipConn = nil

function Farm.setNoclip(enabled)
    if _noclipConn then
        _noclipConn:Disconnect()
        _noclipConn = nil
    end
    if enabled then
        _noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
        table.insert(Farm._conns, _noclipConn)
    else
        -- Restore collision on all parts except HumanoidRootPart
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- ── Teleport Helpers ─────────────────────────────────────────────────

function Farm.teleportTo(cf, heightOffset)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (root and cf) then return end
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.CFrame = cf + Vector3.new(0, heightOffset or 3, 0)
end

function Farm.getPartForTier(tierName)
    local map        = workspace:FindFirstChild("Map")
    local spawnParts = map and map:FindFirstChild("SpawnParts")
    if not spawnParts then return nil end
    local folder = spawnParts:FindFirstChild(tierName)
    if folder then
        for _, part in ipairs(folder:GetChildren()) do
            if part:IsA("BasePart") then return part end
        end
    end
    return nil
end

function Farm.teleportToTier(tierName)
    local part = Farm.getPartForTier(tierName)
    if not part then return false end
    local h = (Config and Config.FlyHeight) or 16
    Farm.teleportTo(part.CFrame, h)
    if Config and Config.SafeHover then
        Farm.setFloat(true)
    end
    return true
end

function Farm.teleportToSpawn()
    local map  = workspace:FindFirstChild("Map")
    local spawn = map and map:FindFirstChild("SpawnLocation")
    if spawn and spawn:IsA("BasePart") then
        Farm.teleportTo(spawn.CFrame)
        return true
    end
    return false
end

function Farm.teleportToShop(shopName)
    local map   = workspace:FindFirstChild("Map")
    local shops = map and map:FindFirstChild("ShopStands")
    if shops then
        local target = shops:FindFirstChild(shopName)
        if target then
            local root = target:FindFirstChildWhichIsA("BasePart", true)
            if root then
                Farm.teleportTo(root.CFrame)
                return true
            end
        end
    end
    return false
end

-- ── Generic loop spawner ─────────────────────────────────────────────

local function startLoop(key, condFn, bodyFn, afterFn)
    if Farm.Threads[key] then return end
    Farm.Threads[key] = task.spawn(function()
        while Farm.Running and condFn() do
            bodyFn()
        end
        if afterFn then afterFn() end
        Farm.Threads[key] = nil
    end)
end

-- ── 1. Auto Train ────────────────────────────────────────────────────

function Farm.startAutoTrain()
    startLoop("AutoTrain",
        function() return Config.AutoTrain end,
        function()
            Remotes.train()
            task.wait(Config.TrainInterval or 0.1)
        end
    )
end

function Farm.stopAutoTrain()
    Config.AutoTrain = false
end

-- ── 2. Auto Sell ─────────────────────────────────────────────────────

function Farm.startAutoSell()
    startLoop("AutoSell",
        function() return Config.AutoSell end,
        function()
            Remotes.sellAll()
            task.wait(Config.SellInterval or 2)
        end
    )
end

function Farm.stopAutoSell()
    Config.AutoSell = false
end

-- ── 3. Auto Rebirth ──────────────────────────────────────────────────

function Farm.startAutoRebirth()
    startLoop("AutoRebirth",
        function() return Config.AutoRebirth end,
        function()
            Remotes.rebirth()
            task.wait(Config.RebirthInterval or 1)
        end
    )
end

function Farm.stopAutoRebirth()
    Config.AutoRebirth = false
end

-- ── 4. Auto Buy Dumbbell ─────────────────────────────────────────────

function Farm.startAutoBuyDumbell()
    startLoop("AutoBuyDumbell",
        function() return Config.AutoBuyDumbell end,
        function()
            for i = 1, 30 do
                if not (Farm.Running and Config.AutoBuyDumbell) then break end
                Remotes.buyDumbell(i)
                task.wait(0.05)
            end
            task.wait(1)
        end
    )
end

function Farm.stopAutoBuyDumbell()
    Config.AutoBuyDumbell = false
end

-- ── 5. Auto Upgrade Carry ────────────────────────────────────────────

function Farm.startAutoUpgradeCarry()
    startLoop("AutoUpgradeCarry",
        function() return Config.AutoUpgradeCarry end,
        function()
            Remotes.upgradeCarry()
            task.wait(1)
        end
    )
end

function Farm.stopAutoUpgradeCarry()
    Config.AutoUpgradeCarry = false
end

-- ── 6. Auto Pull Egg (Boss-Safe Hover/Fly) ───────────────────────────

function Farm.startAutoPullEgg()
    if Farm.Threads["AutoPullEgg"] then return end
    Farm.Threads["AutoPullEgg"] = task.spawn(function()
        if Config.SafeHover then
            Farm.setFloat(true)
            Farm.setNoclip(true)
        end

        while Farm.Running and Config.AutoPullEgg do
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
                Remotes.claimEgg(tier)
                Remotes.train()
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

-- ── 7. Auto Buy Gear ─────────────────────────────────────────────────

function Farm.startAutoBuyGear()
    startLoop("AutoBuyGear",
        function() return Config.AutoBuyGear end,
        function()
            Remotes.buyGear(Config.BuyGearId or "6")
            task.wait(Config.BuyGearInterval or 1)
        end
    )
end

function Farm.stopAutoBuyGear()
    Config.AutoBuyGear = false
end

-- ── Cleanup ───────────────────────────────────────────────────────────

function Farm.destroy()
    Farm.Running = false

    -- Stop all automation flags
    Config.AutoTrain        = false
    Config.AutoSell         = false
    Config.AutoRebirth      = false
    Config.AutoBuyDumbell   = false
    Config.AutoUpgradeCarry = false
    Config.AutoPullEgg      = false
    Config.AutoBuyGear      = false

    -- Disable physics overrides
    Farm.setFloat(false)
    Farm.setNoclip(false)

    -- Disconnect tracked connections
    for _, conn in ipairs(Farm._conns) do
        pcall(function() conn:Disconnect() end)
    end
    Farm._conns = {}

    -- Threads will exit naturally via the Farm.Running guard
    Farm.Threads = {}
end

return Farm

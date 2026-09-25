--[[
    Vanguard - Pull An Egg
    Remotes.lua - Centralized Remote Dispatcher
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}
local _remotesFolder = nil

-- ── Folder Lookup (cached) ───────────────────────────────────────────

local function getRemotesFolder()
    if _remotesFolder and _remotesFolder.Parent then
        return _remotesFolder
    end
    local shared = ReplicatedStorage:FindFirstChild("SharedModules")
    local network = shared and shared:FindFirstChild("Network")
    _remotesFolder = network and network:FindFirstChild("Remotes")
    return _remotesFolder
end

-- ── Safe Remote Helpers ──────────────────────────────────────────────

function Remotes.fireEvent(name, ...)
    local folder = getRemotesFolder()
    if not folder then return false end
    local remote = folder:FindFirstChild(name)
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(...)
        return true
    end
    return false
end

function Remotes.invokeFunction(name, ...)
    local folder = getRemotesFolder()
    if not folder then return nil end
    local remote = folder:FindFirstChild(name)
    if remote and remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    end
    return nil
end

-- ── Game-Specific Actions ────────────────────────────────────────────

-- 1. Train strength using Dumbbell
function Remotes.train()
    return Remotes.fireEvent("Activate Dumbell")
end

-- 2. Sell all animals in inventory
function Remotes.sellAll()
    return Remotes.fireEvent("Sell All Friends")
end

-- 3. Rebirth
function Remotes.rebirth()
    return Remotes.fireEvent("Rebirth")
end

-- 4. Claim Egg (by tier name or nil for default)
function Remotes.claimEgg(eggNameOrId)
    if eggNameOrId then
        return Remotes.invokeFunction("Strange: Claim Egg", eggNameOrId)
    end
    return Remotes.invokeFunction("Strange: Claim Egg")
end

-- 5. Claim Daily Reward
function Remotes.claimDailyReward()
    return Remotes.fireEvent("Claim Daily Reward")
end

-- 6. Claim Group Reward
function Remotes.claimGroupReward()
    return Remotes.fireEvent("Claim Group Reward")
end

-- 7. Reset AFK timer
function Remotes.resetAFK()
    return Remotes.fireEvent("AFK Idle Reset Request")
end

-- 8. Upgrade Carry Limit
function Remotes.upgradeCarry()
    return Remotes.fireEvent("Upgrade Carry Limit")
end

-- 9. Buy Dumbbell by index or name
function Remotes.buyDumbell(nameOrIndex)
    local id = typeof(nameOrIndex) == "number"
        and ("Dumbell_" .. nameOrIndex)
        or  tostring(nameOrIndex)
    return Remotes.fireEvent("Buy Dumbell", id)
end

-- 10. Place Friend on Plot
function Remotes.placeFriend(uuid, x, z)
    return Remotes.fireEvent("Place Friend", uuid, x or 0, z or 0)
end

-- 11. Open Lucky Block
function Remotes.openLuckyBlock(uuid)
    return Remotes.fireEvent("Open Lucky Block", uuid)
end

-- 12. Buy Gear
function Remotes.buyGear(gearId)
    return Remotes.fireEvent("Buy Gear", tostring(gearId or "6"), "Buy")
end

return Remotes

--[[
    Vanguard — Utils.lua
    Math, string, vector and egg validation helpers.
    Rewritten: removed deprecated Velocity/RotVelocity, added eggsHolder cache.
]]

local NS         = getgenv().EggsESP
local AppConfig  = NS.Config
local S          = NS.Services

local Utils = {}

-- ── Character helpers ────────────────────────────────────────────────
function Utils.getCharacter()
    return S.LocalPlayer.Character
end

function Utils.getRootPart()
    local char = Utils.getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Utils.getHumanoid()
    local char = Utils.getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ── Velocity reset (current API only — no deprecated props) ──────────
function Utils.resetVelocity(root)
    if not root then return end
    pcall(function()
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ── Tween wrapper ────────────────────────────────────────────────────
function Utils.tween(object, properties, duration, style, direction)
    if not object or not object.Parent then return end
    local info = TweenInfo.new(
        duration  or AppConfig.AnimationTime,
        style     or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local tw = S.TweenService:Create(object, info, properties)
    tw:Play()
    return tw
end

-- ── CFrame / Position resolution ────────────────────────────────────
function Utils.getTargetCFrame(target)
    if not target or not target.Parent then return nil end
    if target:IsA("Model") then
        if target.PrimaryPart then return target.PrimaryPart.CFrame end
        local base = target:FindFirstChildWhichIsA("BasePart")
        return base and base.CFrame or target:GetPivot()
    elseif target:IsA("BasePart") then
        return target.CFrame
    end
    return nil
end

function Utils.getTargetPosition(target)
    local cf = Utils.getTargetCFrame(target)
    return cf and cf.Position or nil
end

function Utils.getDistanceToTarget(target)
    local root     = Utils.getRootPart()
    local pos      = Utils.getTargetPosition(target)
    if not root or not pos then return math.huge end
    return (root.Position - pos).Magnitude
end

-- ── Egg validation ───────────────────────────────────────────────────
function Utils.isValidEgg(egg)
    return egg ~= nil
        and egg.Parent == S.RenderedEggsFolder
        and (egg:IsA("Model") or egg:IsA("BasePart"))
end

function Utils.isRareEgg(eggName)
    local lower = eggName:lower()
    for _, kw in ipairs(AppConfig.RareKeywords) do
        if lower:find(kw, 1, true) then return true end
    end
    return false
end

-- ── EggsHolder lookup (cached after first successful find) ───────────
local _eggsHolderCache = nil
local function getEggsHolder()
    if _eggsHolderCache and _eggsHolderCache.Parent then
        return _eggsHolderCache
    end
    _eggsHolderCache = nil
    local playerGui = S.LocalPlayer:FindFirstChild("PlayerGui")
    local main      = playerGui and playerGui:FindFirstChild("Main")
    local index     = main and main:FindFirstChild("Index")
    local holders   = index and index:FindFirstChild("Holders")
    local holder    = holders and holders:FindFirstChild("EggsHolder")
    _eggsHolderCache = holder
    return holder
end

function Utils.getEggImage(eggName)
    local holder   = getEggsHolder()
    if not holder then return "" end
    local eggFrame = holder:FindFirstChild(eggName)
    if not eggFrame then return "" end
    local img = eggFrame:FindFirstChildWhichIsA("ImageLabel", true)
    return (img and img.Image) or ""
end

-- ── Known egg name check (uses cached holder) ────────────────────────
function Utils.isKnownEggName(name)
    if not name or type(name) ~= "string" or #name < 2 then return false end
    if name:lower():find("egg", 1, true) then return true end

    local holder = getEggsHolder()
    if holder and holder:FindFirstChild(name) then return true end

    local folder = S.RenderedEggsFolder
    if folder and folder:FindFirstChild(name) then return true end

    return false
end

NS.Utils = Utils

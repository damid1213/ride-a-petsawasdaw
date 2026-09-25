--[[
    Vanguard — Movement.lua
    Pathfinding, tweening and noclip movement engine.
    Rewritten:
      • maxTime uses Config.MovementTimeBuffer (default 5s) instead of hardcoded 2.5s
      • Cleaner separation between Teleport and AutoFarm modes
      • resetVelocity uses only current API (no deprecated props)
]]

local NS         = getgenv().Vanguard or getgenv().EggsESP
local AppConfig  = NS.Config
local S          = NS.Services
local StateStore = NS.StateStore
local Utils      = NS.Utils

local Movement = {}

-- ── Noclip ───────────────────────────────────────────────────────────
function Movement.setNoclip(enabled)
    if StateStore.noclipConnection then
        pcall(function() StateStore.noclipConnection:Disconnect() end)
        StateStore.noclipConnection = nil
    end

    local character = Utils.getCharacter()
    if not character then return end

    if enabled then
        StateStore.noclipConnection = S.RunService.Stepped:Connect(function()
            local char = Utils.getCharacter()
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart")
                and part.Name ~= "HumanoidRootPart"
                and not part:IsA("Accessory")
                and not part.Parent:IsA("Accessory") then
                part.CanCollide = true
            end
        end
    end
end

-- ── Stop all movement ────────────────────────────────────────────────
function Movement.stop()
    StateStore.movementActive = false
    if StateStore.movementHumanoid and StateStore.movementHumanoid.Parent then
        StateStore.movementHumanoid.AutoRotate = true
    end
    StateStore.movementHumanoid = nil
    Movement.setNoclip(false)
    Utils.resetVelocity(Utils.getRootPart())
end

-- ── Instant teleport ────────────────────────────────────────────────
function Movement.teleportTo(target)
    local root       = Utils.getRootPart()
    if not root then return false end
    local targetCF   = Utils.getTargetCFrame(target)
    if not targetCF then return false end
    Utils.resetVelocity(root)
    root.CFrame = targetCF * CFrame.new(0, AppConfig.TPHeight, 0)
    Utils.resetVelocity(root)
    return true
end

-- ── Smart movement (teleport or smooth depending on movementMode) ────
function Movement.moveTo(target)
    if StateStore.movementMode == "Teleport" then
        return Movement.teleportTo(target)
    end

    if StateStore.movementActive then return false end

    local root       = Utils.getRootPart()
    local humanoid   = Utils.getHumanoid()
    local targetCF   = Utils.getTargetCFrame(target)

    if not root or not humanoid or not targetCF or humanoid.Health <= 0 then
        return false
    end

    local destination  = targetCF.Position + Vector3.new(0, AppConfig.TPHeight, 0)
    local startDist    = (root.Position - destination).Magnitude

    -- Already close enough — snap and return
    if startDist <= 2.8 then
        Utils.resetVelocity(root)
        root.CFrame = targetCF * CFrame.new(0, AppConfig.TPHeight, 0)
        return true
    end

    -- Calculate timeout with a configurable buffer
    local buffer  = AppConfig.MovementTimeBuffer or 5.0
    local maxTime = math.max(4.0, (startDist / AppConfig.MovementSpeed) + buffer)

    StateStore.movementActive   = true
    StateStore.movementHumanoid = humanoid

    local oldAutoRotate  = humanoid.AutoRotate
    local success        = false
    local startTime      = os.clock()
    local lastCheckPos   = root.Position
    local lastCheckTime  = os.clock()

    Movement.setNoclip(true)
    humanoid.AutoRotate = false

    while StateStore.movementActive and (os.clock() - startTime <= maxTime) do
        if not target or not target.Parent or humanoid.Health <= 0 then break end
        if Utils.getRootPart() ~= root then break end

        local curCF = Utils.getTargetCFrame(target)
        if curCF then
            destination = curCF.Position + Vector3.new(0, AppConfig.TPHeight, 0)
        end

        local offset   = destination - root.Position
        local distance = offset.Magnitude

        if distance <= 2.8 then
            Utils.resetVelocity(root)
            root.CFrame = (curCF or targetCF) * CFrame.new(0, AppConfig.TPHeight, 0)
            success = true
            break
        end

        -- Anti-stuck: nudge upward if barely moved
        if os.clock() - lastCheckTime >= AppConfig.AntiStuckThreshold then
            if (root.Position - lastCheckPos).Magnitude < 1.2 then
                root.CFrame = root.CFrame * CFrame.new(0, 4, 0)
                Movement.setNoclip(true)
                Utils.resetVelocity(root)
            end
            lastCheckPos  = root.Position
            lastCheckTime = os.clock()
        end

        local dt   = S.RunService.Heartbeat:Wait()
        local step = math.min(distance, AppConfig.MovementSpeed * dt)
        Utils.resetVelocity(root)

        local newPos = root.Position + (offset.Unit * step)
        if (destination - newPos).Magnitude > 0.08 then
            root.CFrame = CFrame.lookAt(newPos, destination)
        else
            root.CFrame = (curCF or targetCF) * CFrame.new(0, AppConfig.TPHeight, 0)
            success = true
            break
        end
    end

    -- Cleanup
    StateStore.movementActive = false
    if humanoid and humanoid.Parent then humanoid.AutoRotate = oldAutoRotate end
    StateStore.movementHumanoid = nil
    Movement.setNoclip(false)
    Utils.resetVelocity(root)

    return success
end

NS.Movement = Movement

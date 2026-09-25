local NS = getgenv().EggsESP
local AppConfig = NS.Config
local S = NS.Services
local StateStore = NS.StateStore
local Utils = NS.Utils
local Movement = NS.Movement
local Interaction = NS.Interaction
local Plot = NS.Plot

local Rebirth = {}

function Rebirth.getRebirthRemote()
    local rs = S.ReplicatedStorage or game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    local gameRemotes = remotes and remotes:FindFirstChild("Game")
    local rebirthEvent = gameRemotes and gameRemotes:FindFirstChild("Rebirth")
    if rebirthEvent and rebirthEvent:IsA("RemoteEvent") then return rebirthEvent end
    local fallback = rs:FindFirstChild("Rebirth", true)
    if fallback and fallback:IsA("RemoteEvent") then return fallback end
    return nil
end

function Rebirth.fireRebirth()
    local remote = Rebirth.getRebirthRemote()
    if remote then
        local ok = pcall(function() remote:FireServer() end)
        return ok
    end
    return false
end

function Rebirth.findEggByName(eggName)
    local folder = S.RenderedEggsFolder
    if not folder then return nil end
    local query = eggName:lower():match("^%s*(.-)%s*$")
    local now = os.clock()
    -- Pass 1: prefer eggs not currently on cooldown
    for _, egg in ipairs(folder:GetChildren()) do
        local cd = StateStore.eggCooldowns[egg]
        local onCooldown = (cd and now <= cd)
        if not onCooldown and Utils.isValidEgg(egg) then
            local n = egg.Name:lower()
            if n == query or string.find(n, query, 1, true) or string.find(query, n, 1, true) then return egg end
        end
    end
    -- Pass 2: fallback — accept any matching egg even if on cooldown,
    -- so rebirth isn't blocked just because the egg was recently touched.
    for _, egg in ipairs(folder:GetChildren()) do
        if Utils.isValidEgg(egg) then
            local n = egg.Name:lower()
            if n == query or string.find(n, query, 1, true) or string.find(query, n, 1, true) then return egg end
        end
    end
    return nil
end

function Rebirth.scanMissingEggs()
    local missing = {}
    local seen = {}
    local playerGui = S.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return missing end

    local function checkRebirthContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetDescendants()) do
            if item:IsA("TextLabel") then
                local text = item.Text
                if string.find(text, "^%s*0%s*/%s*%d+") or string.find(text, "%s+0%s*/%s*%d+") then
                    local parent = item.Parent
                    local eggCandidate = nil
                    if parent then
                        if Utils.isKnownEggName(parent.Name) then
                            eggCandidate = parent.Name
                        else
                            for _, sib in ipairs(parent:GetChildren()) do
                                if sib:IsA("TextLabel") and sib ~= item then
                                    local st = sib.Text:match("^%s*(.-)%s*$")
                                    if st and #st > 0 and Utils.isKnownEggName(st) then
                                        eggCandidate = st
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if eggCandidate and not seen[eggCandidate:lower()] then
                        seen[eggCandidate:lower()] = true
                        table.insert(missing, eggCandidate)
                    end
                end
            end
        end
    end

    local main = playerGui:FindFirstChild("Main")
    if main then
        for _, child in ipairs(main:GetChildren()) do
            if string.find(child.Name:lower(), "rebirth", 1, true) then checkRebirthContainer(child) end
        end
        local frames = main:FindFirstChild("Frames")
        if frames then
            for _, child in ipairs(frames:GetChildren()) do
                if string.find(child.Name:lower(), "rebirth", 1, true) then checkRebirthContainer(child) end
            end
        end
    end
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and string.find(gui.Name:lower(), "rebirth", 1, true) then
            checkRebirthContainer(gui)
        end
    end

    if #missing == 0 and main then
        local rebirthFrame = main:FindFirstChild("Rebirth", true) or main:FindFirstChild("RebirthFrame", true)
        if rebirthFrame then
            for _, desc in ipairs(rebirthFrame:GetDescendants()) do
                if desc:IsA("Frame") or desc:IsA("ImageLabel") or desc:IsA("TextLabel") then
                    local n = desc.Name
                    if Utils.isKnownEggName(n) and not seen[n:lower()] then
                        local isDone = false
                        for _, child in ipairs(desc:GetDescendants()) do
                            if child:IsA("TextLabel") and string.find(child.Text, "^%s*[1-9]%d*%s*/") then
                                isDone = true; break
                            end
                            if child:IsA("ImageLabel") and (string.find(child.Name:lower(), "check", 1, true) or string.find(child.Name:lower(), "done", 1, true)) and child.Visible then
                                isDone = true; break
                            end
                        end
                        if not isDone then
                            seen[n:lower()] = true
                            table.insert(missing, n)
                        end
                    end
                end
            end
        end
    end
    StateStore.missingRebirthEggs = missing
    return missing
end

function Rebirth.stopAutoRebirth()
    StateStore.autoRebirthActive = false
    Movement.stop()
    if StateStore.autoRebirthThread then
        pcall(function() task.cancel(StateStore.autoRebirthThread) end)
        StateStore.autoRebirthThread = nil
    end
end

function Rebirth.startAutoRebirth(statusUpdater, stopButtonUpdater)
    Rebirth.stopAutoRebirth()
    StateStore.autoRebirthActive = true
    if stopButtonUpdater then stopButtonUpdater(true) end

    StateStore.autoRebirthThread = task.spawn(function()
        while StateStore.autoRebirthActive do
            if statusUpdater then statusUpdater("Checking Rebirth...", AppConfig.AccentGold) end

            -- Scan FIRST, then decide whether to fire
            local missing = Rebirth.scanMissingEggs()

            if #missing == 0 then
                -- Requirements met — fire rebirth
                if statusUpdater then statusUpdater("Rebirth Fired!", AppConfig.AccentGreen) end
                Rebirth.fireRebirth()
                task.wait(0.6)
                Rebirth.fireRebirth()
                task.wait(1.5)
            else
                local missingSummary = table.concat(missing, ", ")
                if statusUpdater then statusUpdater("Needs: [" .. missingSummary .. "]", AppConfig.AccentBlue) end
                for _, eggName in ipairs(missing) do
                    if not StateStore.autoRebirthActive then break end
                    local targetEgg = Rebirth.findEggByName(eggName)
                    if targetEgg then
                        if statusUpdater then statusUpdater("Hunting: " .. targetEgg.Name, AppConfig.AccentGreen) end
                        local arrived = Movement.moveTo(targetEgg)
                        if arrived and StateStore.autoRebirthActive and Utils.isValidEgg(targetEgg) then
                            if statusUpdater then statusUpdater("Collecting...", AppConfig.AccentGold) end
                            Interaction.trigger(targetEgg, AppConfig.AutoFarmHoldTime)
                            StateStore.eggCooldowns[targetEgg] = os.clock() + AppConfig.EggCooldownSeconds
                            task.wait(0.3)
                            if statusUpdater then statusUpdater("Depositing...", AppConfig.AccentBlue) end
                            Movement.stop()
                            local ok = Plot.teleportAndDeposit()
                            if ok then
                                StateStore.addHistoryRecord(targetEgg.Name)
                                if statusUpdater then statusUpdater("Deposited!", AppConfig.AccentGreen) end
                                task.wait(0.5)
                                Rebirth.fireRebirth()
                                task.wait(0.8)
                            end
                        end
                    else
                        if statusUpdater then statusUpdater("Waiting for " .. eggName .. "...", AppConfig.TextSecondary) end
                        task.wait(1.0)
                    end
                end
            end
            task.wait(0.5)
        end
        StateStore.autoRebirthThread = nil
        StateStore.autoRebirthActive = false
    end)
end

NS.Rebirth = Rebirth

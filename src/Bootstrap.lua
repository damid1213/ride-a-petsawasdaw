-- src/Bootstrap.lua
local NS = getgenv().EggsESP
local AppConfig = NS.Config
local S = NS.Services
local StateStore = NS.StateStore
local Utils = NS.Utils
local Stability = NS.Stability
local Movement = NS.Movement
local Farm = NS.Farm
local Rebirth = NS.Rebirth
local ESP = NS.ESP
local UI = NS.UI

local function cleanup()
    for _, conn in ipairs(StateStore._connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(StateStore._connections)

    if StateStore.antiAFKConnection then
        pcall(function() StateStore.antiAFKConnection:Disconnect() end)
        StateStore.antiAFKConnection = nil
    end
    if StateStore.noclipConnection then
        pcall(function() StateStore.noclipConnection:Disconnect() end)
        StateStore.noclipConnection = nil
    end

    Farm.stopAutoFarm()
    Farm.stopAutoBestEgg()
    Rebirth.stopAutoRebirth()
    Movement.stop()

    if StateStore.screenGui then
        pcall(function() StateStore.screenGui:Destroy() end)
        StateStore.screenGui = nil
    end

    StateStore.reset()
end

local function startApplication()
    cleanup()

    if not UI then
        warn("[Bootstrap] UI module missing — cannot mount")
        return
    end

    if not UI.mount then
        warn("[Bootstrap] UI.mount is nil — UI.lua may be incomplete")
        return
    end

    local UIResult = UI.mount()

    StateStore.track(S.LocalPlayer.CharacterAdded:Connect(function()
        Movement.stop()
        task.wait(1.0)
        Utils.resetVelocity(Utils.getRootPart())
    end))

    task.spawn(function()
        while UIResult and UIResult.ScreenGui and UIResult.ScreenGui.Parent do
            for egg, data in pairs(StateStore.eggData) do
                if egg and egg.Parent then
                    if data.NameBillboard and data.NameBillboard.Enabled then
                        ESP.updateBillboard(egg)
                    end
                else
                    ESP.removeEgg(egg)
                end
            end
            task.wait(0.3)
        end
    end)

    local function bindEggFolder(folder)
        local debounce = false
        local function queueUpdate()
            if debounce then return end
            debounce = true
            task.delay(0.25, function()
                debounce = false
                if UIResult.populateList then UIResult.populateList() end
                if UIResult.updateLiveEggsSummary then UIResult.updateLiveEggsSummary() end
            end)
        end

        StateStore.track(folder.ChildAdded:Connect(function(egg)
            StateStore.autoFarmProcessed[egg] = nil
            StateStore.eggCooldowns[egg] = nil
            ESP.updateEgg(egg)
            ESP.bindEggLifecycle(egg)
            queueUpdate()
            if Utils.isRareEgg(egg.Name) and UIResult.showRareAlert then
                UIResult.showRareAlert(egg)
            end
        end))

        StateStore.track(folder.ChildRemoved:Connect(function(egg)
            ESP.removeEgg(egg)
            queueUpdate()
        end))

        for _, egg in ipairs(folder:GetChildren()) do
            ESP.updateEgg(egg)
            ESP.bindEggLifecycle(egg)
        end
    end

    if S.RenderedEggsFolder then
        bindEggFolder(S.RenderedEggsFolder)
    else
        task.spawn(function()
            local folder = S.Workspace:WaitForChild("RenderedEggs", 60)
            if folder then
                S.RenderedEggsFolder = folder
                bindEggFolder(folder)
                if UIResult.populateList then UIResult.populateList() end
                if UIResult.updateLiveEggsSummary then UIResult.updateLiveEggsSummary() end
            end
        end)
    end

    Stability.setupAntiAFK(true)
    Stability.setupAutoRejoin()

    NS.API = {
        FireRebirth = Rebirth.fireRebirth,
        GetMissingRebirthEggs = Rebirth.scanMissingEggs,
        StartAutoRebirth = Rebirth.startAutoRebirth,
        StopAutoRebirth = Rebirth.stopAutoRebirth,
        Cleanup = cleanup,
    }

    print("[RideAPet v" .. AppConfig.Version .. "] Initialized successfully.")
end

startApplication()

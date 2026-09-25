-- src/LoadingScreen.lua
-- Animated Loading Screen for RideAPet / Vanguard

local NS = getgenv().EggsESP or getgenv().Vanguard or {}
getgenv().EggsESP = NS
getgenv().Vanguard = NS
local S = NS and NS.Services

local LoadingScreen = {}

local screenGui = nil
local mainFrame = nil
local progressBar = nil
local progressText = nil
local statusText = nil
local moduleText = nil
local timeText = nil
local logoImage = nil
local logoGlow = nil
local logoRing = nil
local spinnerDots = {}
local shimmer = nil
local particleContainer = nil
local currentProgress = 0
local startTime = os.clock()
local isComplete = false
local animationConnections = {}
local heartbeatConn = nil

local LOGO_URL = "https://yourimageshare.com/ib/K3HDoXCNox.png"

-- ══════════════════════════════════════════════════════════
-- HELPER
-- ══════════════════════════════════════════════════════════
local function tween(obj, props, time, style, dir)
    local ts = game:GetService("TweenService")
    return ts:Create(obj, TweenInfo.new(
        time or 0.3,
        style or Enum.EasingStyle.Quart,
        dir or Enum.EasingDirection.Out
    ), props)
end

local function disconnectAll()
    for _, conn in ipairs(animationConnections) do
        pcall(function() conn:Disconnect() end)
    end
    animationConnections = {}
    if heartbeatConn then
        pcall(function() heartbeatConn:Disconnect() end)
        heartbeatConn = nil
    end
end

-- ══════════════════════════════════════════════════════════
-- SHOW
-- ══════════════════════════════════════════════════════════
function LoadingScreen.Show()
    if screenGui and screenGui.Parent then return end

    startTime = os.clock()
    currentProgress = 0
    isComplete = false

    -- หา parent
    local targetParent
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then targetParent = hui end
    end
    if not targetParent then
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then targetParent = cg end
    end
    if not targetParent then
        targetParent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end

    -- ลบของเก่า
    local old = targetParent:FindFirstChild("Vanguard_Loading")
    if old then old:Destroy() end

    -- ═══ ScreenGui ═══
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Vanguard_Loading"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 9999
    screenGui.Parent = targetParent

    -- ═══ Blur background ═══
    local blur = Instance.new("BlurEffect")
    blur.Name = "Vanguard_Blur"
    blur.Size = 0
    blur.Parent = game:GetService("Lighting")
    tween(blur, { Size = 24 }, 0.6):Play()

    -- ═══ Main Frame ═══
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    mainFrame.ZIndex = 1
    mainFrame.Parent = screenGui

    -- Gradient (จะ animate ทีหลัง)
    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 15)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 18, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15)),
    })
    bgGradient.Rotation = 0
    bgGradient.Parent = mainFrame

    -- Fade in background
    tween(mainFrame, { BackgroundTransparency = 0.02 }, 0.4):Play()

    -- Animate gradient
    task.spawn(function()
        while screenGui and screenGui.Parent and not isComplete do
            for i = 0, 360, 8 do
                if not (screenGui and screenGui.Parent) then break end
                bgGradient.Rotation = i
                task.wait(0.04)
            end
        end
    end)

    -- ═══ Content Container ═══
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(0, 500, 0, 420)
    content.Position = UDim2.new(0.5, -250, 0.5, -210)
    content.BackgroundTransparency = 1
    content.ZIndex = 2
    content.Parent = mainFrame

    -- ═══ Logo Container ═══
    local logoContainer = Instance.new("Frame")
    logoContainer.Name = "LogoContainer"
    logoContainer.Size = UDim2.new(0, 160, 0, 160)
    logoContainer.Position = UDim2.new(0.5, -80, 0, 0)
    logoContainer.BackgroundTransparency = 1
    logoContainer.ZIndex = 3
    logoContainer.Parent = content

    -- ═══ Logo Glow (พื้นหลังเรืองแสง) ═══
    logoGlow = Instance.new("ImageLabel")
    logoGlow.Name = "LogoGlow"
    logoGlow.Size = UDim2.new(0, 180, 0, 180)
    logoGlow.Position = UDim2.new(0.5, -90, 0.5, -90)
    logoGlow.BackgroundTransparency = 1
    logoGlow.Image = LOGO_URL
    logoGlow.ImageColor3 = Color3.fromRGB(0, 230, 118)
    logoGlow.ImageTransparency = 0.75
    logoGlow.ScaleType = Enum.ScaleType.Fit
    logoGlow.ZIndex = 2
    logoGlow.Parent = logoContainer

    -- Animate glow (pulse)
    task.spawn(function()
        local dir = 1
        while screenGui and screenGui.Parent and logoGlow and logoGlow.Parent and not isComplete do
            local target = dir == 1 and 0.55 or 0.85
            local t = tween(logoGlow, { ImageTransparency = target }, 1.2)
            t:Play()
            task.wait(1.2)
            dir = -dir
        end
    end)

    -- Animate glow scale (pulse)
    task.spawn(function()
        while screenGui and screenGui.Parent and logoGlow and logoGlow.Parent and not isComplete do
            tween(logoGlow, { Size = UDim2.new(0, 200, 0, 200) }, 1.0):Play()
            task.wait(1.0)
            tween(logoGlow, { Size = UDim2.new(0, 180, 0, 180) }, 1.0):Play()
            task.wait(1.0)
        end
    end)

    -- ═══ Ring (วงกลมหมุนรอบโลโก้) ═══
    logoRing = Instance.new("Frame")
    logoRing.Name = "Ring"
    logoRing.Size = UDim2.new(0, 150, 0, 150)
    logoRing.Position = UDim2.new(0.5, -75, 0.5, -75)
    logoRing.BackgroundTransparency = 1
    logoRing.ZIndex = 2
    logoRing.Parent = logoContainer

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = logoRing

    local ringStroke = Instance.new("UIStroke")
    ringStroke.Name = "RingStroke"
    ringStroke.Color = Color3.fromRGB(0, 230, 118)
    ringStroke.Thickness = 2
    ringStroke.Transparency = 0.4
    ringStroke.Parent = logoRing

    -- Gradient บน ring (ทำให้ดูเหมือนหมุน)
    local ringGradient = Instance.new("UIGradient")
    ringGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
    })
    ringGradient.Parent = ringStroke

    -- Animate ring หมุน
    task.spawn(function()
        local rotate = 0
        while screenGui and screenGui.Parent and ringGradient and ringGradient.Parent and not isComplete do
            rotate = rotate + 6
            ringGradient.Rotation = rotate
            task.wait(0.03)
        end
    end)

    -- Animate ring breathe (ขยาย/หด)
    task.spawn(function()
        while screenGui and screenGui.Parent and logoRing and logoRing.Parent and not isComplete do
            tween(logoRing, { Size = UDim2.new(0, 160, 0, 160), Position = UDim2.new(0.5, -80, 0.5, -80) }, 0.8):Play()
            task.wait(0.8)
            tween(logoRing, { Size = UDim2.new(0, 140, 0, 140), Position = UDim2.new(0.5, -70, 0.5, -70) }, 0.8):Play()
            task.wait(0.8)
        end
    end)

    -- ═══ Particle Effect (จุดเล็ก ๆ รอบโลโก้) ═══
    particleContainer = Instance.new("Frame")
    particleContainer.Name = "Particles"
    particleContainer.Size = UDim2.new(0, 220, 0, 220)
    particleContainer.Position = UDim2.new(0.5, -110, 0.5, -110)
    particleContainer.BackgroundTransparency = 1
    particleContainer.ZIndex = 1
    particleContainer.Parent = logoContainer

    -- สร้าง particles 12 ตัว
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        local particle = Instance.new("Frame")
        particle.Name = "Particle" .. i
        particle.Size = UDim2.new(0, 6, 0, 6)
        particle.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
        particle.BorderSizePixel = 0
        particle.ZIndex = 1

        local pc = Instance.new("UICorner")
        pc.CornerRadius = UDim.new(1, 0)
        pc.Parent = particle

        particle.Parent = particleContainer

        -- เก็บ reference
        particle:SetAttribute("Angle", i / 12)
        particle:SetAttribute("Radius", 100)
    end

    -- Animate particles หมุนรอบ
    task.spawn(function()
        local rotation = 0
        while screenGui and screenGui.Parent and particleContainer and particleContainer.Parent and not isComplete do
            rotation = rotation + 0.03
            for _, particle in ipairs(particleContainer:GetChildren()) do
                if particle:IsA("Frame") then
                    local baseAngle = particle:GetAttribute("Angle") * math.pi * 2
                    local angle = baseAngle + rotation
                    local radius = particle:GetAttribute("Radius")
                    local x = math.cos(angle) * radius
                    local y = math.sin(angle) * radius
                    particle.Position = UDim2.new(0.5, x - 3, 0.5, y - 3)
                end
            end
            task.wait(0.02)
        end
    end)

    -- ═══ Logo Image ═══
    logoImage = Instance.new("ImageLabel")
    logoImage.Name = "Logo"
    logoImage.Size = UDim2.new(0, 120, 0, 120)
    logoImage.Position = UDim2.new(0.5, -60, 0.5, -60)
    logoImage.BackgroundTransparency = 1
    logoImage.Image = LOGO_URL
    logoImage.ScaleType = Enum.ScaleType.Fit
    logoImage.ZIndex = 4
    logoImage.ImageTransparency = 1
    logoImage.Parent = logoContainer

    -- Animation: Logo fade + bounce in
    logoImage.Size = UDim2.new(0, 60, 0, 60)
    logoImage.Position = UDim2.new(0.5, -30, 0.5, -30)
    tween(logoImage, { ImageTransparency = 0 }, 0.5):Play()
    tween(logoImage, {
        Size = UDim2.new(0, 120, 0, 120),
        Position = UDim2.new(0.5, -60, 0.5, -60),
    }, 0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

    -- Animation: Logo pulse (เต้นเบา ๆ)
    task.spawn(function()
        task.wait(1.0)
        while screenGui and screenGui.Parent and logoImage and logoImage.Parent and not isComplete do
            tween(logoImage, { Size = UDim2.new(0, 126, 0, 126), Position = UDim2.new(0.5, -63, 0.5, -63) }, 0.9):Play()
            task.wait(0.9)
            tween(logoImage, { Size = UDim2.new(0, 120, 0, 120), Position = UDim2.new(0.5, -60, 0.5, -60) }, 0.9):Play()
            task.wait(0.9)
        end
    end)

    -- ═══ Title ═══
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 32)
    title.Position = UDim2.new(0, 0, 0, 170)
    title.BackgroundTransparency = 1
    title.Text = "Luxury<font color='#00e676'>X</font>HUB"
    title.RichText = true
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 30
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextTransparency = 1
    title.ZIndex = 4
    title.Parent = content

    tween(title, { TextTransparency = 0 }, 0.6):Play()

    -- ═══ Version ═══
    local version = Instance.new("TextLabel")
    version.Name = "Version"
    version.Size = UDim2.new(1, 0, 0, 18)
    version.Position = UDim2.new(0, 0, 0, 204)
    version.BackgroundTransparency = 1
    version.Text = "v1.0.0 • Animated Loader"
    version.TextColor3 = Color3.fromRGB(150, 150, 150)
    version.TextSize = 12
    version.Font = Enum.Font.GothamMedium
    version.TextXAlignment = Enum.TextXAlignment.Center
    version.TextTransparency = 1
    version.ZIndex = 4
    version.Parent = content

    task.delay(0.3, function()
        tween(version, { TextTransparency = 0 }, 0.5):Play()
    end)

    -- ═══ Progress Bar Container ═══
    local progressContainer = Instance.new("Frame")
    progressContainer.Name = "ProgressContainer"
    progressContainer.Size = UDim2.new(1, -60, 0, 10)
    progressContainer.Position = UDim2.new(0, 30, 0, 250)
    progressContainer.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    progressContainer.BorderSizePixel = 0
    progressContainer.ZIndex = 4
    progressContainer.Parent = content

    local pcCorner = Instance.new("UICorner")
    pcCorner.CornerRadius = UDim.new(1, 0)
    pcCorner.Parent = progressContainer

    -- Progress fill
    progressBar = Instance.new("Frame")
    progressBar.Name = "Fill"
    progressBar.Size = UDim2.new(0, 0, 1, 0)
    progressBar.BackgroundColor3 = Color3.fromRGB(0, 230, 118)
    progressBar.BorderSizePixel = 0
    progressBar.ZIndex = 5
    progressBar.ClipsDescendants = true
    progressBar.Parent = progressContainer

    local pbCorner = Instance.new("UICorner")
    pbCorner.CornerRadius = UDim.new(1, 0)
    pbCorner.Parent = progressBar

    -- Shimmer effect on progress bar
    shimmer = Instance.new("Frame")
    shimmer.Name = "Shimmer"
    shimmer.Size = UDim2.new(0, 60, 1, 0)
    shimmer.Position = UDim2.new(-1, 0, 0, 0)
    shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    shimmer.BackgroundTransparency = 0.5
    shimmer.BorderSizePixel = 0
    shimmer.ZIndex = 6
    shimmer.Parent = progressBar

    local shimmerCorner = Instance.new("UICorner")
    shimmerCorner.CornerRadius = UDim.new(1, 0)
    shimmerCorner.Parent = shimmer

    local shimmerGradient = Instance.new("UIGradient")
    shimmerGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    shimmerGradient.Parent = shimmer

    -- Animate shimmer
    task.spawn(function()
        while screenGui and screenGui.Parent and shimmer and shimmer.Parent and not isComplete do
            shimmer.Position = UDim2.new(-1, 0, 0, 0)
            tween(shimmer, { Position = UDim2.new(1, 0, 0, 0) }, 1.5, Enum.EasingStyle.Linear):Play()
            task.wait(1.7)
        end
    end)

    -- ═══ Progress Text ═══
    progressText = Instance.new("TextLabel")
    progressText.Name = "Percent"
    progressText.Size = UDim2.new(1, 0, 0, 22)
    progressText.Position = UDim2.new(0, 0, 0, 268)
    progressText.BackgroundTransparency = 1
    progressText.Text = "0%"
    progressText.TextColor3 = Color3.fromRGB(0, 230, 118)
    progressText.TextSize = 15
    progressText.Font = Enum.Font.GothamBold
    progressText.TextXAlignment = Enum.TextXAlignment.Center
    progressText.TextTransparency = 1
    progressText.ZIndex = 4
    progressText.Parent = content

    task.delay(0.4, function()
        tween(progressText, { TextTransparency = 0 }, 0.5):Play()
    end)

    -- ═══ Status + Spinner Dots ═══
    local statusContainer = Instance.new("Frame")
    statusContainer.Name = "StatusContainer"
    statusContainer.Size = UDim2.new(1, -40, 0, 20)
    statusContainer.Position = UDim2.new(0, 20, 0, 305)
    statusContainer.BackgroundTransparency = 1
    statusContainer.ZIndex = 4
    statusContainer.Parent = content

    statusText = Instance.new("TextLabel")
    statusText.Name = "Status"
    statusText.Size = UDim2.new(1, -60, 1, 0)
    statusText.Position = UDim2.new(0, 30, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Initializing..."
    statusText.TextColor3 = Color3.fromRGB(230, 230, 230)
    statusText.TextSize = 14
    statusText.Font = Enum.Font.GothamMedium
    statusText.TextXAlignment = Enum.TextXAlignment.Center
    statusText.TextTransparency = 1
    statusText.ZIndex = 4
    statusText.Parent = statusContainer

    task.delay(0.5, function()
        tween(statusText, { TextTransparency = 0 }, 0.4):Play()
    end)

    -- Spinner dots (3 dots กระพริบ)
    for i = 1, 3 do
        local dot = Instance.new("Frame")
        dot.Name = "Dot" .. i
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Position = UDim2.new(0, 8 + (i - 1) * 12, 0.5, -3)
        dot.BackgroundColor3 = Color3.fromRGB(0, 230, 118)
        dot.BackgroundTransparency = 1
        dot.BorderSizePixel = 0
        dot.ZIndex = 5
        dot.Parent = statusContainer

        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = dot

        table.insert(spinnerDots, dot)
    end

    -- Animate dots
    task.spawn(function()
        task.wait(0.5)
        while screenGui and screenGui.Parent and not isComplete do
            for i, dot in ipairs(spinnerDots) do
                if dot and dot.Parent then
                    tween(dot, { BackgroundTransparency = 0 }, 0.2):Play()
                    task.wait(0.15)
                    tween(dot, { BackgroundTransparency = 1 }, 0.3):Play()
                end
            end
            task.wait(0.2)
        end
    end)

    -- ═══ Module Text ═══
    moduleText = Instance.new("TextLabel")
    moduleText.Name = "Module"
    moduleText.Size = UDim2.new(1, -40, 0, 16)
    moduleText.Position = UDim2.new(0, 20, 0, 332)
    moduleText.BackgroundTransparency = 1
    moduleText.Text = ""
    moduleText.TextColor3 = Color3.fromRGB(140, 140, 140)
    moduleText.TextSize = 11
    moduleText.Font = Enum.Font.Gotham
    moduleText.TextXAlignment = Enum.TextXAlignment.Center
    moduleText.TextTransparency = 1
    moduleText.ZIndex = 4
    moduleText.Parent = content

    task.delay(0.6, function()
        tween(moduleText, { TextTransparency = 0 }, 0.4):Play()
    end)

    -- ═══ Time Text ═══
    timeText = Instance.new("TextLabel")
    timeText.Name = "Time"
    timeText.Size = UDim2.new(1, 0, 0, 16)
    timeText.Position = UDim2.new(0, 0, 0, 365)
    timeText.BackgroundTransparency = 1
    timeText.Text = "⏱️ 0.0s"
    timeText.TextColor3 = Color3.fromRGB(100, 100, 110)
    timeText.TextSize = 11
    timeText.Font = Enum.Font.Gotham
    timeText.TextXAlignment = Enum.TextXAlignment.Center
    timeText.TextTransparency = 1
    timeText.ZIndex = 4
    timeText.Parent = content

    task.delay(0.7, function()
        tween(timeText, { TextTransparency = 0 }, 0.4):Play()
    end)
end

-- ══════════════════════════════════════════════════════════
-- UPDATE
-- ══════════════════════════════════════════════════════════
function LoadingScreen.Update(progress, status, moduleName)
    if not screenGui or not screenGui.Parent then return end
    if isComplete then return end

    progress = math.clamp(progress or currentProgress, 0, 100)
    currentProgress = progress

    -- Animate progress bar
    tween(progressBar, { Size = UDim2.new(progress / 100, 0, 1, 0) }, 0.3):Play()

    if progressText then
        progressText.Text = string.format("%d%%", math.floor(progress))
        -- Pop animation
        progressText.TextSize = 18
        tween(progressText, { TextSize = 15 }, 0.2):Play()
    end
    if status and statusText then
        statusText.Text = status
    end
    if moduleName and moduleText then
        moduleText.Text = moduleName
    end
    if timeText then
        local elapsed = os.clock() - startTime
        timeText.Text = string.format("⏱️ %.1fs", elapsed)
    end

    if progress >= 100 then
        isComplete = true
    end
end

-- ══════════════════════════════════════════════════════════
-- COMPLETE
-- ══════════════════════════════════════════════════════════
function LoadingScreen.Complete()
    if not screenGui or not screenGui.Parent then return end

    isComplete = true

    LoadingScreen.Update(100, "✅ Ready!", "")

    task.wait(0.3)

    -- Fade out everything
    local ts = game:GetService("TweenService")
    local fadeTween = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

    if mainFrame then
        ts:Create(mainFrame, fadeTween, { BackgroundTransparency = 1 }):Play()
    end

    for _, obj in ipairs(screenGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            ts:Create(obj, fadeTween, { TextTransparency = 1 }):Play()
        elseif obj:IsA("ImageLabel") then
            ts:Create(obj, fadeTween, { ImageTransparency = 1 }):Play()
        elseif obj:IsA("Frame") then
            ts:Create(obj, fadeTween, { BackgroundTransparency = 1 }):Play()
        elseif obj:IsA("UIStroke") then
            ts:Create(obj, fadeTween, { Transparency = 1 }):Play()
        end
    end

    -- Fade out blur
    local blur = game:GetService("Lighting"):FindFirstChild("Vanguard_Blur")
    if blur then
        ts:Create(blur, fadeTween, { Size = 0 }):Play()
    end

    task.wait(0.6)

    disconnectAll()
    if blur then blur:Destroy() end
    if screenGui then screenGui:Destroy() end
    screenGui = nil
end

-- ══════════════════════════════════════════════════════════
-- HIDE
-- ══════════════════════════════════════════════════════════
function LoadingScreen.Hide()
    disconnectAll()
    local blur = game:GetService("Lighting"):FindFirstChild("Vanguard_Blur")
    if blur then blur:Destroy() end
    if screenGui then
        pcall(function() screenGui:Destroy() end)
        screenGui = nil
    end
end

NS.LoadingScreen = LoadingScreen

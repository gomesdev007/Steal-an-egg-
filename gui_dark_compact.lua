-- steal an egg - compact dark gui
-- instant pickup + anti ragdoll + guardian controller

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local instantPickup = false
local antiRagdoll = false
local guardianEnabled = false
local instantConnection
local ragdollActive = false

-- exact anti-ragdoll system from the original base
local antiRagdollUtility = {
    Players = Players,
    ReplicatedStorage = ReplicatedStorage,
    connections = nil,
    active = false
}

antiRagdollUtility.GetConnections = function(obj, signal)
    local s, r = pcall(function()
        return getconnections(obj[signal])
    end)
    if s and r then
        return r
    end
    return nil
end

antiRagdollUtility.Disconnect = function(conns)
    local s, r = pcall(function()
        local patched = 0
        for _, conn in next, conns do
            conn:Disconnect()
            patched += 1
        end
        return patched
    end)
    if s and r ~= 0 then
        return true
    end
    return false
end

function antiRagdollUtility:init()
    self.LocalPlayer = self.Players.LocalPlayer
    if not self.LocalPlayer or not getconnections then
        return false
    end

    self.Packages = self.ReplicatedStorage:FindFirstChild("Packages")
    if not self.Packages then return false end

    self.Networking = self.Packages:FindFirstChild("Networking")
    if not self.Networking then return false end

    -- IMPORTANT: the original uses this exact object name
    self["RE/RigSync/Refresh"] = self.Networking:FindFirstChild("RE/RigSync/Refresh")
    if not self["RE/RigSync/Refresh"] then return false end

    self.connections = self.GetConnections(
        self["RE/RigSync/Refresh"],
        "OnClientEvent"
    )

    if not self.connections then return false end

    return self.Disconnect(self.connections)
end

function antiRagdollUtility:activate()
    if self.active then return true end
    local result = self:init()
    if result then
        self.active = true
        ragdollActive = true
        return true
    end
    return false
end

function antiRagdollUtility:deactivate()
    if not self.active then
        ragdollActive = false
        return true
    end
    self.active = false
    self.connections = nil
    ragdollActive = false
    return true
end

local function instantActivate()
    if instantConnection then return true end
    instantConnection = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, plr)
        if not instantPickup or plr ~= player then return end
        if tostring(prompt) == "CarryAreaEgg" then
            pcall(function()
                prompt.HoldDuration = 0
            end)
        end
    end)
    return true
end

local function instantDeactivate()
    if instantConnection then
        instantConnection:Disconnect()
        instantConnection = nil
    end
end

local SPEED = _G.RyderGuardianSpeed or 400
function _G.GuardianSetSpeed(v)
    SPEED = math.clamp(math.floor(v), 50, 500)
end
local MIN_SPEED = 50
local MAX_SPEED = 500

local PAUSE_POSITION = Vector3.new(594, 71, -373)
local DESTINATION = Vector3.new(497, 71, -354)
local PAUSE_DISTANCE = 3
local PAUSE_TIME = 0.50
local HEAD_UP = 1.5
local HEAD_BACK = 2
local WALK_ANIMATION_ID = "rbxassetid://131533059911792"
local WALK_ANIMATION_SPEED = 8.196428

local enabled = false
local clone = nil
local cloneHead = nil
local walkTrack = nil
local guardConnection = nil
local playerConnection = nil
local playerReleased = false
local pauseStarted = false
local finalMoveStarted = false
local finalMoveConnection = nil
local originalTransparency = {}

local guardArea = workspace.__OBJECTS.Areas.GuardAreas["Titan Temple"]
local guard = guardArea and guardArea:FindFirstChild("Guard")

if not guard then
    warn("Guardian não encontrado.")
end

local function hideOriginal()
    if not guard then return end
    originalTransparency = {}
    for _, object in ipairs(guard:GetDescendants()) do
        if object:IsA("BasePart") then
            originalTransparency[object] = object.LocalTransparencyModifier
            object.LocalTransparencyModifier = 1
        elseif object:IsA("Decal") or object:IsA("Texture") then
            originalTransparency[object] = object.Transparency
            object.Transparency = 1
        end
    end
end

local function showOriginal()
    for object, value in pairs(originalTransparency) do
        if object and object.Parent then
            if object:IsA("BasePart") then
                object.LocalTransparencyModifier = value
            elseif object:IsA("Decal") or object:IsA("Texture") then
                object.Transparency = value
            end
        end
    end
    originalTransparency = {}
end

local function stopConnections()
    if guardConnection then guardConnection:Disconnect(); guardConnection = nil end
    if playerConnection then playerConnection:Disconnect(); playerConnection = nil end
    if finalMoveConnection then finalMoveConnection:Disconnect(); finalMoveConnection = nil end
end

local function cleanup()
    stopConnections()
    if walkTrack then
        pcall(function() walkTrack:Stop(); walkTrack:Destroy() end)
        walkTrack = nil
    end
    if clone then clone:Destroy(); clone = nil end
    cloneHead = nil
    showOriginal()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
    end
    playerReleased = false
    pauseStarted = false
    finalMoveStarted = false
end

local function GoTo(pos)
    local dist = math.huge
    repeat
        if not enabled or not guard then return false end
        local dt = task.wait(0.01)
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        local start = root.Position
        local target = pos.BoundsCFrame.Position
        local difference = target - start
        dist = difference.Magnitude
        if dist <= 5 then break end
        if dist > 0 then
            local step = math.min(dist, dt * SPEED)
            character:MoveTo(start + difference.Unit * step)
        end
    until dist <= 5
    return true
end

local function startFinalMove()
    if finalMoveStarted or not enabled then return end
    finalMoveStarted = true
    playerReleased = true
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end
    humanoid.PlatformStand = false
    humanoid.AutoRotate = true
    humanoid.WalkSpeed = SPEED
    root.CFrame = CFrame.new(PAUSE_POSITION + Vector3.new(0, 3, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    humanoid:MoveTo(DESTINATION)
    local elapsed = 0
    finalMoveConnection = RunService.Heartbeat:Connect(function(dt)
        if not enabled then return end
        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
        local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        if not currentHumanoid or not currentRoot then return end
        if (currentRoot.Position - DESTINATION).Magnitude <= 4 then
            finalMoveConnection:Disconnect()
            finalMoveConnection = nil
            return
        end
        elapsed += dt
        if elapsed >= 0.20 then
            elapsed = 0
            currentHumanoid:MoveTo(DESTINATION)
        end
    end)
end

function _G.GuardianActivate()
    if enabled or not guard then return end
    enabled = true
    playerReleased = false
    pauseStarted = false
    finalMoveStarted = false
    local spawnCFrame = guard:GetPivot()
    local pos = {BoundsCFrame = spawnCFrame}
    hideOriginal()
    local arrived = GoTo(pos)
    if not arrived or not enabled then return end
    task.wait(0.10)
    if not enabled then return end
    clone = guard:Clone()
    clone.Name = "GuardianClone"
    clone.Parent = workspace
    clone:PivotTo(spawnCFrame)
    for _, object in ipairs(clone:GetDescendants()) do
        if object:IsA("BasePart") then
            object.CanCollide = true
            object.CanTouch = true
            object.CanQuery = true
            object.Massless = true
        end
    end
    local animationController = clone:FindFirstChild("AnimationController", true)
    if animationController then
        local animator = animationController:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = animationController
        end
        local animation = Instance.new("Animation")
        animation.AnimationId = WALK_ANIMATION_ID
        walkTrack = animator:LoadAnimation(animation)
        walkTrack.Looped = true
        walkTrack.Priority = Enum.AnimationPriority.Action
        walkTrack:Play()
        walkTrack:AdjustSpeed(WALK_ANIMATION_SPEED)
    end
    cloneHead = clone:FindFirstChild("Head", true)
    if not cloneHead or not cloneHead:IsA("BasePart") then
        enabled = false
        cleanup()
        return
    end
    guardConnection = RunService.Heartbeat:Connect(function(dt)
        if not enabled or not clone or not clone.Parent or pauseStarted then return end
        local currentCFrame = clone:GetPivot()
        local currentPosition = currentCFrame.Position
        local difference = PAUSE_POSITION - currentPosition
        local distance = difference.Magnitude
        if distance <= PAUSE_DISTANCE then
            clone:PivotTo(CFrame.lookAt(PAUSE_POSITION, PAUSE_POSITION + currentCFrame.LookVector))
            pauseStarted = true
            if walkTrack then walkTrack:AdjustSpeed(0) end
            task.delay(PAUSE_TIME, function()
                if not enabled or not clone or not clone.Parent then return end
                startFinalMove()
                if clone then clone:Destroy(); clone = nil end
                cloneHead = nil
                if walkTrack then
                    pcall(function() walkTrack:Stop(); walkTrack:Destroy() end)
                    walkTrack = nil
                end
            end)
            return
        end
        local direction = difference.Unit
        local movement = math.min(SPEED * dt, distance)
        local newPosition = currentPosition + direction * movement
        clone:PivotTo(CFrame.lookAt(newPosition, newPosition + direction))
    end)
    playerConnection = RunService.RenderStepped:Connect(function()
        if not enabled or playerReleased or not clone or not clone.Parent or not cloneHead then return end
        local character = player.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid then return end
        local targetCFrame = cloneHead.CFrame * CFrame.new(0, cloneHead.Size.Y / 2 + HEAD_UP, HEAD_BACK)
        root.CFrame = targetCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
    end)
end

function _G.GuardianDeactivate()
    if not enabled then return end
    enabled = false
    cleanup()
end

local gui = Instance.new("ScreenGui")
gui.Name = "StealEggGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(245, 225)
main.Position = UDim2.new(0.5, -122, 0.5, -112)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(52, 52, 57)
stroke.Thickness = 1
stroke.Transparency = 0.1
stroke.Parent = main

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 42)
top.BackgroundTransparency = 1
top.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "steal an egg"
title.TextColor3 = Color3.fromRGB(235, 235, 238)
title.TextSize = 14
title.Font = Enum.Font.GothamMedium
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(70, 18)
status.Position = UDim2.new(1, -105, 0, 12)
status.BackgroundTransparency = 1
status.Text = "idle"
status.TextColor3 = Color3.fromRGB(145, 145, 150)
status.TextSize = 10
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Right
status.Parent = top

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(28, 28)
minimize.Position = UDim2.new(1, -34, 0, 7)
minimize.BackgroundTransparency = 1
minimize.Text = "—"
minimize.TextColor3 = Color3.fromRGB(165, 165, 170)
minimize.TextSize = 17
minimize.Font = Enum.Font.Gotham
minimize.Parent = top

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -50)
content.Position = UDim2.fromOffset(10, 45)
content.BackgroundTransparency = 1
content.Parent = main

local function makeToggle(name, y)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 38)
    button.Position = UDim2.fromOffset(0, y)
    button.BackgroundColor3 = Color3.fromRGB(28, 28, 31)
    button.AutoButtonColor = false
    button.Text = ""
    button.Parent = content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = button
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -65, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(215, 215, 218)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = button
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.fromOffset(28, 16)
    indicator.Position = UDim2.new(1, -40, 0.5, -8)
    indicator.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
    indicator.Parent = button
    local ic = Instance.new("UICorner")
    ic.CornerRadius = UDim.new(1, 0)
    ic.Parent = indicator
    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(12, 12)
    dot.Position = UDim2.fromOffset(2, 2)
    dot.BackgroundColor3 = Color3.fromRGB(155, 155, 160)
    dot.Parent = indicator
    local dc = Instance.new("UICorner")
    dc.CornerRadius = UDim.new(1, 0)
    dc.Parent = dot
    return button, indicator, dot
end

local pickupButton, pickupIndicator, pickupDot = makeToggle("instant pickup", 0)
local ragdollButton, ragdollIndicator, ragdollDot = makeToggle("anti ragdoll", 44)
local guardianButton, guardianIndicator, guardianDot = makeToggle("guardian", 88)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, 0, 0, 18)
speedLabel.Position = UDim2.fromOffset(0, 132)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "guardian speed: 400"
speedLabel.TextColor3 = Color3.fromRGB(150, 150, 155)
speedLabel.TextSize = 10
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = content

local sliderBackground = Instance.new("Frame")
sliderBackground.Size = UDim2.new(1, 0, 0, 7)
sliderBackground.Position = UDim2.fromOffset(0, 157)
sliderBackground.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
sliderBackground.BorderSizePixel = 0
sliderBackground.Parent = content

local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(1, 0)
sliderCorner.Parent = sliderBackground

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(350 / 450, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(135, 135, 140)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBackground

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = sliderFill

local sliderButton = Instance.new("TextButton")
sliderButton.Size = UDim2.fromOffset(15, 15)
sliderButton.AnchorPoint = Vector2.new(0.5, 0.5)
sliderButton.Position = UDim2.new(350 / 450, 0, 0.5, 0)
sliderButton.BackgroundColor3 = Color3.fromRGB(230, 230, 232)
sliderButton.Text = ""
sliderButton.BorderSizePixel = 0
sliderButton.Parent = sliderBackground

local sbc = Instance.new("UICorner")
sbc.CornerRadius = UDim.new(1, 0)
sbc.Parent = sliderButton

local SPEED_MIN = 50
local SPEED_MAX = 500
local sliderDragging = false

local function setGuardianSpeed(speed)
    speed = math.clamp(math.floor(speed), SPEED_MIN, SPEED_MAX)
    speedLabel.Text = "guardian speed: " .. speed
    local percent = (speed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
    sliderFill.Size = UDim2.new(percent, 0, 1, 0)
    sliderButton.Position = UDim2.new(percent, 0, 0.5, 0)
    _G.RyderGuardianSpeed = speed
    if _G.GuardianSetSpeed then
        _G.GuardianSetSpeed(speed)
    end
end

local function setSpeedFromX(x)
    local width = sliderBackground.AbsoluteSize.X
    if width <= 0 then return end
    local relative = math.clamp(x - sliderBackground.AbsolutePosition.X, 0, width)
    local percent = relative / width
    setGuardianSpeed(SPEED_MIN + (SPEED_MAX - SPEED_MIN) * percent)
end

sliderBackground.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = true
        setSpeedFromX(input.Position.X)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not sliderDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        setSpeedFromX(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = false
    end
end)

local function setToggle(button, indicator, dot, enabledState)
    local bg = enabledState and Color3.fromRGB(76, 27, 32) or Color3.fromRGB(28, 28, 31)
    local ind = enabledState and Color3.fromRGB(185, 45, 52) or Color3.fromRGB(55, 55, 60)
    local dotPos = enabledState and UDim2.fromOffset(14, 2) or UDim2.fromOffset(2, 2)
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = bg}):Play()
    TweenService:Create(indicator, TweenInfo.new(0.15), {BackgroundColor3 = ind}):Play()
    TweenService:Create(dot, TweenInfo.new(0.15), {Position = dotPos}):Play()
end

local function updateStatus()
    local active = instantPickup or antiRagdoll or guardianEnabled
    status.Text = active and "active" or "idle"
    status.TextColor3 = active and Color3.fromRGB(95, 205, 120) or Color3.fromRGB(145, 145, 150)
end

pickupButton.MouseButton1Click:Connect(function()
    instantPickup = not instantPickup
    if instantPickup then instantActivate() else instantDeactivate() end
    setToggle(pickupButton, pickupIndicator, pickupDot, instantPickup)
    updateStatus()
end)

ragdollButton.MouseButton1Click:Connect(function()
    if antiRagdoll then
        antiRagdoll = false
        antiRagdollUtility:deactivate()
    else
        antiRagdoll = antiRagdollUtility:activate()
    end
    setToggle(ragdollButton, ragdollIndicator, ragdollDot, antiRagdoll)
    updateStatus()
end)

guardianButton.MouseButton1Click:Connect(function()
    guardianEnabled = not guardianEnabled
    if guardianEnabled then
        task.spawn(function()
            if _G.GuardianActivate then _G.GuardianActivate() end
        end)
    else
        if _G.GuardianDeactivate then _G.GuardianDeactivate() end
    end
    setToggle(guardianButton, guardianIndicator, guardianDot, guardianEnabled)
    updateStatus()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
    if not guardianEnabled or triggeredPlayer ~= player then return end
    task.delay(0.50, function()
        if guardianEnabled and _G.GuardianActivate then
            _G.GuardianActivate()
        end
    end)
end)

local dragging = false
local dragStart
local startPos
local dragInput

top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        dragInput = input
    end
end)

top.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    main.Size = minimized and UDim2.fromOffset(245, 45) or UDim2.fromOffset(245, 225)
    minimize.Text = minimized and "+" or "—"
end)

setGuardianSpeed(400)
setToggle(pickupButton, pickupIndicator, pickupDot, false)
setToggle(ragdollButton, ragdollIndicator, ragdollDot, false)
setToggle(guardianButton, guardianIndicator, guardianDot, false)
updateStatus()

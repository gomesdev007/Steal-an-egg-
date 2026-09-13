local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/refs/heads/main/Fun%C3%A7%C3%A3odoclon"))()
end)

local SPEED = 300
local MIN_SPEED = 50
local MAX_SPEED = 500
local DESTINATION = Vector3.new(497, 71, -354)
local SLOW_DISTANCE = 20
local SLOW_SPEED = 50

local HEAD_UP = 5
local HEAD_BACK = 0

local WALK_ANIMATION_ID = "rbxassetid://75608548920054"
local WALK_ANIMATION_SPEED = 2

local enabled = false
local clone = nil
local cloneHead = nil
local walkTrack = nil
local guardConnection = nil
local playerConnection = nil
local promptAutoConnection = nil
local originalTransparency = {}
local travelToken = 0
local guardArea = workspace.__OBJECTS.Areas.GuardAreas["Cherry Blossom"]
local guard = guardArea:FindFirstChild("Guard")

if not guard then
    warn("Guardian não encontrado.")
    return
end

local gui = Instance.new("ScreenGui")
gui.Name = "GuardianController"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(190, 105)
main.Position = UDim2.new(0.5, -95, 0.72, 0)
main.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local dragging = false
local dragStart
local startPosition
local function updateDrag(input)
    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
end
main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)
main.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateDrag(input)
    end
end)

local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(170, 34)
button.Position = UDim2.fromOffset(10, 8)
button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Text = "guardian: off"
button.TextSize = 14
button.Font = Enum.Font.GothamMedium
button.BorderSizePixel = 0
button.Parent = main

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = button

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.fromOffset(170, 18)
speedLabel.Position = UDim2.fromOffset(10, 48)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
speedLabel.Text = "speed: 300"
speedLabel.TextSize = 12
speedLabel.Font = Enum.Font.Gotham
speedLabel.Parent = main

local sliderBackground = Instance.new("Frame")
sliderBackground.Size = UDim2.fromOffset(170, 8)
sliderBackground.Position = UDim2.fromOffset(10, 78)
sliderBackground.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
sliderBackground.BorderSizePixel = 0
sliderBackground.Parent = main

local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(1, 0)
sliderCorner.Parent = sliderBackground

local sliderFill = Instance.new("Frame")
local initialPercent = (SPEED - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
sliderFill.Size = UDim2.new(initialPercent, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBackground

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = sliderFill

local sliderButton = Instance.new("TextButton")
sliderButton.Size = UDim2.fromOffset(16, 16)
sliderButton.AnchorPoint = Vector2.new(0.5, 0.5)
sliderButton.Position = UDim2.new(initialPercent, 0, 0.5, 0)
sliderButton.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
sliderButton.Text = ""
sliderButton.BorderSizePixel = 0
sliderButton.Parent = sliderBackground

local sliderButtonCorner = Instance.new("UICorner")
sliderButtonCorner.CornerRadius = UDim.new(1, 0)
sliderButtonCorner.Parent = sliderButton

local sliderDragging = false
local function setSpeedFromX(x)
    local width = sliderBackground.AbsoluteSize.X
    if width <= 0 then return end
    local relative = math.clamp(x - sliderBackground.AbsolutePosition.X, 0, width)
    local percent = relative / width
    SPEED = math.floor(MIN_SPEED + (MAX_SPEED - MIN_SPEED) * percent)
    speedLabel.Text = "speed: " .. SPEED
    sliderFill.Size = UDim2.new(percent, 0, 1, 0)
    sliderButton.Position = UDim2.new(percent, 0, 0.5, 0)
end
sliderBackground.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = true
        setSpeedFromX(input.Position.X)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        setSpeedFromX(input.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = false
    end
end)

local function hideOriginal()
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
end

local function cleanup()
    travelToken += 1
    stopConnections()
    if walkTrack then
        pcall(function()
            walkTrack:Stop()
            walkTrack:Destroy()
        end)
        walkTrack = nil
    end
    if clone then
        clone:Destroy()
        clone = nil
    end
    cloneHead = nil
    showOriginal()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
    end
end

-- Complete Auto Steal movement method, adapted only for this controller.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

local function alternateHandler(parent)
    for _ = 1, 6 do
        if not parent or parent == workspace then
            return false
        end
        if (parent:IsA("Model") and parent:FindFirstChildWhichIsA("Humanoid")) or parent:FindFirstChildWhichIsA("AnimationController") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local function refreshGroundParams()
    local data = {}
    if player.Character then
        data[#data + 1] = player.Character
    end
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            data[#data + 1] = otherPlayer.Character
        end
    end
    if clone and clone.Parent then
        data[#data + 1] = clone
    end
    groundParams.FilterDescendantsInstances = data
end

local function probeGround(x, z, differenceNumber, raycastResultNumber)
    local difference = differenceNumber
    for _ = 1, 4 do
        local raycastResult = workspace:Raycast(
            Vector3.new(x, difference, z),
            Vector3.new(0, -(difference - (differenceNumber - raycastResultNumber)), 0),
            groundParams
        )
        if not raycastResult then
            return nil
        end
        if not alternateHandler(raycastResult.Instance) then
            return raycastResult.Position.Y
        end
        difference = raycastResult.Position.Y - 0.6
        if difference <= differenceNumber - raycastResultNumber then
            return nil
        end
    end
    return nil
end

local function getGroundY(x, z, y)
    local low = probeGround(x, z, y + 7, 7 + 420)
    if low then
        return low
    end
    local high = probeGround(x, z, y + 160, 160 + 420)
    if high and high > y + 7 then
        return high
    end
    return nil
end

local function getCharacterRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function getCharacterHumanoid()
    local character = player.Character
    return character and character:FindFirstChildWhichIsA("Humanoid") or nil
end

local function getCharacterOffset()
    local root = getCharacterRoot()
    local humanoid = getCharacterHumanoid()
    local number = root and root.Size.Y * 0.5 or 1
    local numberResult = 2
    if humanoid then
        local success, hipHeight = pcall(function()
            return humanoid.HipHeight
        end)
        if success and type(hipHeight) == "number" and hipHeight > 0 then
            numberResult = hipHeight
        end
    end
    return number + numberResult
end

local function updateMovementProperties()
    if not clone then return end
    pcall(function()
        local rootPart = clone:FindFirstChild("HumanoidRootPart", true)
        if rootPart and rootPart:IsA("BasePart") then
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function autoStealMove(targetPosition, secondaryFlag, callback, token)
    local movingPart = clone and (clone:FindFirstChild("HumanoidRootPart", true) or clone:FindFirstChildWhichIsA("BasePart", true))
    if not movingPart or not movingPart:IsA("BasePart") then
        return false
    end

    local position = movingPart.Position
    local vector = Vector3.new(targetPosition.X - position.X, 0, targetPosition.Z - position.Z)
    local magnitude = vector.Magnitude
    if magnitude <= 0.5 then
        return true
    end

    local unit = vector.Unit
    local rotation = CFrame.lookAt(Vector3.zero, unit).Rotation
    local sumNumber = getCharacterOffset()
    refreshGroundParams()
    local sum = (getGroundY(position.X, position.Z, position.Y - sumNumber) or position.Y - sumNumber) + sumNumber
    local number = 0
    local previousPosition = position
    local timeout = tick() + magnitude / math.max(SPEED, 1) + 10
    local flag = false
    local timestamp = tick()

    while enabled and clone and clone.Parent and token == travelToken and (not callback or callback()) do
        local dt = RunService.Heartbeat:Wait()
        local capturedInput = clone and (clone:FindFirstChild("HumanoidRootPart", true) or clone:FindFirstChildWhichIsA("BasePart", true))
        if not capturedInput or not capturedInput.Parent then
            break
        end

        if (capturedInput.Position - previousPosition).Magnitude > 2 then
            previousPosition = capturedInput.Position
            timestamp = tick()
        elseif tick() - timestamp > 0.5 then
            timestamp = tick()
        end

        if timeout < tick() then
            break
        end

        local quotientNumber = math.min(SPEED * math.min(dt, 0.1), magnitude - number)
        local secondaryQuotientNumber = math.max(1, math.ceil(quotientNumber / 6))
        local quotient = quotientNumber / secondaryQuotientNumber

        for _ = 1, secondaryQuotientNumber do
            number = math.min(magnitude, number + quotient)
            local nextPosition = position + unit * number
            local condition = getGroundY(nextPosition.X, nextPosition.Z, sum - sumNumber)
            if condition then
                sum += math.clamp(condition + sumNumber - sum, -24, 24)
            end
            if magnitude <= number then
                break
            end
        end

        local nextPosition = position + unit * number
        pcall(function()
            clone:PivotTo(CFrame.new(nextPosition.X, sum, nextPosition.Z) * rotation)
        end)
        updateMovementProperties()

        if number >= magnitude - 0.01 then
            flag = true
            break
        end
    end

    if token ~= travelToken then
        return false
    end

    if flag then
        return true
    end

    local alternateInput = clone and (clone:FindFirstChild("HumanoidRootPart", true) or clone:FindFirstChildWhichIsA("BasePart", true))
    if not alternateInput then
        return false
    end
    return Vector3.new(targetPosition.X - alternateInput.Position.X, 0, targetPosition.Z - alternateInput.Position.Z).Magnitude <= (secondaryFlag or 8)
end

local function activate()
    if enabled then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    enabled = true
    travelToken += 1
    local thisToken = travelToken
    button.Text = "guardian: on"
    hideOriginal()

    clone = guard:Clone()
    clone.Name = "GuardianClone"
    clone.Parent = workspace
    clone:PivotTo(root.CFrame)

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
        local animator = animationController:FindFirstChildOfClass("Animator") or Instance.new("Animator")
        animator.Parent = animationController
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
        button.Text = "guardian: off"
        return
    end

    playerConnection = RunService.RenderStepped:Connect(function()
        if not enabled or not clone or not clone.Parent or not cloneHead then return end
        local currentCharacter = player.Character
        local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        local humanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
        if not currentRoot or not humanoid then return end
        local targetCFrame = cloneHead.CFrame * CFrame.new(0, cloneHead.Size.Y / 2 + HEAD_UP, HEAD_BACK)
        currentRoot.CFrame = targetCFrame
        currentRoot.AssemblyLinearVelocity = Vector3.zero
        currentRoot.AssemblyAngularVelocity = Vector3.zero
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
    end)

    task.spawn(function()
        local success = autoStealMove(DESTINATION, 0.05, function()
            return enabled and clone and clone.Parent and thisToken == travelToken
        end, thisToken)
        if success and enabled and thisToken == travelToken then
            enabled = false
            cleanup()
            button.Text = "guardian: off"
        end
    end)
end

local function deactivate()
    if not enabled then return end
    enabled = false
    cleanup()
    button.Text = "guardian: off"
end

promptAutoConnection = ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
    if triggeredPlayer ~= player then return end
    task.delay(0.50, function()
        if not enabled then
            task.spawn(activate)
        end
    end)
end)

button.MouseButton1Click:Connect(function()
    if enabled then
        deactivate()
    else
        task.spawn(activate)
    end
end)

print("Guardian Controller otimizado carregado. Auto Steal movement speed: 300")
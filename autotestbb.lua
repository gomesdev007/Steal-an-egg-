local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

pcall(function()
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/refs/heads/main/Fun%C3%A7%C3%A3odoclon"
    ))()
end)

local SPEED = 400
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

-- Auto Steal movement settings
local STEP_MAX = 6
local PROBE_LOW = 7
local PROBE_HIGH = 160
local PROBE_DOWN = 420

local enabled = false
local clone = nil
local cloneHead = nil
local walkTrack = nil

local guardConnection = nil
local playerConnection = nil
local finalMoveConnection = nil
local promptAutoConnection = nil

local playerReleased = false
local pauseStarted = false
local finalMoveStarted = false

local originalTransparency = {}

local guardArea = workspace.__OBJECTS.Areas.GuardAreas["Titan Temple"]
local guard = guardArea:FindFirstChild("Guard")

if not guard then
    warn("Guardian não encontrado.")
    return
end

-- =====================================================
-- AUTO STEAL MOVEMENT METHOD
-- Replaces the old GoTo/MoveTo movement for the player.
-- =====================================================

local moving = false
local travelToken = 0

local function getCharacter()
    return player.Character
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildWhichIsA("Humanoid")
end

local function getRootHeight()
    local root = getRoot()
    local humanoid = getHumanoid()
    if not root then
        return 2
    end

    local hipHeight = 2
    if humanoid then
        pcall(function()
            hipHeight = humanoid.HipHeight
        end)
    end

    return (root.Size.Y * 0.5) + hipHeight
end

local function recoverCharacter()
    local character = getCharacter()
    if not character then
        return
    end

    for _, item in ipairs(character:GetDescendants()) do
        if item:IsA("BasePart") then
            if item.Anchored then
                pcall(function()
                    item.Anchored = false
                end)
            end
        elseif item:IsA("Weld") or item:IsA("WeldConstraint") then
            pcall(function()
                local p0 = item.Part0
                local p1 = item.Part1

                if (p0 and not p0:IsDescendantOf(character))
                    or (p1 and not p1:IsDescendantOf(character)) then
                    item:Destroy()
                end
            end)
        end
    end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function refreshRayFilter()
    local filter = {}
    local character = getCharacter()

    if character then
        table.insert(filter, character)
    end

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            table.insert(filter, otherPlayer.Character)
        end
    end

    rayParams.FilterDescendantsInstances = filter
end

local function isCharacterLike(instance)
    for _ = 1, 6 do
        if not instance or instance == workspace then
            return false
        end

        if instance:IsA("Model") then
            if instance:FindFirstChildWhichIsA("Humanoid")
                or instance:FindFirstChildWhichIsA("AnimationController") then
                return true
            end
        end

        instance = instance.Parent
    end

    return false
end

local function probeGround(x, z, startY, downDistance)
    local currentY = startY

    for _ = 1, 4 do
        local result = workspace:Raycast(
            Vector3.new(x, currentY, z),
            Vector3.new(0, -downDistance, 0),
            rayParams
        )

        if not result then
            return nil
        end

        if not isCharacterLike(result.Instance) then
            return result.Position.Y
        end

        currentY = result.Position.Y - 0.6
    end

    return nil
end

local function getGroundY(x, z, y)
    local low = probeGround(
        x,
        z,
        y + PROBE_LOW,
        PROBE_LOW + PROBE_DOWN
    )

    if low then
        return low
    end

    return probeGround(
        x,
        z,
        y + PROBE_HIGH,
        PROBE_HIGH + PROBE_DOWN
    )
end

local function setPhysics(root, humanoid)
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    pcall(function()
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end)
end

local function autoStealMove(targetPosition, token)
    local root = getRoot()
    local humanoid = getHumanoid()

    if not root or not humanoid then
        return false
    end

    local startPosition = root.Position
    local vector = Vector3.new(
        targetPosition.X - startPosition.X,
        0,
        targetPosition.Z - startPosition.Z
    )

    local magnitude = vector.Magnitude
    if magnitude <= 0.5 then
        return true
    end

    local unit = vector.Unit
    local rotation = CFrame.lookAt(Vector3.zero, unit).Rotation
    local rootHeight = getRootHeight()

    refreshRayFilter()

    local groundY = getGroundY(
        startPosition.X,
        startPosition.Z,
        startPosition.Y - rootHeight
    )

    local currentY = (groundY or (startPosition.Y - rootHeight)) + rootHeight
    local travelled = 0

    local deadline = tick() + magnitude / math.max(SPEED, 1) + 10
    local lastPosition = startPosition
    local lastProgress = tick()
    local reached = false

    while enabled and moving and token == travelToken and tick() < deadline do
        local dt = RunService.Heartbeat:Wait()

        if not enabled or not moving or token ~= travelToken then
            break
        end

        root = getRoot()
        humanoid = getHumanoid()

        if not root or not root.Parent or not humanoid or humanoid.Health <= 0 then
            break
        end

        if (root.Position - lastPosition).Magnitude > 2 then
            lastPosition = root.Position
            lastProgress = tick()
        elseif tick() - lastProgress > 0.5 then
            lastProgress = tick()
            recoverCharacter()
        end

        local stepDistance = math.min(
            SPEED * math.min(dt, 0.1),
            magnitude - travelled
        )

        local subSteps = math.max(
            1,
            math.ceil(stepDistance / STEP_MAX)
        )

        local step = stepDistance / subSteps

        for _ = 1, subSteps do
            travelled = math.min(
                magnitude,
                travelled + step
            )

            local nextPosition = startPosition + unit * travelled

            local detectedGround = getGroundY(
                nextPosition.X,
                nextPosition.Z,
                currentY - rootHeight
            )

            if detectedGround then
                currentY += math.clamp(
                    detectedGround + rootHeight - currentY,
                    -STEP_MAX * 4,
                    STEP_MAX * 4
                )
            end

            if travelled >= magnitude then
                break
            end
        end

        local nextPosition = startPosition + unit * travelled

        pcall(function()
            root.CFrame = CFrame.new(
                nextPosition.X,
                currentY,
                nextPosition.Z
            ) * rotation
        end)

        setPhysics(root, humanoid)

        if travelled >= magnitude - 0.01 then
            reached = true
            break
        end
    end

    return reached
end

local function GoTo(pos)
    if not pos or not pos.BoundsCFrame then
        return false
    end

    moving = true
    travelToken += 1

    local token = travelToken
    local reached = autoStealMove(
        pos.BoundsCFrame.Position,
        token
    )

    if token == travelToken then
        moving = false
    end

    return reached
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

    main.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end

main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

main.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
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
speedLabel.Text = "speed: 400"
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
sliderFill.Size = UDim2.new(
    (SPEED - MIN_SPEED) / (MAX_SPEED - MIN_SPEED),
    0,
    1,
    0
)
sliderFill.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBackground

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = sliderFill

local sliderButton = Instance.new("TextButton")
sliderButton.Size = UDim2.fromOffset(16, 16)
sliderButton.AnchorPoint = Vector2.new(0.5, 0.5)
sliderButton.Position = UDim2.new(
    (SPEED - MIN_SPEED) / (MAX_SPEED - MIN_SPEED),
    0,
    0.5,
    0
)
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
    if width <= 0 then
        return
    end

    local relative = math.clamp(
        x - sliderBackground.AbsolutePosition.X,
        0,
        width
    )

    local percent = relative / width

    SPEED = math.floor(
        MIN_SPEED + (MAX_SPEED - MIN_SPEED) * percent
    )

    speedLabel.Text = "speed: " .. SPEED
    sliderFill.Size = UDim2.new(percent, 0, 1, 0)
    sliderButton.Position = UDim2.new(percent, 0, 0.5, 0)
end

sliderBackground.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        sliderDragging = true
        setSpeedFromX(input.Position.X)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not sliderDragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        setSpeedFromX(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
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
    if guardConnection then
        guardConnection:Disconnect()
        guardConnection = nil
    end

    if playerConnection then
        playerConnection:Disconnect()
        playerConnection = nil
    end

    if finalMoveConnection then
        finalMoveConnection:Disconnect()
        finalMoveConnection = nil
    end
end

local function cleanup()
    moving = false
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

    playerReleased = false
    pauseStarted = false
    finalMoveStarted = false
end

local function startFinalMove()
    if finalMoveStarted or not enabled then
        return
    end

    finalMoveStarted = true
    playerReleased = true

    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return
    end

    humanoid.PlatformStand = false
    humanoid.AutoRotate = true
    humanoid.WalkSpeed = SPEED

    root.CFrame = CFrame.new(
        PAUSE_POSITION + Vector3.new(0, 3, 0)
    )

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    -- Final movement remains the normal humanoid movement phase.
    humanoid:MoveTo(DESTINATION)

    local elapsed = 0

    finalMoveConnection = RunService.Heartbeat:Connect(function(dt)
        if not enabled then
            return
        end

        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter
            and currentCharacter:FindFirstChildOfClass("Humanoid")

        local currentRoot = currentCharacter
            and currentCharacter:FindFirstChild("HumanoidRootPart")

        if not currentHumanoid or not currentRoot then
            return
        end

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

local function activate()
    if enabled then
        return
    end

    enabled = true
    button.Text = "guardian: on"

    playerReleased = false
    pauseStarted = false
    finalMoveStarted = false

    local spawnCFrame = guard:GetPivot()

    local pos = {
        BoundsCFrame = spawnCFrame
    }

    hideOriginal()

    -- Uses the supplied Auto Steal movement method.
    local arrived = GoTo(pos)

    if not arrived or not enabled then
        return
    end

    task.wait(0.10)

    if not enabled then
        return
    end

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
        button.Text = "guardian: off"
        return
    end

    guardConnection = RunService.Heartbeat:Connect(function(dt)
        if not enabled or not clone or not clone.Parent then
            return
        end

        if pauseStarted then
            return
        end

        local currentCFrame = clone:GetPivot()
        local currentPosition = currentCFrame.Position

        local difference = PAUSE_POSITION - currentPosition
        local distance = difference.Magnitude

        if distance <= PAUSE_DISTANCE then
            clone:PivotTo(
                CFrame.lookAt(
                    PAUSE_POSITION,
                    PAUSE_POSITION + currentCFrame.LookVector
                )
            )

            pauseStarted = true

            if walkTrack then
                walkTrack:AdjustSpeed(0)
            end

            task.delay(PAUSE_TIME, function()
                if not enabled then
                    return
                end

                if not clone or not clone.Parent then
                    return
                end

                startFinalMove()

                if clone then
                    clone:Destroy()
                    clone = nil
                end

                cloneHead = nil

                if walkTrack then
                    pcall(function()
                        walkTrack:Stop()
                        walkTrack:Destroy()
                    end)
                    walkTrack = nil
                end
            end)

            return
        end

        local direction = difference.Unit
        local movement = math.min(SPEED * dt, distance)
        local newPosition = currentPosition + direction * movement

        clone:PivotTo(
            CFrame.lookAt(
                newPosition,
                newPosition + direction
            )
        )
    end)

    playerConnection = RunService.RenderStepped:Connect(function()
        if not enabled or playerReleased then
            return
        end

        if not clone or not clone.Parent or not cloneHead then
            return
        end

        local character = player.Character
        if not character then
            return
        end

        local root = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if not root or not humanoid then
            return
        end

        local targetCFrame = cloneHead.CFrame * CFrame.new(
            0,
            cloneHead.Size.Y / 2 + HEAD_UP,
            HEAD_BACK
        )

        root.CFrame = targetCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
    end)
end

local function deactivate()
    if not enabled then
        return
    end

    enabled = false
    cleanup()

    button.Text = "guardian: off"
end

promptAutoConnection = ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
    if triggeredPlayer ~= player then
        return
    end

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

print("Guardian Controller com Auto Steal movement carregado.")

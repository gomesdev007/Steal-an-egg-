-- Auto Steal movement test
-- Uses the Auto Steal movement method from the supplied open source.
-- Travel speed changed to 400.
-- Destination uses the same spawn-resolution method from the open source.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local TRAVEL_SPEED = 400
local STEP_MAX = 6
local PROBE_LOW = 7
local PROBE_HIGH = 160
local PROBE_DOWN = 420

local moving = false
local travelToken = 0

local function getCharacter()
    return LocalPlayer.Character
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
    if not root then return 2 end
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
    if not character then return end
    for _, item in ipairs(character:GetDescendants()) do
        if item:IsA("BasePart") then
            if item.Anchored then
                pcall(function() item.Anchored = false end)
            end
        elseif item:IsA("Weld") or item:IsA("WeldConstraint") then
            pcall(function()
                local p0 = item.Part0
                local p1 = item.Part1
                if (p0 and not p0:IsDescendantOf(character)) or (p1 and not p1:IsDescendantOf(character)) then
                    item:Destroy()
                end
            end)
        end
    end
    local humanoid = getHumanoid()
    if humanoid then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function refreshRayFilter()
    local filter = {}
    local character = getCharacter()
    if character then table.insert(filter, character) end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            table.insert(filter, player.Character)
        end
    end
    rayParams.FilterDescendantsInstances = filter
end

local function isCharacterLike(instance)
    for _ = 1, 6 do
        if not instance or instance == workspace then return false end
        if instance:IsA("Model") then
            if instance:FindFirstChildWhichIsA("Humanoid") or instance:FindFirstChildWhichIsA("AnimationController") then
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
        if not result then return nil end
        if not isCharacterLike(result.Instance) then
            return result.Position.Y
        end
        currentY = result.Position.Y - 0.6
    end
    return nil
end

local function getGroundY(x, z, y)
    local low = probeGround(x, z, y + PROBE_LOW, PROBE_LOW + PROBE_DOWN)
    if low then return low end
    return probeGround(x, z, y + PROBE_HIGH, PROBE_HIGH + PROBE_DOWN)
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

-- Complete Auto Steal-style movement core.
local function autoStealMove(targetPosition, token)
    local root = getRoot()
    local humanoid = getHumanoid()
    if not root or not humanoid then return false end

    local startPosition = root.Position
    local vector = Vector3.new(
        targetPosition.X - startPosition.X,
        0,
        targetPosition.Z - startPosition.Z
    )
    local magnitude = vector.Magnitude
    if magnitude <= 0.5 then return true end

    local unit = vector.Unit
    local rotation = CFrame.lookAt(Vector3.zero, unit).Rotation
    local rootHeight = getRootHeight()

    local groundY = getGroundY(
        startPosition.X,
        startPosition.Z,
        startPosition.Y - rootHeight
    )

    local currentY = (groundY or (startPosition.Y - rootHeight)) + rootHeight
    local travelled = 0
    local deadline = tick() + magnitude / TRAVEL_SPEED + 10
    local lastPosition = startPosition
    local lastProgress = tick()
    local reached = false

    while moving and token == travelToken and tick() < deadline do
        local dt = RunService.Heartbeat:Wait()
        if not moving or token ~= travelToken then break end

        root = getRoot()
        humanoid = getHumanoid()
        if not root or not root.Parent or not humanoid or humanoid.Health <= 0 then break end

        local distanceMoved = (root.Position - lastPosition).Magnitude
        if distanceMoved > 2 then
            lastPosition = root.Position
            lastProgress = tick()
        elseif tick() - lastProgress > 0.5 then
            lastProgress = tick()
            recoverCharacter()
        end

        local stepDistance = math.min(
            TRAVEL_SPEED * math.min(dt, 0.1),
            magnitude - travelled
        )

        local subSteps = math.max(1, math.ceil(stepDistance / STEP_MAX))
        local step = stepDistance / subSteps

        for _ = 1, subSteps do
            travelled = math.min(magnitude, travelled + step)
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

            if travelled >= magnitude then break end
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

-- Same destination resolution used by the open source value116():
-- 1. Player.RespawnLocation
-- 2. First SpawnLocation in Workspace
-- 3. Own plot pivot as fallback
local function findMySpawn()
    local respawnLocation = LocalPlayer.RespawnLocation

    if respawnLocation and respawnLocation:IsA("BasePart") then
        return respawnLocation.CFrame.Position + Vector3.new(0, 4, 0)
    end

    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("SpawnLocation") then
            return descendant.Position + Vector3.new(0, 4, 0)
        end
    end

    local plots = workspace:FindFirstChild("Plots")
    if plots then
        local rf = workspace:FindFirstChild("RF")
        local homestead = rf and rf:FindFirstChild("Homestead")
        local askState = homestead and homestead:FindFirstChild("AskState")

        if askState and askState:IsA("RemoteFunction") then
            local ok, data = pcall(function()
                return askState:InvokeServer()
            end)
            if ok and type(data) == "table" then
                local owners = data.OwnersBySlot or data.SlotOwners or data.Owners or data.Slots
                if type(owners) == "table" then
                    for slot, owner in pairs(owners) do
                        local ownerId = owner
                        if type(owner) == "table" then
                            ownerId = owner.UserId or owner.OwnerUserId or owner.Id or owner.Name
                        end
                        if ownerId == LocalPlayer.UserId or ownerId == tostring(LocalPlayer.UserId) or ownerId == LocalPlayer.Name then
                            local plot = plots:FindFirstChild(tostring(slot))
                            if plot then
                                local okPivot, pivot = pcall(function()
                                    return plot:GetPivot()
                                end)
                                if okPivot and pivot then
                                    return pivot.Position + Vector3.new(0, 4, 0)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoStealSpawnMovementTest"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 190, 0, 76)
frame.Position = UDim2.new(0.5, -95, 0.5, -38)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
frame.BorderSizePixel = 0
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(35, 35, 35)
stroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 23)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "auto steal movement"
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -20, 0, 32)
button.Position = UDim2.new(0, 10, 0, 34)
button.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
button.BorderSizePixel = 0
button.Font = Enum.Font.GothamMedium
button.Text = "go to my spawn"
button.TextColor3 = Color3.fromRGB(220, 220, 220)
button.TextSize = 12
button.Parent = frame
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

local dragging = false
local dragStart
local startFramePosition

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startFramePosition = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startFramePosition.X.Scale,
            startFramePosition.X.Offset + delta.X,
            startFramePosition.Y.Scale,
            startFramePosition.Y.Offset + delta.Y
        )
    end
end)

button.MouseButton1Click:Connect(function()
    if moving then
        moving = false
        travelToken += 1
        button.Text = "go to my spawn"
        return
    end

    local spawnPosition = findMySpawn()
    if not spawnPosition then
        button.Text = "spawn not found"
        task.delay(2, function()
            if button.Parent then button.Text = "go to my spawn" end
        end)
        return
    end

    moving = true
    travelToken += 1
    local token = travelToken
    button.Text = "moving..."
    refreshRayFilter()

    task.spawn(function()
        local reached = autoStealMove(spawnPosition, token)
        if token ~= travelToken then return end
        moving = false
        button.Text = reached and "arrived" or "stopped"
        task.wait(1)
        if button.Parent then button.Text = "go to my spawn" end
    end)
end)

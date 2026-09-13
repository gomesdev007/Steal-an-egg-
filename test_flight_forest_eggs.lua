-- test_flight_forest_eggs.lua
-- Test only: uses the Auto Steal movement/flight method from the supplied open-source script.
-- No prompt firing, pickup, delivery, or MoveTo is used.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local SPEED = 1000
local STEP_MAX = 6
local PROBE_LOW = 7
local PROBE_HIGH = 160
local PROBE_DOWN = 420

local running = false
local travelToken = 0

local function getCharacterParts()
    local character = player.Character
    if not character then return nil, nil, nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    return character, root, humanoid
end

local function isCharacterOrHumanoidModel(instance)
    local parent = instance
    for _ = 1, 6 do
        if not parent then break end
        if parent:IsA("Model") and parent:FindFirstChildWhichIsA("Humanoid") then
            return true
        end
        if parent:IsA("Model") and parent:FindFirstChildWhichIsA("AnimationController") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local function makeGroundParams(character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.IgnoreWater = true
    return params
end

local function probeGround(x, z, startY, raycastParams)
    local difference = startY

    for _ = 1, 4 do
        local result = workspace:Raycast(
            Vector3.new(x, difference, z),
            Vector3.new(0, -(difference - (startY - PROBE_DOWN)), 0),
            raycastParams
        )

        if not result then
            return nil
        end

        if not isCharacterOrHumanoidModel(result.Instance) then
            return result.Position.Y
        end

        difference = result.Position.Y - 0.6

        if difference <= startY - PROBE_DOWN then
            return nil
        end
    end

    return nil
end

local function getGroundY(x, z, baseY, raycastParams)
    local low = probeGround(x, z, baseY + PROBE_LOW, raycastParams)
    if low then
        return low
    end

    local high = probeGround(x, z, baseY + PROBE_HIGH, raycastParams)
    if high and high > baseY + PROBE_LOW then
        return high
    end

    return nil
end

local function getRootHeight(root, humanoid)
    local half = root and root.Size.Y * 0.5 or 1
    local hip = 2

    if humanoid then
        local ok, value = pcall(function()
            return humanoid.HipHeight
        end)
        if ok and type(value) == "number" and value > 0 then
            hip = value
        end
    end

    return half + hip
end

local function stopPhysics(root, humanoid)
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    if humanoid then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end
end

local function findForestEgg()
    local ok, snapshot = pcall(function()
        local packages = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
        local networking = packages and packages:FindFirstChild("Networking")
        local remote = networking and networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
        if not remote then return nil end
        if remote:IsA("RemoteFunction") then
            return remote:InvokeServer()
        end
    end)

    if not ok or type(snapshot) ~= "table" or type(snapshot.Records) ~= "table" then
        return nil
    end

    local slots = workspace:FindFirstChild("AreaEggSlotsClient")
    if not slots then return nil end

    local nearest = nil
    local nearestDistance = math.huge
    local root = select(2, getCharacterParts())
    if not root then return nil end

    for _, record in pairs(snapshot.Records) do
        if type(record) == "table" and record.State == "Slot" and record.Uid then
            local area = tostring(record.AreaId or "")
            local areaLower = string.lower(area)

            if string.find(areaLower, "forest", 1, true) then
                local model = slots:FindFirstChild(tostring(record.Uid))
                local part

                if model then
                    if model:IsA("BasePart") then
                        part = model
                    elseif model:IsA("Model") then
                        part = model.PrimaryPart
                            or model:FindFirstChild("Hitbox")
                            or model:FindFirstChildWhichIsA("BasePart")
                    end
                end

                local position = part and part.Position
                if not position then
                    local cf = record.BoundsCFrame or record.BottomCFrame
                    position = cf and cf.Position
                end

                if position then
                    local distance = (root.Position - position).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearest = position
                    end
                end
            end
        end
    end

    return nearest
end

-- This is the movement core from Auto Steal: horizontal vector, ground probing,
-- Heartbeat timing, capped step size, CFrame movement, velocity reset and Physics state.
local function autoStealFlight(target)
    local character, root, humanoid = getCharacterParts()
    if not character or not root or not humanoid or humanoid.Health <= 0 then
        return false
    end

    local position = root.Position
    local horizontal = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
    local magnitude = horizontal.Magnitude

    if magnitude <= 0.5 then
        return true
    end

    local unit = horizontal.Unit
    local rotation = CFrame.lookAt(Vector3.zero, unit).Rotation
    local raycastParams = makeGroundParams(character)
    local groundOffset = getRootHeight(root, humanoid)
    local groundY = getGroundY(position.X, position.Z, position.Y - groundOffset, raycastParams)
        or position.Y - groundOffset
    groundY += groundOffset

    local travelled = 0
    local deadline = tick() + magnitude / SPEED + 10
    local lastPosition = root.Position
    local stuckTimestamp = tick()

    while running and travelToken == travelToken and humanoid.Health > 0 do
        local dt = RunService.Heartbeat:Wait()
        if not running then break end

        if (root.Position - lastPosition).Magnitude > 2 then
            lastPosition = root.Position
            stuckTimestamp = tick()
        elseif tick() - stuckTimestamp > 0.5 then
            stuckTimestamp = tick()
        end

        if deadline < tick() then
            break
        end

        local quotientNumber = math.min(SPEED * math.min(dt, 0.1), magnitude - travelled)
        local subSteps = math.max(1, math.ceil(quotientNumber / STEP_MAX))
        local quotient = quotientNumber / subSteps

        for _ = 1, subSteps do
            travelled = math.min(magnitude, travelled + quotient)

            local nextPosition = position + unit * travelled
            local probedY = getGroundY(nextPosition.X, nextPosition.Z, groundY - groundOffset, raycastParams)

            if probedY then
                groundY += math.clamp(
                    probedY + groundOffset - groundY,
                    -STEP_MAX * 4,
                    STEP_MAX * 4
                )
            end

            if magnitude <= travelled then
                break
            end
        end

        local nextPosition = position + unit * travelled

        pcall(function()
            root.CFrame = CFrame.new(nextPosition.X, groundY, nextPosition.Z) * rotation
        end)

        stopPhysics(root, humanoid)

        if travelled >= magnitude - 0.01 then
            return true
        end
    end

    return false
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoStealFlightTest"
gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end

local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(180, 48)
button.Position = UDim2.new(0.5, -90, 0.75, 0)
button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
button.TextColor3 = Color3.fromRGB(235, 235, 235)
button.TextSize = 15
button.Font = Enum.Font.GothamMedium
button.Text = "test forest flight"
button.AutoButtonColor = true
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button

local dragging = false
local dragStart
local startPos

button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = button.Position
    end
end)

button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = dragStart or input.Position
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStart
    button.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end)

game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

button.MouseButton1Click:Connect(function()
    if running then
        running = false
        travelToken += 1
        button.Text = "test forest flight"
        return
    end

    running = true
    travelToken += 1
    button.Text = "searching forest..."

    task.spawn(function()
        local target = findForestEgg()

        if not target then
            running = false
            button.Text = "forest egg not found"
            task.wait(1.5)
            if button.Parent then button.Text = "test forest flight" end
            return
        end

        button.Text = "flying to forest egg"
        autoStealFlight(target)

        running = false
        button.Text = "test forest flight"
    end)
end)

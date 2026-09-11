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

    self["RE/RigSync/Refresh"] =
        self.Networking:FindFirstChild("RE/RigSync/Refresh")

    if not self["RE/RigSync/Refresh"] then
        return false
    end

    self.connections = self.GetConnections(
        self["RE/RigSync/Refresh"],
        "OnClientEvent"
    )

    if not self.connections then
        return false
    end

    return self.Disconnect(self.connections)
end

function antiRagdollUtility:activate()
    if self.active then
        return true
    end

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
    if instantConnection then
        return true
    end

    instantConnection =
        ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, plr)
            if not instantPickup or plr ~= player then
                return
            end

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

pcall(function()
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/refs/heads/main/Fun%C3%A7%C3%A3odoclon"
    ))()
end)

local guardianButton

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
local promptAutoConnection = nil

local originalTransparency = {}

local guardArea = workspace.__OBJECTS.Areas.GuardAreas["Titan Temple"]
local guard = guardArea:FindFirstChild("Guard")

if not guard then
    warn("Guardian não encontrado.")
    return
end

local function hideOriginal()
    originalTransparency = {}

    for _, object in ipairs(guard:GetDescendants()) do
        if object:IsA("BasePart") then
            originalTransparency[object] =
                object.LocalTransparencyModifier

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

local function GoTo(pos)
    local dist = math.huge

    repeat
        if not enabled then
            return false
        end

        local dt = task.wait(0.01)

        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not root then
            return false
        end

        local start = root.Position
        local target = pos.BoundsCFrame.Position
        local difference = target - start

        dist = difference.Magnitude

        if dist <= 5 then
            break
        end

        if dist > 0 then
            local step = math.min(dist, dt * SPEED)

            character:MoveTo(
                start + difference.Unit * step
            )
        end

    until dist <= 5

    return true
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

    humanoid:MoveTo(DESTINATION)

    local elapsed = 0

    finalMoveConnection = RunService.Heartbeat:Connect(function(dt)
        if not enabled then
            return
        end

        local currentCharacter = player.Character
        local currentHumanoid =
            currentCharacter and
            currentCharacter:FindFirstChildOfClass("Humanoid")

        local currentRoot =
            currentCharacter and
            currentCharacter:FindFirstChild("HumanoidRootPart")

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
    guardianButton.Text = "guardian: on"

    playerReleased = false
    pauseStarted = false
    finalMoveStarted = false

    local spawnCFrame = guard:GetPivot()

    local pos = {
        BoundsCFrame = spawnCFrame
    }

    hideOriginal()

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

    local animationController =
        clone:FindFirstChild("AnimationController", true)

    if animationController then
        local animator =
            animationController:FindFirstChildOfClass("Animator")

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
        guardianButton.Text = "guardian: off"
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

        local difference =
            PAUSE_POSITION - currentPosition

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

        local movement =
            math.min(
                SPEED * dt,
                distance
            )

        local newPosition =
            currentPosition +
            direction * movement

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

        local root =
            character:FindFirstChild("HumanoidRootPart")

        local humanoid =
            character:FindFirstChildOfClass("Humanoid")

        if not root or not humanoid then
            return
        end

        local targetCFrame =
            cloneHead.CFrame *
            CFrame.new(
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

    guardianButton.Text = "guardian: off"
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

local gui = Instance.new("ScreenGui")
gui.Name = "StealEggGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(235, 180)
main.Position = UDim2.new(0.5, -117, 0.5, -90)
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
title.Size = UDim2.new(1, -105, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "steal an egg"
title.TextColor3 = Color3.fromRGB(235, 235, 238)
title.TextSize = 14
title.Font = Enum.Font.GothamMedium
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(60, 18)
status.Position = UDim2.new(1, -92, 0, 12)
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

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -50)
content.Position = UDim2.fromOffset(10, 45)
content.BackgroundTransparency = 1
content.Parent = main

local minimized = false

local function setMinimized(value)
    minimized = value

    if minimized then
        content.Visible = false
        main.Size = UDim2.fromOffset(235, 42)
        minimize.Text = "+"
    else
        content.Visible = true
        main.Size = UDim2.fromOffset(235, 180)
        minimize.Text = "—"
    end
end

minimize.MouseButton1Click:Connect(function()
    setMinimized(not minimized)
end)

local function makeToggle(name, y)
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, 0, 0, 38)
    toggleButton.Position = UDim2.fromOffset(0, y)
    toggleButton.BackgroundColor3 = Color3.fromRGB(28, 28, 31)
    toggleButton.AutoButtonColor = false
    toggleButton.Text = ""
    toggleButton.Parent = content

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = toggleButton

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -65, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(215, 215, 218)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleButton

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.fromOffset(28, 16)
    indicator.Position = UDim2.new(1, -40, 0.5, -8)
    indicator.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
    indicator.Parent = toggleButton

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

    local function setActive(active)
        if active then
            TweenService:Create(
                indicator,
                TweenInfo.new(0.15),
                {BackgroundColor3 = Color3.fromRGB(155, 45, 45)}
            ):Play()

            TweenService:Create(
                dot,
                TweenInfo.new(0.15),
                {Position = UDim2.new(1, -14, 0, 2)}
            ):Play()
        else
            TweenService:Create(
                indicator,
                TweenInfo.new(0.15),
                {BackgroundColor3 = Color3.fromRGB(55, 55, 60)}
            ):Play()

            TweenService:Create(
                dot,
                TweenInfo.new(0.15),
                {Position = UDim2.fromOffset(2, 2)}
            ):Play()
        end
    end

    return toggleButton, setActive
end

local instantButton, setInstantVisual =
    makeToggle("instant pickup", 0)

local ragdollButton, setRagdollVisual =
    makeToggle("anti ragdoll", 43)

gaurdianButton = guardianButton
setGuardianVisual = select(2, makeToggle("guardian", 86))
guardianButton = select(1, content:FindFirstChild("guardian")) or guardianButton

-- Reuse the exact Guardian button reference required by the Guardian logic.
local guardianToggle = content:GetChildren()[3]
if guardianToggle and guardianToggle:IsA("TextButton") then
    guardianButton = guardianToggle
end

instantButton.MouseButton1Click:Connect(function()
    instantPickup = not instantPickup

    if instantPickup then
        instantActivate()
        setInstantVisual(true)
    else
        instantDeactivate()
        setInstantVisual(false)
    end

    status.Text = instantPickup and "active" or "idle"
end)

ragdollButton.MouseButton1Click:Connect(function()
    antiRagdoll = not antiRagdoll

    if antiRagdoll then
        antiRagdollUtility:activate()
        setRagdollVisual(true)
    else
        antiRagdollUtility:deactivate()
        setRagdollVisual(false)
    end

    status.Text = antiRagdoll and "active" or "idle"
end)

guardianButton.MouseButton1Click:Connect(function()
    if enabled then
        deactivate()
        guardianEnabled = false
        setGuardianVisual(false)
        status.Text = "idle"
    else
        guardianEnabled = true
        setGuardianVisual(true)
        task.spawn(activate)
        status.Text = "active"
    end
end)

print("Steal an Egg compact GUI loaded.")

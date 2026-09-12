local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/refs/heads/main/Fun%C3%A7%C3%A3odoclon"))()
end)

-- Guardian settings
local SPEED = 400
local MIN_SPEED = 400
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

local guardArea = workspace.__OBJECTS.Areas.GuardAreas["Cherry Blossom"]
local guard = guardArea and guardArea:FindFirstChild("Guard")

if not guard then
    warn("Guardian não encontrado.")
    return
end

-- Compkiller UI
local Compkiller = loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/CompKiller/refs/heads/main/src/source.luau"))()

local Window = Compkiller.new({
    Name = "GUARDIAN",
    Keybind = "LeftAlt",
    Logo = "rbxassetid://120245531583106",
    Scale = Compkiller.Scale.Window,
    TextSize = 15,
})

Window:DrawCategory({
    Name = "Guardian"
})

local GuardianTab = Window:DrawTab({
    Name = "Guardian Controller",
    Icon = "shield",
    EnableScrolling = true
})

local GuardianSection = GuardianTab:DrawSection({
    Name = "Guardian",
    Position = "left"
})

local GuardianToggle

local function setToggleVisual(value)
    if not GuardianToggle then
        return
    end

    pcall(function()
        GuardianToggle:Set(value)
    end)
end

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
end

local function activate()
    if enabled then
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then
        return
    end

    enabled = true
    setToggleVisual(true)

    local spawnCFrame = root.CFrame
    hideOriginal()

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
        setToggleVisual(false)
        return
    end

    guardConnection = RunService.Heartbeat:Connect(function(dt)
        if not enabled or not clone or not clone.Parent then
            return
        end

        local currentCFrame = clone:GetPivot()
        local currentPosition = currentCFrame.Position
        local difference = DESTINATION - currentPosition
        local distance = difference.Magnitude

        if distance <= 0.05 then
            clone:PivotTo(CFrame.lookAt(DESTINATION, DESTINATION + currentCFrame.LookVector))
            enabled = false
            cleanup()
            setToggleVisual(false)
            return
        end

        local direction = difference.Unit
        local currentSpeed = distance <= SLOW_DISTANCE and SLOW_SPEED or SPEED
        local movement = math.min(currentSpeed * dt, distance)
        local newPosition = currentPosition + direction * movement

        clone:PivotTo(CFrame.lookAt(newPosition, newPosition + direction))

        if walkTrack then
            local animationSpeed = currentSpeed == SLOW_SPEED
                and (WALK_ANIMATION_SPEED * 0.25)
                or WALK_ANIMATION_SPEED

            walkTrack:AdjustSpeed(animationSpeed)
        end
    end)

    playerConnection = RunService.RenderStepped:Connect(function()
        if not enabled then
            return
        end

        if not clone or not clone.Parent or not cloneHead then
            return
        end

        local currentCharacter = player.Character
        local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        local humanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")

        if not currentRoot or not humanoid then
            return
        end

        local targetCFrame = cloneHead.CFrame * CFrame.new(
            0,
            cloneHead.Size.Y / 2 + HEAD_UP,
            HEAD_BACK
        )

        currentRoot.CFrame = targetCFrame
        currentRoot.AssemblyLinearVelocity = Vector3.zero
        currentRoot.AssemblyAngularVelocity = Vector3.zero
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
    end)
end

local function deactivate()
    if not enabled then
        setToggleVisual(false)
        return
    end

    enabled = false
    cleanup()
    setToggleVisual(false)
end

GuardianToggle = GuardianSection:AddToggle({
    Name = "Guardian",
    Flag = "Guardian_Toggle",
    Default = false,
    Callback = function(value)
        if value then
            task.spawn(activate)
        else
            deactivate()
        end
    end,
})

GuardianSection:AddSlider({
    Name = "Speed",
    Min = 400,
    Max = 500,
    Default = 400,
    Round = 0,
    Flag = "Guardian_Speed",
    Callback = function(value)
        SPEED = math.clamp(math.floor(value), 400, 500)
    end,
})

GuardianSection:AddParagraph({
    Title = "Status",
    Content = "Guardian: OFF\nSpeed: 400 - 500\nAnimation: 75608548920054"
})

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

print("Guardian Controller + Compkiller carregado.")

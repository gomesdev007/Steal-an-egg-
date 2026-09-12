local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/refs/heads/main/Fun%C3%A7%C3%A3odoclon"))()
end)

local SPEED = 400
local MIN_SPEED = 50
local MAX_SPEED = 500

local DESTINATION = Vector3.new(497, 71, -354)
local SLOW_DISTANCE = 20
local SLOW_SPEED = 50

-- posição do jogador em cima do clone
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
    if enabled then return end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- captura a posição ATUAL do jogador; não usa a posição do Guardian original
    local spawnCFrame = root.CFrame

    enabled = true
    button.Text = "guardian: on"
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
        button.Text = "guardian: off"
        return
    end

    -- MOVIMENTO BASEADO NO SISTEMA PRONTO ENVIADO PELO USUÁRIO.
    -- Sem GoTo, sem ponto de pausa e sem mover o jogador até o Guardian original.
    guardConnection = RunService.Heartbeat:Connect(function(dt)
        if not enabled or not clone or not clone.Parent then return end

        local currentCFrame = clone:GetPivot()
        local currentPosition = currentCFrame.Position
        local difference = DESTINATION - currentPosition
        local distance = difference.Magnitude

        -- chegou na posição FINAL: encerra tudo imediatamente
        if distance <= 0.05 then
            clone:PivotTo(CFrame.lookAt(DESTINATION, DESTINATION + currentCFrame.LookVector))
            enabled = false
            cleanup()
            button.Text = "guardian: off"
            return
        end

        local direction = difference.Unit
        local currentSpeed = distance <= SLOW_DISTANCE and SLOW_SPEED or SPEED
        local movement = math.min(currentSpeed * dt, distance)
        local newPosition = currentPosition + direction * movement

        clone:PivotTo(CFrame.lookAt(newPosition, newPosition + direction))

        if walkTrack then
            walkTrack:AdjustSpeed(WALK_ANIMATION_SPEED)
        end
    end)

    -- mantém o personagem acima da cabeça, pegando carona
    playerConnection = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        if not clone or not clone.Parent or not cloneHead then return end

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

print("Guardian Controller otimizado carregado.")
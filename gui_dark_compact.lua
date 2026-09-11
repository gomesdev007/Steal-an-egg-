-- steal an egg - compact dark gui
-- redesigned interface: draggable on pc/mobile, compact, animated, toggleable functions

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local instantPickup = false
local antiRagdoll = false
local instantConnection
local ragdollConnections = {}

local function instantActivate()
    if instantConnection then return end
    instantConnection = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, plr)
        if not instantPickup or plr ~= player then return end
        if tostring(prompt) == "CarryAreaEgg" then
            pcall(function() prompt.HoldDuration = 0 end)
        end
    end)
end

local function instantDeactivate()
    if instantConnection then
        instantConnection:Disconnect()
        instantConnection = nil
    end
end

local function antiRagdollActivate()
    table.clear(ragdollConnections)
    pcall(function()
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        local networking = packages and packages:FindFirstChild("Networking")
        local re = networking and networking:FindFirstChild("RE")
        local rigSync = re and re:FindFirstChild("RigSync")
        local refresh = rigSync and rigSync:FindFirstChild("Refresh")
        if refresh and getconnections then
            for _, connection in ipairs(getconnections(refresh.OnClientEvent)) do
                if connection.Disconnect then
                    connection:Disconnect()
                    table.insert(ragdollConnections, connection)
                end
            end
        end
    end)
end

local function antiRagdollDeactivate()
    table.clear(ragdollConnections)
end

local gui = Instance.new("ScreenGui")
gui.Name = "StealEggGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(235, 145)
main.Position = UDim2.new(0.5, -117, 0.5, -72)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 55, 60)
stroke.Thickness = 1
stroke.Transparency = 0.15
stroke.Parent = main

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 40)
top.BackgroundTransparency = 1
top.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -65, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "steal an egg"
title.TextColor3 = Color3.fromRGB(235, 235, 238)
title.TextSize = 14
title.Font = Enum.Font.GothamMedium
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(65, 18)
status.Position = UDim2.new(1, -110, 0, 11)
status.BackgroundTransparency = 1
status.Text = "idle"
status.TextColor3 = Color3.fromRGB(145, 145, 150)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Right
status.Parent = top

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(28, 28)
minimize.Position = UDim2.new(1, -34, 0, 6)
minimize.BackgroundTransparency = 1
minimize.Text = "—"
minimize.TextColor3 = Color3.fromRGB(170, 170, 175)
minimize.TextSize = 17
minimize.Font = Enum.Font.Gotham
minimize.Parent = top

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -48)
content.Position = UDim2.fromOffset(10, 43)
content.BackgroundTransparency = 1
content.Parent = main

local function makeToggle(name, y)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 40)
    button.Position = UDim2.fromOffset(0, y)
    button.BackgroundColor3 = Color3.fromRGB(29, 29, 32)
    button.AutoButtonColor = false
    button.Text = ""
    button.Parent = content

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = button

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
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
    dot.BackgroundColor3 = Color3.fromRGB(160, 160, 165)
    dot.Parent = indicator

    local dc = Instance.new("UICorner")
    dc.CornerRadius = UDim.new(1, 0)
    dc.Parent = dot

    return button, indicator, dot
end

local pickupButton, pickupIndicator, pickupDot = makeToggle("instant pickup", 0)
local ragdollButton, ragdollIndicator, ragdollDot = makeToggle("anti ragdoll", 46)

local function setToggle(button, indicator, dot, enabled)
    local bg = enabled and Color3.fromRGB(80, 28, 32) or Color3.fromRGB(29, 29, 32)
    local ind = enabled and Color3.fromRGB(185, 45, 52) or Color3.fromRGB(55, 55, 60)
    local dotPos = enabled and UDim2.fromOffset(14, 2) or UDim2.fromOffset(2, 2)
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = bg}):Play()
    TweenService:Create(indicator, TweenInfo.new(0.15), {BackgroundColor3 = ind}):Play()
    TweenService:Create(dot, TweenInfo.new(0.15), {Position = dotPos}):Play()
end

local function updateStatus()
    local active = instantPickup or antiRagdoll
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
    antiRagdoll = not antiRagdoll
    if antiRagdoll then antiRagdollActivate() else antiRagdollDeactivate() end
    setToggle(ragdollButton, ragdollIndicator, ragdollDot, antiRagdoll)
    updateStatus()
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
    if input == dragInput and dragging then
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
    main.Size = minimized and UDim2.fromOffset(235, 45) or UDim2.fromOffset(235, 145)
    minimize.Text = minimized and "+" or "—"
end)

setToggle(pickupButton, pickupIndicator, pickupDot, false)
setToggle(ragdollButton, ragdollIndicator, ragdollDot, false)
updateStatus()

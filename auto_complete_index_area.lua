-- auto complete index only
-- target areas use the same area data used by the source Egg ESP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local normalSpeed = 100
local slowSpeed = 50
local slowEggDistance = 40
local slowPlotDistance = 30
local running = false
local selectedAreas = {}
local areaKeys = {}
local areaLabels = {}

local rarityOrder = {
    Common = 1, Rare = 2, Epic = 3, Legendary = 4,
    Mythic = 5, Divine = 6, Eternal = 7,
}

local function characterParts()
    local character = LocalPlayer.Character
    if not character then return nil, nil, nil end
    return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

-- Same source used by Egg ESP: ReplicatedStorage.Data.Areas
local function getAreaNames()
    local result = {}
    local seen = {}
    areaKeys = {}
    areaLabels = {}

    local dataFolder = ReplicatedStorage:FindFirstChild("Data")
    local areasModule = dataFolder and dataFolder:FindFirstChild("Areas")

    if areasModule and areasModule:IsA("ModuleScript") then
        local ok, data = pcall(require, areasModule)
        if ok and type(data) == "table" then
            data = data.Directory or data
            for key, info in pairs(data) do
                if type(key) == "string" and type(info) == "table" then
                    local label = info.DisplayName or info.Name or key
                    if type(label) == "string" and label ~= "" and not seen[label] then
                        seen[label] = true
                        result[#result + 1] = label
                        areaKeys[label] = key
                        areaLabels[key] = label
                    end
                end
            end
        end
    end

    -- Fallback only if the module is unavailable.
    if #result == 0 then
        for _, containerName in ipairs({"Areas", "Islands"}) do
            local container = workspace:FindFirstChild(containerName)
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    if not seen[child.Name] then
                        seen[child.Name] = true
                        result[#result + 1] = child.Name
                        areaKeys[child.Name] = child.Name
                        areaLabels[child.Name] = child.Name
                    end
                end
            end
        end
    end

    table.sort(result, function(a, b)
        local ka, kb = areaKeys[a], areaKeys[b]
        local ia, ib = dataFolder and areasModule, dataFolder and areasModule
        return tostring(a) < tostring(b)
    end)

    return result
end

local function isAreaSelected(prompt)
    local count = 0
    for _ in pairs(selectedAreas) do count += 1 end
    if count == 0 then return true end

    local obj = prompt.Parent
    while obj and obj ~= workspace do
        local name = obj.Name
        for label in pairs(selectedAreas) do
            if name == label or name == areaKeys[label] then
                return true
            end
        end
        obj = obj.Parent
    end
    return false
end

local function getRarity(prompt)
    local best = 0
    local obj = prompt.Parent
    for _ = 1, 8 do
        if not obj then break end
        local name = string.lower(obj.Name)
        for rarity, value in pairs(rarityOrder) do
            if name:find(string.lower(rarity), 1, true) then best = math.max(best, value) end
        end
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local text = string.lower(d.Text or "")
                for rarity, value in pairs(rarityOrder) do
                    if text:find(string.lower(rarity), 1, true) then best = math.max(best, value) end
                end
            end
        end
        obj = obj.Parent
    end
    return best
end

local function isEggPrompt(prompt)
    local action = string.lower(prompt.ActionText or "")
    local object = string.lower(prompt.ObjectText or "")
    local name = string.lower(prompt.Parent and prompt.Parent.Name or "")
    return action:find("grab",1,true) or action:find("take",1,true) or action:find("pick",1,true)
        or action:find("carry",1,true) or action:find("steal",1,true)
        or object:find("egg",1,true) or name:find("egg",1,true)
end

local function findBestEgg()
    local _, _, root = characterParts()
    if not root then return nil end
    local best, bestScore, bestDistance = nil, -1, math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled and isEggPrompt(obj) and isAreaSelected(obj) then
            local part = obj.Parent
            if part and part:IsA("BasePart") then
                local distance = (part.Position - root.Position).Magnitude
                local score = getRarity(obj)
                if score > bestScore or (score == bestScore and distance < bestDistance) then
                    best, bestScore, bestDistance = obj, score, distance
                end
            end
        end
    end
    return best
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    return pcall(function()
        if typeof(fireproximityprompt) == "function" then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(math.max(prompt.HoldDuration, 0.05))
            prompt:InputHoldEnd()
        end
    end)
end

local function getPlotPosition()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                if string.lower(obj.Text or ""):find(string.lower(LocalPlayer.Name), 1, true) then
                    local ok, pivot = pcall(function() return plot:GetPivot() end)
                    if ok then return pivot.Position end
                end
            end
        end
    end
    return nil
end

local function moveTo(position, slowDistance)
    local _, humanoid, root = characterParts()
    if not humanoid or not root then return false end
    while running do
        _, humanoid, root = characterParts()
        if not humanoid or not root then return false end
        local distance = (Vector3.new(position.X, root.Position.Y, position.Z) - root.Position).Magnitude
        if distance <= 3 then
            humanoid:MoveTo(position)
            return true
        end
        humanoid.WalkSpeed = distance <= slowDistance and slowSpeed or normalSpeed
        humanoid:MoveTo(position)
        task.wait(0.10)
    end
    return false
end

for _, old in ipairs(PlayerGui:GetChildren()) do
    if old.Name == "AutoCompleteIndexGui" or old.Name == "AutoCompleteIndexAreaGui" then
        old:Destroy()
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoCompleteIndexGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(230, 150)
frame.Position = UDim2.new(0, 12, 0.5, 55)
frame.BackgroundColor3 = Color3.fromRGB(22,22,22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

-- PC + mobile dragging
local dragging = false
local dragStart
local startPos
local dragInput

local function updateDrag(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        dragInput = input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        updateDrag(input)
    end
end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-16,0,28)
title.Position = UDim2.fromOffset(8,6)
title.BackgroundTransparency = 1
title.Text = "auto complete index"
title.TextColor3 = Color3.fromRGB(240,240,240)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

title.Active = false

local areaButton = Instance.new("TextButton")
areaButton.Size = UDim2.new(1,-16,0,34)
areaButton.Position = UDim2.fromOffset(8,40)
areaButton.BackgroundColor3 = Color3.fromRGB(35,35,35)
areaButton.BorderSizePixel = 0
areaButton.TextColor3 = Color3.fromRGB(225,225,225)
areaButton.Font = Enum.Font.Gotham
areaButton.TextSize = 12
areaButton.Text = "target egg areas"
areaButton.Parent = frame
Instance.new("UICorner", areaButton).CornerRadius = UDim.new(0,7)

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1,-16,0,34)
toggle.Position = UDim2.fromOffset(8,80)
toggle.BackgroundColor3 = Color3.fromRGB(45,45,45)
toggle.BorderSizePixel = 0
toggle.TextColor3 = Color3.fromRGB(225,225,225)
toggle.Font = Enum.Font.Gotham
toggle.TextSize = 12
toggle.Text = "auto complete index: off"
toggle.Parent = frame
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,7)

local areaList = Instance.new("ScrollingFrame")
areaList.Size = UDim2.new(1,-16,0,115)
areaList.Position = UDim2.fromOffset(8,118)
areaList.BackgroundColor3 = Color3.fromRGB(28,28,28)
areaList.BorderSizePixel = 0
areaList.Visible = false
areaList.ScrollBarThickness = 3
areaList.Parent = frame
Instance.new("UICorner", areaList).CornerRadius = UDim.new(0,7)
local layout = Instance.new("UIListLayout", areaList)
layout.Padding = UDim.new(0,3)

local function refreshAreaList()
    for _, child in ipairs(areaList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local areas = getAreaNames()
    for _, area in ipairs(areas) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1,-6,0,27)
        b.BackgroundColor3 = selectedAreas[area] and Color3.fromRGB(70,35,35) or Color3.fromRGB(40,40,40)
        b.BorderSizePixel = 0
        b.Text = area
        b.TextColor3 = Color3.fromRGB(230,230,230)
        b.Font = Enum.Font.Gotham
        b.TextSize = 11
        b.Parent = areaList
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
        b.Activated:Connect(function()
            if selectedAreas[area] then
                selectedAreas[area] = nil
            else
                selectedAreas[area] = true
            end
            refreshAreaList()
        end)
    end
    areaList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 6)
end

areaButton.Activated:Connect(function()
    areaList.Visible = not areaList.Visible
    frame.Size = areaList.Visible and UDim2.fromOffset(230,245) or UDim2.fromOffset(230,150)
    if areaList.Visible then refreshAreaList() end
end)

toggle.Activated:Connect(function()
    running = not running
    toggle.Text = running and "auto complete index: on" or "auto complete index: off"

    if running then
        task.spawn(function()
            while running do
                local egg = findBestEgg()
                if egg and egg.Parent and egg.Parent:IsA("BasePart") then
                    if moveTo(egg.Parent.Position, slowEggDistance) then
                        firePrompt(egg)
                        task.wait(0.8)
                        local plot = getPlotPosition()
                        if plot then moveTo(plot, slowPlotDistance) end
                    end
                else
                    task.wait(0.5)
                end
            end
            local _, humanoid = characterParts()
            if humanoid then humanoid.WalkSpeed = 16 end
        end)
    else
        local _, humanoid = characterParts()
        if humanoid then humanoid.WalkSpeed = 16 end
    end
end)

refreshAreaList()

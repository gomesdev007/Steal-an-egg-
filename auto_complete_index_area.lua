-- auto complete index only
-- target areas and egg records follow the same data path used by the source Egg ESP

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

local rarityOrder = {
    Common = 1, Rare = 2, Epic = 3, Legendary = 4,
    Mythic = 5, Divine = 6, Eternal = 7,
}

local function characterParts()
    local character = LocalPlayer.Character
    if not character then return nil, nil, nil end
    return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

local function getAreasData()
    local folder = ReplicatedStorage:FindFirstChild("Data")
    local module = folder and folder:FindFirstChild("Areas")
    if not module or not module:IsA("ModuleScript") then return nil end
    local ok, data = pcall(require, module)
    if not ok or type(data) ~= "table" then return nil end
    return data.Directory or data
end

-- Exact area list source used by the open-source hub.
local function getAreaNames()
    local result, seen = {}, {}
    areaKeys = {}
    local data = getAreasData()

    if type(data) == "table" then
        for key, info in pairs(data) do
            if type(key) == "string" and type(info) == "table" then
                local label = info.DisplayName or info.Name or key
                if type(label) == "string" and label ~= "" and not seen[label] then
                    seen[label] = true
                    result[#result + 1] = label
                    areaKeys[label] = key
                end
            end
        end
    end

    if #result == 0 then
        for _, containerName in ipairs({"Areas", "Islands"}) do
            local container = workspace:FindFirstChild(containerName)
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    if not seen[child.Name] then
                        seen[child.Name] = true
                        result[#result + 1] = child.Name
                        areaKeys[child.Name] = child.Name
                    end
                end
            end
        end
    end

    table.sort(result)
    return result
end

local function selectedCount()
    local n = 0
    for _ in pairs(selectedAreas) do n += 1 end
    return n
end

local function areaMatches(areaId)
    if selectedCount() == 0 then return true end
    if type(areaId) ~= "string" then return false end

    for label in pairs(selectedAreas) do
        local key = areaKeys[label] or label
        if areaId == label or areaId == key then
            return true
        end
    end
    return false
end

local function rarityValue(value)
    if type(value) == "table" then
        value = value.DisplayName or value._id or value.Name or value.Id
    end
    if type(value) ~= "string" then return 0 end
    for rarity, score in pairs(rarityOrder) do
        if string.lower(value):find(string.lower(rarity), 1, true) then
            return score
        end
    end
    return 0
end

-- Same live snapshot remote used by the source hub.
local function getLiveRecords()
    local rf = ReplicatedStorage:FindFirstChild("RF")
    local eggWorld = rf and rf:FindFirstChild("EggWorld")
    local remote = eggWorld and eggWorld:FindFirstChild("AskLiveSnapshot")
    if not remote or not remote:IsA("RemoteFunction") then return {} end

    local ok, snapshot = pcall(function()
        return remote:InvokeServer()
    end)
    if not ok or type(snapshot) ~= "table" then return {} end

    local output, seen = {}, {}

    local function addRecords(records)
        if type(records) ~= "table" then return end
        for uid, item in pairs(records) do
            if type(item) == "table" then
                local id = item.Uid or (type(uid) == "string" and uid or nil)
                if id and not seen[id] then
                    seen[id] = true
                    if item.Uid == nil then item.Uid = id end
                    output[#output + 1] = item
                end
            end
        end
    end

    -- The source handles both direct and nested Records snapshots.
    for _, item in pairs(snapshot) do
        if type(item) == "table" and type(item.Records) == "table" then
            addRecords(item.Records)
        end
    end
    if type(snapshot.Records) == "table" then
        addRecords(snapshot.Records)
    end
    if #output == 0 then
        addRecords(snapshot)
    end

    return output
end

local function recordPosition(record)
    local placement = record.Placement
    local value = placement and (placement.LocalCFrame or placement.CFrame or placement.WorldCFrame)
    if typeof(value) == "CFrame" then return value.Position end
    if typeof(value) == "Vector3" then return value end

    for _, key in ipairs({"BoundsCFrame", "BottomCFrame", "CFrame"}) do
        value = record[key]
        if typeof(value) == "CFrame" then return value.Position end
        if typeof(value) == "Vector3" then return value end
    end
    return nil
end

local function findEggModel(uid)
    local folder = workspace:FindFirstChild("AreaEggSlotsClient")
    if not folder then return nil end

    local direct = folder:FindFirstChild(tostring(uid))
    if direct then return direct end

    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then
            if child.Name == tostring(uid)
                or child:GetAttribute("Uid") == uid
                or child:GetAttribute("EggUid") == uid then
                return child
            end
        end
    end
    return nil
end

local function findPromptInModel(model)
    if not model then return nil end
    local fallback
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local action = string.lower(obj.ActionText or "")
            local object = string.lower(obj.ObjectText or "")
            if action:find("grab",1,true) or action:find("take",1,true)
                or action:find("pick",1,true) or action:find("carry",1,true)
                or action:find("steal",1,true) or object:find("egg",1,true) then
                return obj
            end
            fallback = fallback or obj
        end
    end
    return fallback
end

local function findBestEgg()
    local _, _, root = characterParts()
    if not root then return nil end

    local best, bestScore, bestDistance = nil, -1, math.huge
    for _, record in ipairs(getLiveRecords()) do
        local position = recordPosition(record)
        local areaId = record.AreaId
        if position and areaMatches(areaId) then
            local model = findEggModel(record.Uid)
            local prompt = findPromptInModel(model)
            if prompt and prompt.Parent then
                local distance = (position - root.Position).Magnitude
                local rarity = record.Rarity or record.RarityName or record.Tier or record.RarityId
                local score = rarityValue(rarity)
                if score > bestScore or (score == bestScore and distance < bestDistance) then
                    best = {
                        prompt = prompt,
                        position = position,
                        uid = record.Uid,
                        area = areaId,
                    }
                    bestScore = score
                    bestDistance = distance
                end
            end
        end
    end
    return best
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then return false end
    local ok = pcall(function()
        if typeof(fireproximityprompt) == "function" then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(math.max(prompt.HoldDuration, 0.05))
            prompt:InputHoldEnd()
        end
    end)
    return ok
end

local function getPlotPosition()
    -- First use the same visual plot lookup, then fall back to plot models.
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    for _, plot in ipairs(plots:GetChildren()) do
        local found = false
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local text = string.lower(obj.Text or "")
                if text:find(string.lower(LocalPlayer.Name), 1, true)
                    or text:find(string.lower(LocalPlayer.DisplayName), 1, true) then
                    found = true
                    break
                end
            end
        end

        if found then
            local ok, pivot = pcall(function() return plot:GetPivot() end)
            if ok then return pivot.Position end
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

        local target = Vector3.new(position.X, root.Position.Y, position.Z)
        local distance = (target - root.Position).Magnitude
        if distance <= 3 then
            humanoid:MoveTo(target)
            return true
        end

        humanoid.WalkSpeed = distance <= slowDistance and slowSpeed or normalSpeed
        humanoid:MoveTo(target)
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

-- Drag on PC + mobile.
local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
local function updateDrag(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos, dragInput = true, input.Position, frame.Position, input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then updateDrag(input) end
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

    for _, area in ipairs(getAreaNames()) do
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
            if selectedAreas[area] then selectedAreas[area] = nil else selectedAreas[area] = true end
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
                if egg then
                    if moveTo(egg.position, slowEggDistance) then
                        -- Refresh the prompt after arriving because the model can update while travelling.
                        local prompt = findPromptInModel(findEggModel(egg.uid)) or egg.prompt
                        firePrompt(prompt)
                        task.wait(0.8)

                        local plot = getPlotPosition()
                        if plot then
                            moveTo(plot, slowPlotDistance)
                        end
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

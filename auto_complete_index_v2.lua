-- auto complete index v2
-- selected area -> MoveTo egg -> autocomplete prompt -> MoveTo player plot -> delivery prompt -> repeat

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local NORMAL_SPEED = 100
local SLOW_SPEED = 50
local EGG_SLOW_DISTANCE = 40
local BASE_SLOW_DISTANCE = 30
local ARRIVE_DISTANCE = 4

local running = false
local cycleBusy = false
local selectedAreas = {}
local areaKeys = {}

local rarityOrder = {
    Common = 1,
    Rare = 2,
    Epic = 3,
    Legendary = 4,
    Mythic = 5,
    Divine = 6,
    Eternal = 7,
}

local function characterParts()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil, nil
    end
    return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

local function getAreasData()
    local data = ReplicatedStorage:FindFirstChild("Data")
    local module = data and data:FindFirstChild("Areas")
    if not module or not module:IsA("ModuleScript") then
        return nil
    end

    local ok, result = pcall(require, module)
    if not ok or type(result) ~= "table" then
        return nil
    end

    return result.Directory or result
end

local function getAreaNames()
    local result = {}
    local seen = {}
    areaKeys = {}

    local data = getAreasData()

    if type(data) == "table" then
        for key, info in pairs(data) do
            if type(key) == "string" then
                local label = key
                if type(info) == "table" then
                    label = info.DisplayName or info.Name or key
                end

                if type(label) == "string" and label ~= "" and not seen[label] then
                    seen[label] = true
                    areaKeys[label] = key
                    result[#result + 1] = label
                end
            end
        end
    end

    if #result == 0 then
        for _, folderName in ipairs({"Areas", "Islands"}) do
            local folder = workspace:FindFirstChild(folderName)
            if folder then
                for _, child in ipairs(folder:GetChildren()) do
                    if not seen[child.Name] then
                        seen[child.Name] = true
                        areaKeys[child.Name] = child.Name
                        result[#result + 1] = child.Name
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
    for _ in pairs(selectedAreas) do
        n += 1
    end
    return n
end

local function areaMatches(areaId)
    if selectedCount() == 0 or areaId == nil then
        return false
    end

    local id = tostring(areaId)
    local lowerId = string.lower(id)

    for label in pairs(selectedAreas) do
        local key = tostring(areaKeys[label] or label)
        if id == label or id == key then
            return true
        end
        if lowerId == string.lower(label) or lowerId == string.lower(key) then
            return true
        end
    end

    return false
end

local function rarityValue(value)
    if type(value) == "table" then
        value = value.DisplayName or value.Name or value.Id or value._id
    end
    if type(value) ~= "string" then
        return 0
    end

    local lower = string.lower(value)
    for rarity, score in pairs(rarityOrder) do
        if lower:find(string.lower(rarity), 1, true) then
            return score
        end
    end
    return 0
end

-- Same live egg remote used by the open source.
local function getLiveRecords()
    local rf = ReplicatedStorage:FindFirstChild("RF")
    local eggWorld = rf and rf:FindFirstChild("EggWorld")
    local remote = eggWorld and eggWorld:FindFirstChild("AskLiveSnapshot")

    if not remote or not remote:IsA("RemoteFunction") then
        return {}
    end

    local ok, snapshot = pcall(function()
        return remote:InvokeServer()
    end)

    if not ok or type(snapshot) ~= "table" then
        return {}
    end

    local output = {}
    local seen = {}

    local function addRecords(records)
        if type(records) ~= "table" then
            return
        end

        for uid, item in pairs(records) do
            if type(item) == "table" then
                local realUid = item.Uid or (type(uid) == "string" and uid or nil)
                if realUid and not seen[realUid] then
                    seen[realUid] = true
                    item.Uid = item.Uid or realUid
                    output[#output + 1] = item
                end
            end
        end
    end

    if type(snapshot.Records) == "table" then
        addRecords(snapshot.Records)
    end

    for _, item in pairs(snapshot) do
        if type(item) == "table" and type(item.Records) == "table" then
            addRecords(item.Records)
        end
    end

    if #output == 0 then
        addRecords(snapshot)
    end

    return output
end

local function recordPosition(record)
    if type(record) ~= "table" then
        return nil
    end

    local placement = record.Placement
    if type(placement) == "table" then
        for _, key in ipairs({"LocalCFrame", "CFrame", "WorldCFrame"}) do
            local value = placement[key]
            if typeof(value) == "CFrame" then
                return value.Position
            end
            if typeof(value) == "Vector3" then
                return value
            end
        end
    end

    for _, key in ipairs({"BoundsCFrame", "BottomCFrame", "CFrame"}) do
        local value = record[key]
        if typeof(value) == "CFrame" then
            return value.Position
        end
        if typeof(value) == "Vector3" then
            return value
        end
    end

    return nil
end

local function findEggModel(uid)
    local folder = workspace:FindFirstChild("AreaEggSlotsClient")
    if not folder then
        return nil
    end

    local direct = folder:FindFirstChild(tostring(uid))
    if direct then
        return direct
    end

    for _, child in ipairs(folder:GetChildren()) do
        local attrUid = child:GetAttribute("Uid") or child:GetAttribute("EggUid")
        if child.Name == tostring(uid) or tostring(attrUid) == tostring(uid) then
            return child
        end
    end

    return nil
end

local function promptPosition(prompt)
    local parent = prompt and prompt.Parent
    if not parent then
        return nil
    end

    if parent:IsA("BasePart") then
        return parent.Position
    end

    if parent:IsA("Attachment") and parent.Parent and parent.Parent:IsA("BasePart") then
        return parent.Parent.Position
    end

    local part = parent:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function promptText(prompt)
    return string.lower(
        tostring(prompt.Name) .. " " ..
        tostring(prompt.ActionText) .. " " ..
        tostring(prompt.ObjectText)
    )
end

local function isEggPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return false
    end

    local text = promptText(prompt)
    return text:find("grab", 1, true)
        or text:find("take", 1, true)
        or text:find("pick", 1, true)
        or text:find("carry", 1, true)
        or text:find("steal", 1, true)
        or text:find("egg", 1, true)
end

local function isDeliveryPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return false
    end

    local text = promptText(prompt)
    return text:find("place", 1, true)
        or text:find("plant", 1, true)
        or text:find("drop", 1, true)
        or text:find("put", 1, true)
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then
        return false
    end

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

local function nearestPrompt(position, mode, maxDistance)
    local best
    local bestDistance = maxDistance or math.huge

    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Enabled then
            local valid = mode == "egg" and isEggPrompt(descendant)
                or mode == "delivery" and isDeliveryPrompt(descendant)

            if valid then
                local p = promptPosition(descendant)
                if p then
                    local distance = (p - position).Magnitude
                    if distance <= bestDistance then
                        best = descendant
                        bestDistance = distance
                    end
                end
            end
        end
    end

    return best
end

local function findBestEgg()
    local _, _, root = characterParts()
    if not root then
        return nil
    end

    local best
    local bestRarity = -1
    local bestDistance = math.huge

    for _, record in ipairs(getLiveRecords()) do
        if record.State == nil or record.State == "Slot" then
            local position = recordPosition(record)
            local areaId = record.AreaId
            local uid = record.Uid

            if uid and position and areaMatches(areaId) then
                local model = findEggModel(uid)
                local prompt = model and nearestPrompt(position, "egg", 12)

                if prompt then
                    local rarity = rarityValue(
                        record.Rarity
                        or record.RarityName
                        or record.Tier
                        or record.RarityId
                    )
                    local distance = (position - root.Position).Magnitude

                    if rarity > bestRarity or (rarity == bestRarity and distance < bestDistance) then
                        best = {
                            uid = uid,
                            position = position,
                            prompt = prompt,
                            area = areaId,
                        }
                        bestRarity = rarity
                        bestDistance = distance
                    end
                end
            end
        end
    end

    return best
end

-- Exact plot ownership path from the open source: Homestead/AskState -> slot -> workspace.Plots.
local function getPlayerPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end

    local rf = ReplicatedStorage:FindFirstChild("RF")
    local homestead = rf and rf:FindFirstChild("Homestead")
    local remote = homestead and homestead:FindFirstChild("AskState")

    if remote and remote:IsA("RemoteFunction") then
        local ok, state = pcall(function()
            return remote:InvokeServer()
        end)

        if ok and type(state) == "table" then
            local owners = state.OwnersBySlot
                or state.SlotOwners
                or state.Owners
                or state.Slots

            if type(owners) == "table" then
                for slot, owner in pairs(owners) do
                    local ownerId = owner

                    if type(owner) == "table" then
                        ownerId = owner.UserId
                            or owner.OwnerUserId
                            or owner.Id
                            or owner.Name
                    end

                    if ownerId == LocalPlayer.UserId
                        or tostring(ownerId) == tostring(LocalPlayer.UserId)
                        or ownerId == LocalPlayer.Name then

                        return plots:FindFirstChild(tostring(slot))
                    end
                end
            end
        end
    end

    for _, plot in ipairs(plots:GetChildren()) do
        for _, descendant in ipairs(plot:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                local text = tostring(descendant.Text or "")
                if text:find(LocalPlayer.Name, 1, true) then
                    return plot
                end
            end
        end
    end

    return nil
end

local function getPlotPosition()
    local plot = getPlayerPlot()
    if not plot then
        return nil
    end

    local ok, pivot = pcall(function()
        return plot:GetPivot()
    end)

    return ok and pivot and pivot.Position or nil
end

-- The requested movement method: Humanoid:MoveTo(), repeatedly refreshed.
local function moveTo(position, slowDistance)
    local _, humanoid, root = characterParts()
    if not humanoid or not root then
        return false
    end

    while running do
        _, humanoid, root = characterParts()
        if not humanoid or not root or humanoid.Health <= 0 then
            return false
        end

        local target = Vector3.new(position.X, root.Position.Y, position.Z)
        local distance = (target - root.Position).Magnitude

        if distance <= ARRIVE_DISTANCE then
            humanoid:MoveTo(target)
            return true
        end

        humanoid.WalkSpeed = distance <= slowDistance and SLOW_SPEED or NORMAL_SPEED
        humanoid:MoveTo(target)
        task.wait(0.10)
    end

    return false
end

-- Autocomplete the egg prompt until the pickup is actually completed.
local function completeEgg(egg)
    local started = os.clock()

    while running and os.clock() - started < 8 do
        local _, _, root = characterParts()
        if not root then
            return false
        end

        local model = findEggModel(egg.uid)
        local prompt = model and nearestPrompt(egg.position, "egg", 10)
        prompt = prompt or nearestPrompt(root.Position, "egg", 10)

        if prompt then
            firePrompt(prompt)
        end

        local character = LocalPlayer.Character
        local tool = character and character:FindFirstChildWhichIsA("Tool")
        if tool then
            return true
        end

        if not findEggModel(egg.uid) then
            return true
        end

        task.wait(0.12)
    end

    return false
end

-- At the base, complete the existing place/drop/plant prompt.
local function completeDelivery()
    local started = os.clock()

    while running and os.clock() - started < 8 do
        local _, _, root = characterParts()
        if not root then
            return false
        end

        local prompt = nearestPrompt(root.Position, "delivery", 14)

        if prompt then
            firePrompt(prompt)
            task.wait(0.20)

            local character = LocalPlayer.Character
            local tool = character and character:FindFirstChildWhichIsA("Tool")
            if not tool then
                return true
            end
        else
            task.wait(0.15)
        end
    end

    return false
end

local function runCycle()
    if cycleBusy or not running then
        return
    end

    cycleBusy = true

    -- 1: selected area -> find egg.
    local egg = findBestEgg()

    if not egg then
        cycleBusy = false
        return
    end

    -- 2: MoveTo egg.
    if not moveTo(egg.position, EGG_SLOW_DISTANCE) then
        cycleBusy = false
        return
    end

    -- 3: autocomplete egg prompt.
    if not completeEgg(egg) then
        cycleBusy = false
        return
    end

    -- 4: completed -> find own base.
    local basePosition = getPlotPosition()
    if not basePosition then
        cycleBusy = false
        return
    end

    -- 5: MoveTo own base.
    if not moveTo(basePosition, BASE_SLOW_DISTANCE) then
        cycleBusy = false
        return
    end

    -- 6: delivery prompt.
    completeDelivery()

    -- 7: repeat.
    task.wait(0.15)
    cycleBusy = false
end

-- Remove old UI copies.
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
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

-- PC + mobile drag.
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
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

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
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        updateDrag(input)
    end
end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.Text = "auto complete index"
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

title.Active = false

local areaButton = Instance.new("TextButton")
areaButton.Size = UDim2.new(1, -16, 0, 34)
areaButton.Position = UDim2.fromOffset(8, 40)
areaButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
areaButton.BorderSizePixel = 0
areaButton.TextColor3 = Color3.fromRGB(225, 225, 225)
areaButton.Font = Enum.Font.Gotham
areaButton.TextSize = 12
areaButton.Text = "target egg areas"
areaButton.Parent = frame
Instance.new("UICorner", areaButton).CornerRadius = UDim.new(0, 7)

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -16, 0, 34)
toggle.Position = UDim2.fromOffset(8, 80)
toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
toggle.BorderSizePixel = 0
toggle.TextColor3 = Color3.fromRGB(225, 225, 225)
toggle.Font = Enum.Font.Gotham
toggle.TextSize = 12
toggle.Text = "auto complete index: off"
toggle.Parent = frame
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 7)

local areaList = Instance.new("ScrollingFrame")
areaList.Size = UDim2.new(1, -16, 0, 115)
areaList.Position = UDim2.fromOffset(8, 118)
areaList.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
areaList.BorderSizePixel = 0
areaList.Visible = false
areaList.ScrollBarThickness = 3
areaList.Parent = frame
Instance.new("UICorner", areaList).CornerRadius = UDim.new(0, 7)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.Parent = areaList

local function refreshAreaList()
    for _, child in ipairs(areaList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for _, area in ipairs(getAreaNames()) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -6, 0, 27)
        button.BackgroundColor3 = selectedAreas[area]
            and Color3.fromRGB(70, 35, 35)
            or Color3.fromRGB(40, 40, 40)
        button.BorderSizePixel = 0
        button.Text = area
        button.TextColor3 = Color3.fromRGB(230, 230, 230)
        button.Font = Enum.Font.Gotham
        button.TextSize = 11
        button.Parent = areaList
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

        button.Activated:Connect(function()
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

    if areaList.Visible then
        refreshAreaList()
        frame.Size = UDim2.fromOffset(230, 245)
    else
        frame.Size = UDim2.fromOffset(230, 150)
    end
end)

toggle.Activated:Connect(function()
    running = not running
    toggle.Text = running
        and "auto complete index: on"
        or "auto complete index: off"

    if running then
        task.spawn(function()
            while running do
                if selectedCount() > 0 then
                    runCycle()
                else
                    task.wait(0.5)
                end
                task.wait(0.10)
            end

            local _, humanoid = characterParts()
            if humanoid then
                humanoid.WalkSpeed = 16
            end
        end)
    else
        local _, humanoid = characterParts()
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end)

refreshAreaList()

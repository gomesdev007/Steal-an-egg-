-- auto complete index v3
-- Uses the same field-egg structure as the open-source Egg ESP:
-- EggSnapshot -> Records -> State/Uid -> AreaId -> AreaEggSlotsClient -> position.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local RUNNING = false
local NORMAL_SPEED = 100
local SLOW_SPEED = 50
local EGG_SLOW_DISTANCE = 40
local BASE_SLOW_DISTANCE = 30

local selectedAreas = {}
local areaOrder = {}
local areaSet = {}

local function characterParts()
    local character = LocalPlayer.Character
    if not character then return nil, nil, nil end
    return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

local function remote(path)
    local node = ReplicatedStorage
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

local function invoke(path)
    local r = remote(path)
    if not r or not r:IsA("RemoteFunction") then return nil end
    local ok, result = pcall(function() return r:InvokeServer() end)
    return ok and result or nil
end

-- Same EggSnapshot source used by the open-source ESP.
local function readEggSnapshot()
    local snapshot = invoke({"RF", "EggWorld", "AskFieldEggSnapshot"})
    if type(snapshot) ~= "table" then return {} end
    return type(snapshot.Records) == "table" and snapshot.Records or {}
end

local function getEggRecords()
    local records = readEggSnapshot()
    local result = {}

    for uid, egg in pairs(records) do
        if type(egg) == "table" and egg.State == "Slot" then
            local id = egg.Uid or (type(uid) == "string" and uid or nil)
            if id then
                egg.Uid = id
                result[#result + 1] = egg
            end
        end
    end

    return result
end

-- The ESP gets the actual egg hitbox from AreaEggSlotsClient using the UID.
local function getEggModel(uid)
    local folder = workspace:FindFirstChild("AreaEggSlotsClient")
    if not folder then return nil end

    local direct = folder:FindFirstChild(tostring(uid))
    if direct then return direct end

    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == tostring(uid)
            or child:GetAttribute("Uid") == uid
            or child:GetAttribute("EggUid") == uid then
            return child
        end
    end

    return nil
end

local function getEggPosition(uid, record)
    local model = getEggModel(uid)
    if model then
        local part = model.PrimaryPart
            or model:FindFirstChild("Hitbox")
            or model:FindFirstChildWhichIsA("BasePart", true)
        if part and part:IsA("BasePart") then
            return part.Position, model
        end

        local ok, pivot = pcall(function() return model:GetPivot() end)
        if ok and pivot then
            return pivot.Position, model
        end
    end

    local bounds = record.BoundsCFrame or record.BottomCFrame
    if typeof(bounds) == "CFrame" then
        return bounds.Position, model
    end
    if typeof(bounds) == "Vector3" then
        return bounds, model
    end

    local placement = record.Placement
    if type(placement) == "table" then
        local cf = placement.LocalCFrame or placement.CFrame or placement.WorldCFrame
        if typeof(cf) == "CFrame" then return cf.Position, model end
        if typeof(cf) == "Vector3" then return cf, model end
    end

    return nil, model
end

-- If the original ESP is running, use its generated Highlight/UID as an extra
-- validation layer. The authoritative egg data still comes from EggSnapshot.
local function hasEspHighlight(uid)
    local roots = {}
    local ok, hui = pcall(function()
        return gethui and gethui() or nil
    end)
    if ok and hui then roots[#roots + 1] = hui end
    roots[#roots + 1] = game:GetService("CoreGui")

    for _, root in ipairs(roots) do
        local esp = root:FindFirstChild("ThanhDuyEggESP")
        if esp then
            local tag = esp:FindFirstChild(tostring(uid))
            if tag and tag:FindFirstChildWhichIsA("Highlight", true) then
                return true
            end
        end
    end

    return false
end

local function rebuildAreas(records)
    local found = {}
    for _, egg in ipairs(records) do
        if egg.AreaId then
            local name = tostring(egg.AreaId)
            if not found[name] then
                found[name] = true
            end
        end
    end

    areaOrder = {}
    for name in pairs(found) do
        areaOrder[#areaOrder + 1] = name
    end
    table.sort(areaOrder)

    areaSet = {}
    for _, name in ipairs(areaOrder) do
        areaSet[name] = true
    end

    -- Remove selections that no longer exist in the current ESP/egg data.
    for name in pairs(selectedAreas) do
        if not areaSet[name] then
            selectedAreas[name] = nil
        end
    end
end

local function areaSelected(area)
    if next(selectedAreas) == nil then return false end
    return selectedAreas[tostring(area)] == true
end

local function findPromptNearEgg(model, position)
    local best = nil
    local bestDistance = math.huge

    if model then
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local parent = obj.Parent
                local p
                if parent and parent:IsA("BasePart") then
                    p = parent.Position
                elseif parent and parent:IsA("Attachment") then
                    p = parent.WorldPosition
                end
                local distance = p and (p - position).Magnitude or 0
                if distance < bestDistance then
                    best = obj
                    bestDistance = distance
                end
            end
        end
    end

    -- Same keyword idea as the open-source prompt handler.
    if best then return best end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") and (parent.Position - position).Magnitude <= 8 then
                local a = string.lower(obj.ActionText or "")
                local o = string.lower(obj.ObjectText or "")
                if a:find("grab",1,true) or a:find("take",1,true)
                    or a:find("pick",1,true) or a:find("carry",1,true)
                    or a:find("steal",1,true) or o:find("egg",1,true) then
                    return obj
                end
            end
        end
    end

    return nil
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then return false end

    if typeof(fireproximityprompt) == "function" then
        return pcall(function() fireproximityprompt(prompt) end)
    end

    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(prompt.HoldDuration, 0.05))
        prompt:InputHoldEnd()
    end)
    return ok
end

local function getOwnPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    -- Exact first method from the source: PlotState -> OwnersBySlot/SotOwners/etc.
    local state = invoke({"RF", "Homestead", "AskState"})
    if type(state) == "table" then
        local owners = state.OwnersBySlot or state.SlotOwners or state.Owners or state.Slots
        if type(owners) == "table" then
            for slot, owner in pairs(owners) do
                local id = owner
                if type(owner) == "table" then
                    id = owner.UserId or owner.OwnerUserId or owner.Id or owner.Name
                end
                if id == LocalPlayer.UserId or id == tostring(LocalPlayer.UserId) or id == LocalPlayer.Name then
                    local plot = plots:FindFirstChild(tostring(slot))
                    if plot then return plot end
                end
            end
        end
    end

    -- Same fallback used by the source: find the player's name in the plot.
    for _, plot in ipairs(plots:GetChildren()) do
        for _, d in ipairs(plot:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local text = string.lower(d.Text or "")
                if text:find(string.lower(LocalPlayer.Name),1,true)
                    or text:find(string.lower(LocalPlayer.DisplayName),1,true) then
                    return plot
                end
            end
        end
    end

    return nil
end

local function plotPosition(plot)
    if not plot then return nil end

    local primary = plot.PrimaryPart
    if primary then return primary.Position end

    for _, name in ipairs({"Base", "Plate", "Pad", "Floor", "Ground", "Origin"}) do
        local part = plot:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then return part.Position end
    end

    local ok, pivot = pcall(function() return plot:GetPivot() end)
    return ok and pivot.Position or nil
end

local function moveTo(target, slowDistance)
    local _, humanoid, root = characterParts()
    if not humanoid or not root then return false end

    while RUNNING do
        _, humanoid, root = characterParts()
        if not humanoid or not root then return false end

        local goal = Vector3.new(target.X, root.Position.Y, target.Z)
        local distance = (goal - root.Position).Magnitude

        if distance <= 3 then
            humanoid:MoveTo(goal)
            return true
        end

        humanoid.WalkSpeed = distance <= slowDistance and SLOW_SPEED or NORMAL_SPEED
        humanoid:MoveTo(goal)
        task.wait(0.08)
    end

    return false
end

local function eggWasRemoved(uid)
    local model = getEggModel(uid)
    if not model then return true end
    return false
end

local function findTargetEgg()
    local _, _, root = characterParts()
    if not root then return nil end

    local records = getEggRecords()
    rebuildAreas(records)

    local best = nil
    local bestDistance = math.huge

    for _, egg in ipairs(records) do
        if areaSelected(egg.AreaId) then
            local position, model = getEggPosition(egg.Uid, egg)
            if position then
                -- Prefer an egg actually represented by the ESP when it exists.
                -- If ESP is not currently enabled, the same underlying records/model path works.
                local highlighted = hasEspHighlight(egg.Uid)
                local prompt = findPromptNearEgg(model, position)

                if prompt or highlighted then
                    local distance = (position - root.Position).Magnitude
                    if distance < bestDistance then
                        bestDistance = distance
                        best = {
                            uid = egg.Uid,
                            area = tostring(egg.AreaId),
                            position = position,
                            model = model,
                            prompt = prompt,
                        }
                    end
                end
            end
        end
    end

    return best
end

local function completeDelivery(plot)
    local position = plotPosition(plot)
    if not position then return false end
    if not moveTo(position, BASE_SLOW_DISTANCE) then return false end

    -- Let the game finish the carried-egg state first, then use the same
    -- broad prompt scan used by the source for place/open actions.
    for _ = 1, 12 do
        local _, _, root = characterParts()
        if not root then return false end

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local parent = obj.Parent
                if parent and parent:IsA("BasePart") and (parent.Position - root.Position).Magnitude <= 12 then
                    local a = string.lower(obj.ActionText or "")
                    local o = string.lower(obj.ObjectText or "")
                    if a:find("place",1,true) or a:find("drop",1,true)
                        or a:find("plant",1,true) or a:find("open",1,true)
                        or o:find("egg",1,true) then
                        firePrompt(obj)
                        task.wait(0.25)
                        return true
                    end
                end
            end
        end
        task.wait(0.08)
    end

    return false
end

local old = PlayerGui:FindFirstChild("AutoCompleteIndexGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoCompleteIndexGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(240, 150)
frame.Position = UDim2.new(0, 12, 0.5, -75)
frame.BackgroundColor3 = Color3.fromRGB(22,22,22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-16,0,28)
title.Position = UDim2.fromOffset(8,6)
title.BackgroundTransparency = 1
title.Text = "auto complete index"
title.TextColor3 = Color3.fromRGB(240,240,240)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = false
title.Parent = frame

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
areaList.Size = UDim2.new(1,-16,0,150)
areaList.Position = UDim2.fromOffset(8,118)
areaList.BackgroundColor3 = Color3.fromRGB(28,28,28)
areaList.BorderSizePixel = 0
areaList.Visible = false
areaList.ScrollBarThickness = 3
areaList.CanvasSize = UDim2.fromOffset(0,0)
areaList.Parent = frame
Instance.new("UICorner", areaList).CornerRadius = UDim.new(0,7)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0,3)
layout.Parent = areaList

local function refreshAreaList()
    for _, child in ipairs(areaList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    -- Refresh directly from the same egg data that creates the ESP.
    local records = getEggRecords()
    rebuildAreas(records)

    for _, area in ipairs(areaOrder) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1,-6,0,28)
        button.BackgroundColor3 = selectedAreas[area] and Color3.fromRGB(75,35,35) or Color3.fromRGB(40,40,40)
        button.BorderSizePixel = 0
        button.Text = area
        button.TextColor3 = Color3.fromRGB(230,230,230)
        button.Font = Enum.Font.Gotham
        button.TextSize = 11
        button.Parent = areaList
        Instance.new("UICorner", button).CornerRadius = UDim.new(0,6)

        button.Activated:Connect(function()
            selectedAreas[area] = not selectedAreas[area] and true or nil
            refreshAreaList()
        end)
    end

    areaList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 6)
end

areaButton.Activated:Connect(function()
    areaList.Visible = not areaList.Visible
    frame.Size = areaList.Visible and UDim2.fromOffset(240, 285) or UDim2.fromOffset(240, 150)
    if areaList.Visible then refreshAreaList() end
end)

-- PC + mobile drag.
local dragging = false
local dragStart
local startPos
local dragInput

local function updateDrag(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
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

local function runCycle()
    task.spawn(function()
        while RUNNING do
            local target = findTargetEgg()

            if not target then
                task.wait(0.35)
                continue
            end

            -- 1) Go exactly to the ESP egg position with MoveTo.
            if not moveTo(target.position, EGG_SLOW_DISTANCE) then break end

            -- Re-read the model/prompt after arriving because the egg can update.
            local currentPosition, currentModel = getEggPosition(target.uid, {
                BoundsCFrame = nil,
                BottomCFrame = nil,
            })
            currentPosition = currentPosition or target.position
            local prompt = findPromptNearEgg(currentModel, currentPosition) or target.prompt

            -- 2) Complete the egg prompt.
            local completed = firePrompt(prompt)
            if not completed then
                task.wait(0.25)
                continue
            end

            -- 3) Wait for the egg to become carried before returning.
            task.wait(0.25)
            local plot = getOwnPlot()
            if plot then
                -- 4) MoveTo the player's own base, slowing at 30 studs.
                completeDelivery(plot)
            end

            -- 5) New snapshot -> new highlighted/available egg -> repeat.
            task.wait(0.15)
        end

        local _, humanoid = characterParts()
        if humanoid then humanoid.WalkSpeed = 16 end
    end)
end

toggle.Activated:Connect(function()
    RUNNING = not RUNNING
    toggle.Text = RUNNING and "auto complete index: on" or "auto complete index: off"

    if RUNNING then
        runCycle()
    else
        local _, humanoid = characterParts()
        if humanoid then humanoid.WalkSpeed = 16 end
    end
end)

refreshAreaList()

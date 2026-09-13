-- Egg ESP + Auto Steal + Go To My Plot + Target Egg Areas
-- Preserves the original stable version from commit 8086666efb5415867b274177b76259c389cceef0

local ORIGINAL_URL = "https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/8086666efb5415867b274177b76259c389cceef0/egg_esp_auto_steal_extracted.lua"

local ok, err = pcall(function()
    loadstring(game:HttpGet(ORIGINAL_URL))()
end)

if not ok then
    warn("Failed to load original script:", err)
    return
end

task.spawn(function()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer

    local function getMyPlot()
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return nil end

        local okState, state = pcall(function()
            local rf = ReplicatedStorage:FindFirstChild("RF")
            local homestead = rf and rf:FindFirstChild("Homestead")
            local askState = homestead and homestead:FindFirstChild("AskState")
            if askState and askState:IsA("RemoteFunction") then
                return askState:InvokeServer()
            end
        end)

        if okState and type(state) == "table" then
            local ownerTables = {state.OwnersBySlot, state.SlotOwners, state.Owners, state.Slots}
            for _, owners in ipairs(ownerTables) do
                if type(owners) == "table" then
                    for slot, owner in pairs(owners) do
                        local matches = false
                        if type(owner) == "number" then
                            matches = owner == LocalPlayer.UserId
                        elseif type(owner) == "string" then
                            matches = owner == tostring(LocalPlayer.UserId) or owner == LocalPlayer.Name
                        elseif type(owner) == "table" then
                            matches = owner.UserId == LocalPlayer.UserId or owner.Name == LocalPlayer.Name
                        end
                        if matches then
                            local candidate = plots:FindFirstChild(tostring(slot))
                            if candidate then return candidate end
                        end
                    end
                end
            end
        end

        for _, plot in ipairs(plots:GetChildren()) do
            for _, obj in ipairs(plot:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local text = string.lower(obj.Text or "")
                    if text:find(string.lower(LocalPlayer.Name), 1, true) or
                       (LocalPlayer.DisplayName ~= LocalPlayer.Name and text:find(string.lower(LocalPlayer.DisplayName), 1, true)) then
                        return plot
                    end
                end
            end
        end
        return nil
    end

    local function getPlotPosition(plot)
        if not plot then return nil end
        if plot:IsA("BasePart") then return plot.Position end
        if plot:IsA("Model") then
            if plot.PrimaryPart then return plot.PrimaryPart.Position end
            local okPivot, pivot = pcall(function() return plot:GetPivot() end)
            if okPivot and pivot then return pivot.Position end
        end
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("BasePart") then return obj.Position end
        end
        return nil
    end

    local function goToMyPlot()
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local plot = getMyPlot()
        if not plot then warn("MY PLOT NOT FOUND") return end
        local position = getPlotPosition(plot)
        if not position then warn("MY PLOT POSITION NOT FOUND") return end
        humanoid:MoveTo(position)
    end

    -- Finds the game's area names without hardcoding them.
    local function getAreaNames()
        local names = {}
        local seen = {}
        local roots = {
            workspace:FindFirstChild("Areas"),
            workspace:FindFirstChild("Islands"),
            workspace:FindFirstChild("__OBJECTS"),
            ReplicatedStorage:FindFirstChild("Data")
        }

        for _, root in ipairs(roots) do
            if root then
                for _, obj in ipairs(root:GetDescendants()) do
                    if obj:IsA("Folder") or obj:IsA("Model") then
                        local n = obj.Name
                        local lower = string.lower(n)
                        if not seen[lower] and #n > 1 and #n < 40 then
                            if lower:find("area", 1, true) or lower:find("island", 1, true) then
                                seen[lower] = true
                                table.insert(names, n)
                            end
                        end
                    end
                end
            end
        end

        table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
        return names
    end

    local selectedAreas = {}

    local gui = Instance.new("ScreenGui")
    gui.Name = "GoToMyPlotGui"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local holder = Instance.new("Frame")
    holder.Name = "TargetAreaHolder"
    holder.Size = UDim2.fromOffset(180, 38)
    holder.Position = UDim2.new(0, 12, 0.5, 0)
    holder.BackgroundTransparency = 1
    holder.Parent = gui

    local button = Instance.new("TextButton")
    button.Name = "GoToMyPlot"
    button.Size = UDim2.fromOffset(150, 38)
    button.Position = UDim2.fromOffset(0, 0)
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.Text = "go to my plot"
    button.TextSize = 14
    button.Font = Enum.Font.Gotham
    button.BorderSizePixel = 0
    button.Parent = holder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    button.Activated:Connect(goToMyPlot)

    local areaButton = Instance.new("TextButton")
    areaButton.Name = "TargetEggAreas"
    areaButton.Size = UDim2.fromOffset(180, 34)
    areaButton.Position = UDim2.fromOffset(0, 44)
    areaButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    areaButton.TextColor3 = Color3.fromRGB(235, 235, 235)
    areaButton.Text = "target egg areas"
    areaButton.TextSize = 13
    areaButton.Font = Enum.Font.Gotham
    areaButton.BorderSizePixel = 0
    areaButton.Parent = holder

    local areaCorner = Instance.new("UICorner")
    areaCorner.CornerRadius = UDim.new(0, 8)
    areaCorner.Parent = areaButton

    local list = Instance.new("ScrollingFrame")
    list.Name = "AreaList"
    list.Size = UDim2.fromOffset(180, 170)
    list.Position = UDim2.fromOffset(0, 82)
    list.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.Visible = false
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.Parent = holder

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 8)
    listCorner.Parent = list

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = list

    local function updateAreaTitle()
        local count = 0
        for _ in pairs(selectedAreas) do count += 1 end
        if count == 0 then
            areaButton.Text = "target egg areas: all"
        else
            areaButton.Text = "target egg areas: " .. tostring(count)
        end
    end

    local function rebuildAreaList()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        local areas = getAreaNames()
        for _, area in ipairs(areas) do
            local key = string.lower(area)
            local option = Instance.new("TextButton")
            option.Size = UDim2.new(1, -8, 0, 28)
            option.BackgroundColor3 = selectedAreas[key] and Color3.fromRGB(55, 55, 55) or Color3.fromRGB(30, 30, 30)
            option.TextColor3 = Color3.fromRGB(235, 235, 235)
            option.Text = area
            option.TextSize = 12
            option.Font = Enum.Font.Gotham
            option.BorderSizePixel = 0
            option.Parent = list

            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 6)
            c.Parent = option

            option.Activated:Connect(function()
                if selectedAreas[key] then
                    selectedAreas[key] = nil
                else
                    selectedAreas[key] = area
                end
                updateAreaTitle()
                rebuildAreaList()
            end)
        end

        list.CanvasSize = UDim2.fromOffset(0, math.max(170, #areas * 31))
        updateAreaTitle()
    end

    areaButton.Activated:Connect(function()
        list.Visible = not list.Visible
        if list.Visible then rebuildAreaList() end
    end)

    updateAreaTitle()
end)
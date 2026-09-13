-- test_move_to_forest_eggs.lua
-- Teste simples: usa a mesma fonte de dados do Egg ESP do open source
-- e leva o jogador, somente com Humanoid:MoveTo(), até os eggs da Forest.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function getCharacter()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, root
end

local function getNetworking()
    local packages = game:FindFirstChild("Packages")
    if not packages then
        return nil
    end

    local networking = packages:FindFirstChild("Networking")
    return networking
end

local function getEggSnapshot()
    local networking = getNetworking()
    if not networking then
        return nil
    end

    local remote = networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
    if not remote or not remote:IsA("RemoteFunction") then
        return nil
    end

    local ok, result = pcall(function()
        return remote:InvokeServer()
    end)

    if ok and type(result) == "table" then
        return result
    end

    return nil
end

local function getEggSlots()
    return workspace:FindFirstChild("AreaEggSlotsClient")
end

-- Mesma ideia do value46/value47 do open source:
-- AreaEggSlotsClient -> UID -> PrimaryPart/Hitbox/BasePart.
local function getEggPart(uid)
    local slots = getEggSlots()
    if not slots or not uid then
        return nil
    end

    local egg = slots:FindFirstChild(tostring(uid))
    if not egg then
        return nil
    end

    if egg:IsA("BasePart") then
        return egg
    end

    if egg:IsA("Model") then
        return egg.PrimaryPart
            or egg:FindFirstChild("Hitbox")
            or egg:FindFirstChildWhichIsA("BasePart")
    end

    return egg:FindFirstChild("Hitbox")
        or egg:FindFirstChildWhichIsA("BasePart")
end

local function getEggPosition(record)
    local uid = record.Uid
    local part = getEggPart(uid)

    if part then
        return part.Position
    end

    local cframe = record.BoundsCFrame or record.BottomCFrame
    if typeof(cframe) == "CFrame" then
        return cframe.Position
    end

    return nil
end

local function isForest(record)
    local area = tostring(record.AreaId or "")
    local rarity = tostring(record.RarityName or record.Rarity or record.Tier or "")

    return area:lower():find("forest", 1, true) ~= nil
        or rarity:lower():find("forest", 1, true) ~= nil
end

local function getForestEggs()
    local snapshot = getEggSnapshot()
    local records = snapshot and snapshot.Records

    if type(records) ~= "table" then
        return {}, "snapshot sem Records"
    end

    local eggs = {}

    for _, record in pairs(records) do
        if type(record) == "table" and record.State == "Slot" and record.Uid and isForest(record) then
            local position = getEggPosition(record)

            if position then
                eggs[#eggs + 1] = {
                    uid = record.Uid,
                    position = position,
                    area = tostring(record.AreaId or "unknown")
                }
            end
        end
    end

    return eggs
end

local function createGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TestMoveToForestEggs"
    gui.ResetOnSpawn = false
    gui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(190, 64)
    frame.Position = UDim2.new(0.5, -95, 0.5, -32)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -12, 1, -12)
    button.Position = UDim2.fromOffset(6, 6)
    button.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    button.BorderSizePixel = 0
    button.Text = "move to forest eggs"
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.TextSize = 14
    button.Font = Enum.Font.GothamMedium
    button.Parent = frame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = button

    return gui, button
end

local gui, button = createGui()
local running = false

local function moveToPosition(humanoid, root, position)
    local oldSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 100

    humanoid:MoveTo(position)

    local started = os.clock()
    while running and humanoid.Parent and root.Parent do
        local distance = (root.Position - position).Magnitude
        if distance <= 5 then
            break
        end

        -- MoveTo precisa ser renovado porque possui timeout interno.
        humanoid:MoveTo(position)

        if os.clock() - started > 60 then
            break
        end

        task.wait(0.15)
    end

    humanoid:MoveTo(root.Position)
    humanoid.WalkSpeed = oldSpeed
end

button.MouseButton1Click:Connect(function()
    if running then
        running = false
        button.Text = "move to forest eggs"
        return
    end

    running = true
    button.Text = "searching forest..."

    local character, humanoid, root = getCharacter()
    if not humanoid or not root then
        running = false
        button.Text = "character not found"
        task.wait(1.5)
        button.Text = "move to forest eggs"
        return
    end

    local eggs, errorMessage = getForestEggs()

    if #eggs == 0 then
        running = false
        button.Text = errorMessage or "no forest eggs"
        task.wait(2)
        button.Text = "move to forest eggs"
        return
    end

    -- Ordena pelo egg mais próximo para o teste começar pelo alvo mais fácil.
    table.sort(eggs, function(a, b)
        return (root.Position - a.position).Magnitude < (root.Position - b.position).Magnitude
    end)

    for index, egg in ipairs(eggs) do
        if not running then
            break
        end

        button.Text = "moving " .. index .. "/" .. #eggs
        moveToPosition(humanoid, root, egg.position)
        task.wait(0.25)
    end

    running = false
    button.Text = "test finished"
    task.wait(1.5)
    button.Text = "move to forest eggs"
end)

print("[Forest MoveTo Test] carregado")
print("[Forest MoveTo Test] botão: move to forest eggs")

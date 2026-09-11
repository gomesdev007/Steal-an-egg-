-- GUI Dark Arrastável para Steal an Egg
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Criar ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealEggGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Criar Frame principal (Dark)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 150)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Adicionar UICorner para bordas arredondadas
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Titulo
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "🥚 Steal an Egg"
titleLabel.BorderSizePixel = 0
titleLabel.Parent = mainFrame

-- Adicionar corner ao título
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleLabel

-- Botão Instant Pickup
local instantPickupButton = Instance.new("TextButton")
instantPickupButton.Name = "InstantPickup"
instantPickupButton.Size = UDim2.new(0.5, -5, 0, 45)
instantPickupButton.Position = UDim2.new(0, 5, 0, 45)
instantPickupButton.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
instantPickupButton.TextColor3 = Color3.fromRGB(255, 255, 255)
instantPickupButton.TextSize = 13
instantPickupButton.Font = Enum.Font.GothamSemibold
instantPickupButton.Text = "⚡ Instant Pickup"
instantPickupButton.BorderSizePixel = 0
instantPickupButton.Parent = mainFrame

local buttonCorner1 = Instance.new("UICorner")
buttonCorner1.CornerRadius = UDim.new(0, 6)
buttonCorner1.Parent = instantPickupButton

-- Botão Anti Ragdoll
local antiRagdollButton = Instance.new("TextButton")
antiRagdollButton.Name = "AntiRagdoll"
antiRagdollButton.Size = UDim2.new(0.5, -5, 0, 45)
antiRagdollButton.Position = UDim2.new(0.5, 5, 0, 45)
antiRagdollButton.BackgroundColor3 = Color3.fromRGB(200, 100, 40)
antiRagdollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
antiRagdollButton.TextSize = 13
antiRagdollButton.Font = Enum.Font.GothamSemibold
antiRagdollButton.Text = "🛡️ Anti Ragdoll"
antiRagdollButton.BorderSizePixel = 0
antiRagdollButton.Parent = mainFrame

local buttonCorner2 = Instance.new("UICorner")
buttonCorner2.CornerRadius = UDim.new(0, 6)
buttonCorner2.Parent = antiRagdollButton

-- Variáveis de arraste
local dragging = false
local dragInput
local dragStart
local startPos

-- Função para iniciar arraste
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mouse = player:GetMouse()
		local mousePos = Vector2.new(mouse.X, mouse.Y)
		
		-- Verificar se clicou no título
		if mousePos.Y >= mainFrame.AbsolutePosition.Y and 
		   mousePos.Y <= mainFrame.AbsolutePosition.Y + titleLabel.AbsoluteSize.Y and
		   mousePos.X >= mainFrame.AbsolutePosition.X and
		   mousePos.X <= mainFrame.AbsolutePosition.X + mainFrame.AbsoluteSize.X then
			dragging = true
			dragStart = mousePos
			startPos = mainFrame.Position
		end
	end
end

-- Função para arrastar
local function onInputChanged(input, gameProcessed)
	if not dragging then return end
	
	local mouse = player:GetMouse()
	local mousePos = Vector2.new(mouse.X, mouse.Y)
	local delta = mousePos - dragStart
	
	mainFrame.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
end

-- Função para parar arraste
local function onInputEnded(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end

-- Conectar eventos de input
UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputChanged:Connect(onInputChanged)
UserInputService.InputEnded:Connect(onInputEnded)

-- Efeito ao passar mouse sobre os botões
local function createHoverEffect(button)
	local originalColor = button.BackgroundColor3
	
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Color3.new(
			math.min(originalColor.R + 0.1, 1),
			math.min(originalColor.G + 0.1, 1),
			math.min(originalColor.B + 0.1, 1)
		)
	end)
	
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = originalColor
	end)
end

createHoverEffect(instantPickupButton)
createHoverEffect(antiRagdollButton)

-- Função Instant Pickup
instantPickupButton.MouseButton1Click:Connect(function()
	instantPickupButton.Text = "⏳ Carregando..."
	instantPickupButton.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
	
	local success, err = pcall(function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Lutosys/opensrc/refs/heads/main/stealanegginstantinteract.lua"))()
	end)
	
	if success then
		instantPickupButton.Text = "✅ Ativado!"
		instantPickupButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		wait(2)
		instantPickupButton.Text = "⚡ Instant Pickup"
		instantPickupButton.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
	else
		instantPickupButton.Text = "❌ Erro!"
		instantPickupButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		warn("Erro ao carregar Instant Pickup: " .. tostring(err))
		wait(2)
		instantPickupButton.Text = "⚡ Instant Pickup"
		instantPickupButton.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
	end
end)

-- Função Anti Ragdoll
antiRagdollButton.MouseButton1Click:Connect(function()
	antiRagdollButton.Text = "⏳ Carregando..."
	antiRagdollButton.BackgroundColor3 = Color3.fromRGB(220, 150, 100)
	
	local success, err = pcall(function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Lutosys/opensrc/refs/heads/main/stealaeggnoknockback.lua"))()
	end)
	
	if success then
		antiRagdollButton.Text = "✅ Ativado!"
		antiRagdollButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		wait(2)
		antiRagdollButton.Text = "🛡️ Anti Ragdoll"
		antiRagdollButton.BackgroundColor3 = Color3.fromRGB(200, 100, 40)
	else
		antiRagdollButton.Text = "❌ Erro!"
		antiRagdollButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		warn("Erro ao carregar Anti Ragdoll: " .. tostring(err))
		wait(2)
		antiRagdollButton.Text = "🛡️ Anti Ragdoll"
		antiRagdollButton.BackgroundColor3 = Color3.fromRGB(200, 100, 40)
	end
end)

print("✅ GUI Steal an Egg carregada com sucesso!")

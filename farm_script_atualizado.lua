--// MONSTER PARASITE EGG ESP + FARM AUTO
--// Detecta: Workspace.AreaEggSlotsClient.<ID>.MonsterParasiteVisual

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local AreaEggSlotsClient = workspace:WaitForChild("AreaEggSlotsClient")

local ESP_FOLDER_NAME = "MonsterParasiteESP"
local farmActive = false
local currentTarget = nil

--// Pasta para organizar os ESPs
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = ESP_FOLDER_NAME
ESPFolder.Parent = AreaEggSlotsClient

local ESPs = {}

-- ============ POSIÇÕES DE FARM ============
local FARM_POSITIONS = {
	Vector3.new(496.76, 70.57, -351.23),
	Vector3.new(537.09, 70.57, -410.15)
}

-- ============ FUNÇÕES ESP (ORIGINAL) ============

local function getTargetPart(egg)
	local visual = egg:FindFirstChild("MonsterParasiteVisual")
	
	if visual then
		local root = visual:FindFirstChild("RootPart", true)
		
		if root and root:IsA("BasePart") then
			return root
		end
	end
	
	local part = egg:FindFirstChildWhichIsA("BasePart", true)
	return part
end

local function removeESP(egg)
	local gui = ESPs[egg]
	
	if gui then
		gui:Destroy()
		ESPs[egg] = nil
	end
end

local function createESP(egg)
	if ESPs[egg] then
		return
	end
	
	local visual = egg:FindFirstChild("MonsterParasiteVisual")
	
	if not visual then
		return
	end
	
	local target = getTargetPart(egg)
	
	if not target then
		return
	end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MonsterParasiteESP"
	billboard.Adornee = target
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(190, 55)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.MaxDistance = 10000
	billboard.Parent = ESPFolder
	
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "✨ MONSTER PARASITE"
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(190, 80, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	
	ESPs[egg] = billboard
	
	task.spawn(function()
		while ESPs[egg] == billboard and egg.Parent do
			local currentVisual = egg:FindFirstChild("MonsterParasiteVisual")
			
			if not currentVisual then
				break
			end
			
			local currentTarget = getTargetPart(egg)
			
			if currentTarget then
				billboard.Adornee = currentTarget
			end
			
			task.wait(0.25)
		end
		
		if ESPs[egg] == billboard then
			removeESP(egg)
		end
	end)
end

local function checkEgg(egg)
	if not egg:IsA("Model") and not egg:IsA("Folder") then
		return
	end
	
	if egg:FindFirstChild("MonsterParasiteVisual") then
		createESP(egg)
	else
		removeESP(egg)
	end
end

--// Ovos que já existem
for _, egg in ipairs(AreaEggSlotsClient:GetChildren()) do
	checkEgg(egg)
end

--// Novos ovos
AreaEggSlotsClient.ChildAdded:Connect(function(egg)
	task.wait(0.05)
	
	checkEgg(egg)
	
	local connection
	connection = egg.DescendantAdded:Connect(function(obj)
		if obj.Name == "MonsterParasiteVisual" then
			task.wait()
			createESP(egg)
			if connection then
				connection:Disconnect()
			end
		end
	end)
	
	task.delay(5, function()
		if connection then
			connection:Disconnect()
		end
	end)
end)

--// Remove ESP quando o ovo é removido
AreaEggSlotsClient.ChildRemoved:Connect(function(egg)
	removeESP(egg)
end)

-- ============ FUNÇÕES DE FARM ============

local function getClosestEgg()
	local closest = nil
	local closestDistance = math.huge
	local charPos = Character:FindFirstChild("HumanoidRootPart")
	
	if not charPos then
		return nil
	end
	
	for _, egg in ipairs(AreaEggSlotsClient:GetChildren()) do
		local visual = egg:FindFirstChild("MonsterParasiteVisual")
		if visual then
			local target = getTargetPart(egg)
			if target then
				local distance = (target.Position - charPos.Position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closest = egg
				end
			end
		end
	end
	
	return closest
end

local function moveToPosition(targetPosition, stopDistance)
	stopDistance = stopDistance or 0.6

	local charRoot = Character:FindFirstChild("HumanoidRootPart")
	local humanoid = Character:FindFirstChild("Humanoid")

	if not charRoot or not humanoid then
		return false
	end

	--// Aproxima andando normalmente
	local startTime = tick()
	local APPROACH_DISTANCE = 3.0

	while farmActive do
		charRoot = Character:FindFirstChild("HumanoidRootPart")
		humanoid = Character:FindFirstChild("Humanoid")

		if not charRoot or not humanoid then
			return false
		end

		local distance = (charRoot.Position - targetPosition).Magnitude

		--// Quando estiver perto, para de usar MoveTo para evitar passar reto
		if distance <= APPROACH_DISTANCE then
			break
		end

		if tick() - startTime > 30 then
			return false
		end

		humanoid:MoveTo(targetPosition)
		task.wait(0.03)
	end

	if not farmActive then
		return false
	end

	--// Parada precisa: coloca o HRP exatamente no ponto e zera o movimento.
	--// Isso evita o "passar reto -> voltar -> passar reto" causado pelo MoveTo.
	charRoot = Character:FindFirstChild("HumanoidRootPart")
	humanoid = Character:FindFirstChild("Humanoid")

	if not charRoot or not humanoid then
		return false
	end

	humanoid:Move(Vector3.zero, false)
	humanoid:MoveTo(charRoot.Position)

	local rotation = charRoot.CFrame - charRoot.Position
	charRoot.CFrame = CFrame.new(targetPosition) * rotation

	--// Garante que a física não faça o personagem sair do ponto imediatamente.
	humanoid:Move(Vector3.zero, false)

	return (charRoot.Position - targetPosition).Magnitude <= stopDistance
end

local function getPromptAtPosition(targetPosition, keyCode, maxDistance)
	keyCode = keyCode or Enum.KeyCode.E
	maxDistance = maxDistance or 4

	local charRoot = Character:FindFirstChild("HumanoidRootPart")
	if not charRoot then
		return nil
	end

	local bestPrompt = nil
	local bestDistance = math.huge

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt")
			and obj.Enabled
			and obj.KeyboardKeyCode == keyCode then

			local parent = obj.Parent
			local promptPosition

			if parent:IsA("BasePart") then
				promptPosition = parent.Position
			elseif parent:IsA("Attachment") then
				promptPosition = parent.WorldPosition
			elseif parent:IsA("Model") then
				local part = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
				if part then
					promptPosition = part.Position
				end
			end

			if promptPosition then
				--// Confirma presença em DOIS pontos:
				--// 1) perto da posição esperada
				--// 2) perto do personagem
				local distanceFromTarget = (promptPosition - targetPosition).Magnitude
				local distanceFromPlayer = (promptPosition - charRoot.Position).Magnitude

				if distanceFromTarget <= maxDistance
					and distanceFromPlayer <= maxDistance then

					local distance = distanceFromPlayer

					if distance < bestDistance then
						bestDistance = distance
						bestPrompt = obj
					end
				end
			end
		end
	end

	return bestPrompt
end

local function getPromptPosition(prompt)
	local parent = prompt and prompt.Parent
	if not parent then
		return nil
	end

	if parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent:IsA("Model") then
		local part = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end

	return nil
end

local function completePromptAtPosition(targetPosition, keyCode, maxDistance)
	keyCode = keyCode or Enum.KeyCode.E
	maxDistance = maxDistance or 4

	--// NÃO procura prompts em um raio gigante.
	--// Só aceita o prompt depois que o personagem confirmou presença no ponto.
	local prompt = getPromptAtPosition(targetPosition, keyCode, maxDistance)

	if not prompt then
		return false
	end

	local promptPosition = getPromptPosition(prompt)
	local charRoot = Character:FindFirstChild("HumanoidRootPart")

	if not promptPosition or not charRoot then
		return false
	end

	--// Segunda confirmação imediatamente antes de ativar.
	if (charRoot.Position - targetPosition).Magnitude > maxDistance then
		return false
	end

	if (promptPosition - charRoot.Position).Magnitude > maxDistance then
		return false
	end

	--// Completa SOMENTE o prompt encontrado no ponto atual.
	prompt:InputHoldBegin()
	task.wait(0.8)
	prompt:InputHoldEnd()

	return true
end

local function farmLoop()
	print("🌾 Loop de Farm Iniciado!")

	while farmActive do
		local charRoot = Character:FindFirstChild("HumanoidRootPart")
		if not charRoot then
			print("❌ Personagem não encontrado!")
			task.wait(1)
			continue
		end

		--// 1. Encontra o egg mais próximo
		local egg = getClosestEgg()

		if not egg then
			print("⏳ Procurando ovos...")
			task.wait(2)
			continue
		end

		local target = getTargetPart(egg)
		if not target then
			task.wait(1)
			continue
		end

		--// 2. Move até o egg e só considera "chegou" após confirmar presença.
		print("🎯 Andando para o ovo...")
		local chegouNoOvo = moveToPosition(target.Position, 0.5)

		if not chegouNoOvo or not farmActive then
			continue
		end

		--// 3. Confirma que realmente está em cima/perto do ovo antes de usar E.
		task.wait(0.05)

		if (Character.HumanoidRootPart.Position - target.Position).Magnitude <= 3.5 then
			print("⚡ Presença no ovo confirmada! Completando E...")
			completePromptAtPosition(target.Position, Enum.KeyCode.E, 4)
		else
			print("⚠️ Presença no ovo não confirmada.")
			continue
		end

		task.wait(0.2)

		--// 4. Move para posição 1
		local pos1 = FARM_POSITIONS[1]
		print("📍 Andando para Posição 1...")

		local chegouPos1 = moveToPosition(pos1, 0.5)

		if not chegouPos1 or not farmActive then
			continue
		end

		--// 5. Só procura/completa E depois de confirmar presença na Pos1.
		task.wait(0.05)

		if (Character.HumanoidRootPart.Position - pos1).Magnitude <= 3.5 then
			print("⚡ Presença na Pos1 confirmada! Completando E...")
			completePromptAtPosition(pos1, Enum.KeyCode.E, 4)
		else
			print("⚠️ Presença na Pos1 não confirmada.")
			continue
		end

		--// 6. Trava por 1 segundo
		print("⏸️ Pausando 1 segundo...")
		task.wait(1)

		if not farmActive then
			break
		end

		--// 7. Move para posição 2
		local pos2 = FARM_POSITIONS[2]
		print("📍 Andando para Posição 2...")

		local chegouPos2 = moveToPosition(pos2, 0.5)

		if not chegouPos2 or not farmActive then
			continue
		end

		--// 8. Pos2 possui E em cima e R embaixo.
		--// O farm usa SOMENTE o prompt E (de cima).
		task.wait(0.05)

		if (Character.HumanoidRootPart.Position - pos2).Magnitude <= 3.5 then
			print("⚡ Presença na Pos2 confirmada! Completando SOMENTE o prompt E de cima...")
			completePromptAtPosition(pos2, Enum.KeyCode.E, 4)
		else
			print("⚠️ Presença na Pos2 não confirmada.")
			continue
		end

		task.wait(0.2)

		--// Repete
		print("🔄 Ciclo completo! Reiniciando...")
	end

	print("⛔ Farm encerrado!")
end

-- ============ CRIAR UI (BOTÃO DRAGGÁVEL) ============

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FarmGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = Player:WaitForChild("PlayerGui")

local farmButton = Instance.new("TextButton")
farmButton.Name = "FarmButton"
farmButton.Size = UDim2.fromOffset(100, 50)
farmButton.Position = UDim2.fromScale(0.5, 0.5)
farmButton.AnchorPoint = Vector2.new(0.5, 0.5)
farmButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
farmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
farmButton.TextSize = 16
farmButton.Font = Enum.Font.GothamBold
farmButton.Text = "🌾 FARM"
farmButton.BorderSizePixel = 2
farmButton.BorderColor3 = Color3.fromRGB(100, 200, 255)
farmButton.Parent = screenGui

--// Efeito hover
farmButton.MouseEnter:Connect(function()
	farmButton.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
end)

farmButton.MouseLeave:Connect(function()
	farmButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
end)

--// Drag system
local dragging = false
local dragStart = nil
local startPos = nil

farmButton.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = farmButton.Position
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		local newX = startPos.X.Offset + delta.X
		local newY = startPos.Y.Offset + delta.Y
		farmButton.Position = UDim2.fromOffset(newX, newY)
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

--// Click do botão
farmButton.MouseButton1Click:Connect(function()
	farmActive = not farmActive
	
	if farmActive then
		print("🌾 FARM INICIADO!")
		farmButton.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
		farmButton.Text = "🛑 STOP"
		
		--// Inicia o loop de farm em uma thread separada
		task.spawn(farmLoop)
	else
		print("⛔ FARM PARADO!")
		farmButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
		farmButton.Text = "🌾 FARM"
	end
end)

--// Atualiza character quando respawna
Player.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	farmActive = false
	farmButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	farmButton.Text = "🌾 FARM"
	print("⚠️ Personagem respawnou! Farm desativado.")
end)

print("✅ MONSTER PARASITE ESP + FARM ATIVADO")
print("📍 Monitorando AreaEggSlotsClient")
print("🌾 Botão Farm disponível (clique para ativar/desativar)")

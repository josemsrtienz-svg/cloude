--[[
	PescaDeMemes • PlotService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > PlotService

	Parcelas: una por jugador, en fila a los lados del río (las construye WorldBuilder).
	  · Al entrar se te asigna una parcela libre y apareces en ella (con su muelle privado delante).
	  · DESCARGA AUTOMÁTICA: al entrar en tu parcela, los memes de tu mochila-acuario se colocan solos
	    en los huecos libres del césped (los más valiosos primero).
	  · Cada meme expuesto es una figura de bloques (MemeModels) con su "+🪙X/min" encima.
	  · "Recoger" (ProximityPrompt del hueco) lo devuelve a la mochila-acuario si cabe.
	  · Los ingresos se acumulan en el CÍRCULO COBRADOR; se cobran pisándolo.
	  · GoHome(): teletransporte a tu parcela.
	Todo se valida aquí (dueño, captura, hueco, capacidad). El cliente oculta los prompts que no son tuyos.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Remotes = require(Root.Shared.Remotes)
local FishMath = require(Root.Shared.FishMath)
local Inventory = require(Root.Shared.Inventory)
local MemeModels = require(Root.Shared.MemeModels)
local Util = require(Root.Shared.Util)

local PlayerData = require(script.Parent.PlayerData)
local MissionService = require(script.Parent.MissionService)
local FishingService = require(script.Parent.FishingService)
local BoostService = require(script.Parent.BoostService)

local PlotService = {}

local INCOME_TICK = 5

local owners: { [number]: Player } = {}
local plotOf: { [Player]: number } = {}
local bankRemainder: { [Player]: number } = {}
local lastCollect: { [Player]: number } = {}
local lastHome: { [Player]: number } = {}
local wasInside: { [Player]: boolean } = {}

local function fail(err: string): any
	return { ok = false, err = err }
end

local function plotFolder(index: number): Instance?
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index)
end

local function incomeText(catch: any): string
	return "+🪙" .. Inventory.FormatIncome(Inventory.CatchIncome(catch, GameConfig.PlotIncomeRate))
end

-- Cartel del dueño: su nombre y, encima, la CARA de su avatar (miniatura de Roblox, la ven todos).
local function setSign(index: number, text: string, userId: number?)
	local plot = plotFolder(index)
	local sign = plot and plot:FindFirstChild("OwnerSign") :: BasePart?
	local label = sign and sign:FindFirstChild("Label", true) :: TextLabel?
	if label then
		label.Text = text
	end
	if not sign then
		return
	end
	local avatar = sign:FindFirstChild("OwnerAvatar") :: BillboardGui?
	if not avatar then
		local bb = Instance.new("BillboardGui")
		bb.Name = "OwnerAvatar"
		bb.Size = UDim2.fromScale(5, 5)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 5.4, 0)
		bb.MaxDistance = 200
		bb.LightInfluence = 0
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		frame.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = sign.Color
		stroke.Parent = frame
		local image = Instance.new("ImageLabel")
		image.Name = "Face"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = frame
		local imageCorner = Instance.new("UICorner")
		imageCorner.CornerRadius = UDim.new(0.5, 0)
		imageCorner.Parent = image
		bb.Parent = sign
		avatar = bb
	end
	local face = (avatar :: BillboardGui):FindFirstChild("Face", true) :: ImageLabel?
	if face then
		face.Image = if userId and userId > 0 then ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(userId) else ""
	end
	(avatar :: BillboardGui).Enabled = userId ~= nil and userId > 0
end

local function setBankLabel(index: number, amount: number?)
	local plot = plotFolder(index)
	local collector = plot and plot:FindFirstChild("Collector")
	local label = collector and collector:FindFirstChild("BankLabel", true) :: TextLabel?
	if label then
		label.Text = if amount then ("🪙 %s\nPisa para cobrar"):format(Util.formatShort(amount)) else "Cobrador"
	end
end

-- ===== Memes expuestos en el césped =====

local function buildDisplay(parent: Instance, spot: BasePart, catch: any)
	local meme = Memes.Get(catch.MemeId)
	if not meme then
		return
	end
	local rarity = Memes.Rarities[meme.Rarity]
	-- el tamaño importa: cuanto más pesa, más grande se ve (con tope)
	local scale = FishMath.DisplayScale(meme, catch.Weight)
	local model = MemeModels.Build(meme.Id, scale, catch.Golden)
	-- mirando hacia el río (el frente de la parcela), de pie sobre el césped
	model:PivotTo(spot.CFrame * CFrame.new(0, spot.Size.Y / 2, 0))
	model.Parent = parent
	CollectionService:AddTag(model, "PescaMemeDisplay") -- el cliente lo anima (Ambience)

	-- aro de rareza en el suelo
	local ring = Instance.new("Part")
	ring.Name = "RarityRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 6.5, 6.5)
	ring.CFrame = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = if catch.Golden then Color3.fromRGB(255, 200, 50) else rarity.Color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = parent

	-- etiquetas flotando: nombre + ingresos (estilo "+$79K")
	local anchor = model.PrimaryPart :: BasePart
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromOffset(220, 70)
	bb.StudsOffsetWorldSpace = Vector3.new(0, MemeModels.Height(meme.Id, scale) + 1.2, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = anchor
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.45)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = ring.Color
	name.TextStrokeTransparency = 0
	name.Text = (if catch.Golden then "✨ " else "") .. meme.Name .. " · " .. FishMath.FormatWeight(catch.Weight)
	name.Parent = bb
	local income = Instance.new("TextLabel")
	income.BackgroundTransparency = 1
	income.Position = UDim2.fromScale(0, 0.45)
	income.Size = UDim2.fromScale(1, 0.55)
	income.Font = Enum.Font.LuckiestGuy
	income.TextScaled = true
	income.TextColor3 = Color3.fromRGB(90, 255, 90)
	income.TextStrokeTransparency = 0
	income.Text = incomeText(catch)
	income.Parent = bb
end

-- Sincroniza los memes expuestos con los datos: solo reconstruye los huecos que cambiaron.
function PlotService.Refresh(player: Player)
	local index = plotOf[player]
	local data = PlayerData.Get(player)
	local plot = index and plotFolder(index)
	if not index or not data or not plot then
		return
	end
	local spots = plot:FindFirstChild("Spots")
	local displays = plot:FindFirstChild("Displays")
	if not spots or not displays then
		return
	end
	for slot = 1, GameConfig.PlotSlots do
		local spot = spots:FindFirstChild("Spot" .. slot) :: BasePart?
		local id = data.Plot[slot]
		local catch = id ~= "" and data.Catches[id]
		local wanted = if catch then id else ""
		local slotFolder = displays:FindFirstChild("Slot" .. slot)
		if not slotFolder then
			slotFolder = Instance.new("Folder")
			slotFolder.Name = "Slot" .. slot
			slotFolder:SetAttribute("CatchId", "")
			slotFolder.Parent = displays
		end
		if slotFolder:GetAttribute("CatchId") ~= wanted then
			slotFolder:ClearAllChildren()
			slotFolder:SetAttribute("CatchId", wanted)
			if catch and spot then
				buildDisplay(slotFolder, spot, catch)
			end
		end
		if spot then
			-- el cliente solo muestra "Recoger" en los huecos ocupados de SU parcela
			spot:SetAttribute("Occupied", catch ~= nil and catch ~= false)
		end
	end
end

local function clearDisplays(index: number)
	local plot = plotFolder(index)
	local displays = plot and plot:FindFirstChild("Displays")
	if displays then
		displays:ClearAllChildren()
	end
	local spots = plot and plot:FindFirstChild("Spots")
	if spots then
		for _, spot in ipairs(spots:GetChildren()) do
			spot:SetAttribute("Occupied", false)
		end
	end
end

-- ===== Descarga automática y Recoger =====

local function deposit(player: Player)
	local index = plotOf[player]
	local data = PlayerData.Get(player)
	if not index or not data then
		return
	end
	local aquarium = Inventory.Aquarium(data) -- ya viene ordenado por valor
	if #aquarium == 0 then
		return
	end
	local placed = 0
	for _, catch in ipairs(aquarium) do
		local slot = table.find(data.Plot, "")
		if not slot then
			break
		end
		data.Plot[slot] = catch.Id
		placed += 1
	end
	if placed > 0 then
		PlayerData.Push(player)
		PlotService.Refresh(player)
		PlayerData.Notify(player, ("🏠 %d meme%s colocado%s en tu parcela"):format(placed, if placed == 1 then "" else "s",
			if placed == 1 then "" else "s"), "Success")
	else
		PlayerData.Notify(player, "🏠 Tu parcela está llena: pulsa \"Recoger\" en un meme para hacer sitio (y véndelo desde el Acuario)", "Warning")
	end
end

local function insidePlot(player: Player, index: number): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	local localPos = GameConfig.PlotCFrame(index):PointToObjectSpace(hrp.Position)
	local half = GameConfig.Plots.Size / 2
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half and localPos.Y < 20
end

local function onPickup(player: Player, index: number, slot: number)
	if plotOf[player] ~= index then
		PlayerData.Notify(player, "🚫 Esta no es tu parcela", "Error")
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local id = data.Plot[slot]
	local catch = id ~= "" and data.Catches[id]
	if not catch then
		return
	end
	if FishingService.IsFishing(player) then
		PlayerData.Notify(player, "Termina de pescar primero", "Warning")
		return
	end
	if catch.Size > Inventory.Free(data) then
		PlayerData.Notify(player, "🐠 No cabe en tu acuario: vende algo o compra una mochila más grande", "Error")
		return
	end
	data.Plot[slot] = ""
	PlayerData.Push(player)
	PlotService.Refresh(player)
	local meme = Memes.Get(catch.MemeId)
	-- la descarga solo ocurre al ENTRAR en la parcela, así que no se vuelve a colocar sola mientras sigas dentro
	PlayerData.Notify(player, ("🐠 %s vuelve a tu acuario (véndelo o cámbialo; al volver a entrar se colocan los mejores)"):format(
		meme and meme.Name or "Meme"), "Info")
end

-- ===== Cobrador =====

local function collect(player: Player)
	local index = plotOf[player]
	local data = PlayerData.Get(player)
	if not index or not data or data.PlotBank <= 0 then
		return
	end
	local now = os.clock()
	if lastCollect[player] and now - lastCollect[player] < 1 then
		return
	end
	lastCollect[player] = now
	local amount = data.PlotBank
	data.PlotBank = 0
	data.MemeCoin += amount
	MissionService.Progress(player, "Collect", amount)
	player:SetAttribute("PlotBank", 0)
	PlayerData.Push(player)
	setBankLabel(index, 0)
	PlayerData.Notify(player, ("💰 ¡Cobrado! +%s MemeCoins"):format(Util.formatShort(amount)), "Success")
end

-- ===== Asignación =====

local function spawnAtPlot(player: Player, character: Model)
	local index = plotOf[player]
	local plot = index and plotFolder(index)
	local spawnPart = plot and plot:FindFirstChild("Spawn") :: BasePart?
	if not spawnPart then
		return
	end
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		task.wait(0.1)
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	end
end

local function assign(player: Player)
	for index = 1, GameConfig.Plots.Count do
		if not owners[index] and plotFolder(index) then
			owners[index] = player
			plotOf[player] = index
			player:SetAttribute("PlotIndex", index)
			setSign(index, player.DisplayName, player.UserId)
			-- si los datos ya estaban cargados (p. ej. en Studio sin DataStore), pintamos la parcela ya
			local data = PlayerData.Get(player)
			if data then
				PlotService.Refresh(player)
				setBankLabel(index, data.PlotBank)
			end
			return
		end
	end
	player:SetAttribute("PlotIndex", 0)
	PlayerData.Notify(player, "⚠️ No quedan parcelas libres en este servidor: no puedes pescar ni exponer memes. Cambia de servidor.", "Error")
end

local function release(player: Player)
	local index = plotOf[player]
	if index then
		owners[index] = nil
		clearDisplays(index)
		setSign(index, "Parcela libre")
		setBankLabel(index, nil)
	end
	plotOf[player] = nil
	bankRemainder[player] = nil
	lastCollect[player] = nil
	lastHome[player] = nil
	wasInside[player] = nil
end

local function grantOffline(player: Player, data: any)
	local now = os.time()
	if data.LastSeen > 0 then
		local elapsed = math.clamp(now - data.LastSeen, 0, GameConfig.OfflineCapHours * 3600)
		local earned = math.floor(Inventory.PlotIncomePerMinute(data, GameConfig.PlotIncomeRate) * GameConfig.OfflineIncomeMultiplier * elapsed / 60)
		if earned > 0 then
			data.PlotBank += earned
			PlayerData.Notify(player, ("🏠 Tu parcela ganó %s 🪙 mientras no estabas: ¡pisa el cobrador!"):format(Util.formatShort(earned)), "Success")
		end
	end
	data.LastSeen = now
end

local function onGoHome(player: Player): any
	local index = plotOf[player]
	if not index then
		return fail("No tienes parcela en este servidor")
	end
	if FishingService.IsFishing(player) then
		return fail("Termina de pescar primero")
	end
	local now = os.clock()
	if lastHome[player] and now - lastHome[player] < GameConfig.Plots.GoHomeCooldown then
		return fail("Espera un momento")
	end
	lastHome[player] = now
	local character = player.Character
	if not character then
		return fail("Sin personaje")
	end
	task.spawn(spawnAtPlot, player, character)
	return { ok = true }
end

function PlotService.Init()
	Remotes.Get("GoHome").OnServerInvoke = onGoHome

	-- prompts "Recoger" y cobradores de todas las parcelas
	for index = 1, GameConfig.Plots.Count do
		local plot = plotFolder(index)
		if plot then
			local spots = plot:FindFirstChild("Spots")
			for slot = 1, GameConfig.PlotSlots do
				local spot = spots and spots:FindFirstChild("Spot" .. slot)
				local prompt = spot and spot:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt.Triggered:Connect(function(player)
						onPickup(player, index, slot)
					end)
				end
			end
			local collector = plot:FindFirstChild("Collector") :: BasePart?
			if collector then
				collector.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player and plotOf[player] == index then
						collect(player)
					end
				end)
			end
		end
	end

	local function onPlayer(player: Player)
		assign(player)
		player.CharacterAdded:Connect(function(character)
			spawnAtPlot(player, character)
		end)
		if player.Character then
			task.spawn(spawnAtPlot, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local data = PlayerData.Get(player)
		if data then
			data.LastSeen = os.time()
		end
		release(player)
	end)

	PlayerData.Loaded:Connect(function(player, data)
		grantOffline(player, data)
		player:SetAttribute("PlotBank", data.PlotBank)
		PlayerData.Push(player)
		-- si aún no tiene parcela (los datos llegaron antes que la asignación), assign() la pintará
		local index = plotOf[player]
		if index then
			PlotService.Refresh(player)
			setBankLabel(index, data.PlotBank)
		end
	end)

	-- descarga automática al ENTRAR en tu parcela (no mientras sigues dentro: así "Recoger" funciona)
	task.spawn(function()
		while true do
			task.wait(GameConfig.DepositCheckInterval)
			for player, index in pairs(plotOf) do
				local inside = insidePlot(player, index)
				local entered = inside and not wasInside[player]
				wasInside[player] = inside
				local data = entered and PlayerData.Get(player)
				if data then
					local ok, err = pcall(deposit, player)
					if not ok then
						warn("[PescaDeMemes] Error descargando el acuario de " .. player.Name .. ": " .. tostring(err))
					end
				end
			end
		end
	end)

	-- ingresos: se acumulan en el cobrador de cada parcela
	task.spawn(function()
		while true do
			task.wait(INCOME_TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data then
					data.LastSeen = os.time()
					local index = plotOf[player]
					if index then -- sin parcela no se genera
						local amount = Inventory.PlotIncomePerMinute(data, GameConfig.PlotIncomeRate) * INCOME_TICK / 60
							* BoostService.Money(player) + (bankRemainder[player] or 0)
						local whole = math.floor(amount)
						bankRemainder[player] = amount - whole
						if whole > 0 then
							data.PlotBank += whole
							player:SetAttribute("PlotBank", data.PlotBank)
							setBankLabel(index, data.PlotBank)
						end
					end
				end
			end
		end
	end)
end

return PlotService

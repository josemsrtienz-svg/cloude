--[[
	PescaDeMemes • PlotService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > PlotService

	Parcelas: una por jugador, alrededor de la charca (las construye WorldBuilder).
	  · Al entrar se te asigna una parcela libre y apareces en ella.
	  · CarryCatch(id): llevas un meme de la mochila flotando sobre tu cabeza (no puedes pescar mientras).
	  · Pedestal (ProximityPrompt): si llevas un meme y está vacío → lo colocas.
	                                si está ocupado y no llevas nada → lo recoges y lo llevas.
	  · Los memes expuestos generan MemeCoins que se acumulan en el COBRADOR; se cobran pisándolo.
	  · GoHome(): teletransporte a tu parcela.
	Todo se valida aquí (dueño, captura, hueco, mochila). Los prompts de otras parcelas el cliente los oculta.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Remotes = require(Root.Shared.Remotes)
local FishMath = require(Root.Shared.FishMath)
local Inventory = require(Root.Shared.Inventory)
local Util = require(Root.Shared.Util)

local PlayerData = require(script.Parent.PlayerData)
local FishingService = require(script.Parent.FishingService)

local PlotService = {}

local INCOME_TICK = 5

local owners: { [number]: Player } = {}
local plotOf: { [Player]: number } = {}
local bankRemainder: { [Player]: number } = {}
local lastCollect: { [Player]: number } = {}
local lastHome: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}

local function fail(err: string): any
	return { ok = false, err = err }
end

local function rateLimited(player: Player): boolean
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.3 then
		return true
	end
	lastRequest[player] = now
	return false
end

-- El atributo "Carrying" es la ÚNICA fuente de verdad de lo que lleva el jugador
-- (también lo leen FishingService y EconomyService).
local function getCarrying(player: Player): string?
	local id = player:GetAttribute("Carrying")
	return if type(id) == "string" and id ~= "" then id else nil
end
PlotService.GetCarrying = getCarrying

local function incomeText(catch: any): string
	return "🪙 " .. Inventory.FormatIncome(Inventory.CatchIncome(catch, GameConfig.PlotIncomeRate))
end

local function plotFolder(index: number): Instance?
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index)
end

local function setSign(index: number, text: string)
	local plot = plotFolder(index)
	local sign = plot and plot:FindFirstChild("OwnerSign")
	local label = sign and sign:FindFirstChild("Label", true) :: TextLabel?
	if label then
		label.Text = text
	end
end

-- El saldo del cobrador también va en un atributo del jugador para que su UI lo vea sin reenviar todos los datos.
local function setBankLabel(index: number, amount: number?)
	local plot = plotFolder(index)
	local collector = plot and plot:FindFirstChild("Collector")
	local label = collector and collector:FindFirstChild("BankLabel", true) :: TextLabel?
	if label then
		label.Text = if amount then ("🪙 %s\nPisa para cobrar"):format(Util.formatNumber(amount)) else "Cobrador"
	end
end

-- ===== Meme sobre la cabeza =====

local function clearCarryVisual(player: Player)
	local character = player.Character
	local old = character and character:FindFirstChild("CarriedMeme")
	if old then
		old:Destroy()
	end
end

local function buildCarryVisual(player: Player, catch: any)
	clearCarryVisual(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local meme = Memes.Get(catch.MemeId)
	if not head or not meme then
		return
	end
	local rarity = Memes.Rarities[meme.Rarity]
	local orb = Instance.new("Part")
	orb.Name = "CarriedMeme"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 2.2
	orb.Color = if catch.Golden then Color3.fromRGB(255, 200, 50) else rarity.Color
	orb.Material = Enum.Material.Neon
	orb.Transparency = 0.45
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.Massless = true
	orb.CFrame = head.CFrame * CFrame.new(0, 3.2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = orb
	weld.Parent = orb
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 110)
	bb.StudsOffset = Vector3.new(0, 0.6, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 150
	bb.Parent = orb
	local emoji = Instance.new("TextLabel")
	emoji.BackgroundTransparency = 1
	emoji.Size = UDim2.new(1, 0, 0.7, 0)
	emoji.Text = meme.Emoji
	emoji.TextScaled = true
	emoji.Parent = bb
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0.7)
	name.Size = UDim2.new(1, 0, 0.3, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = orb.Color
	name.TextStrokeTransparency = 0
	name.Text = meme.Name .. " · " .. FishMath.FormatWeight(catch.Weight)
	name.Parent = bb
	orb.Parent = character
end

local function setCarry(player: Player, catchId: string?)
	player:SetAttribute("Carrying", catchId or "")
	local data = PlayerData.Get(player)
	local catch = catchId and data and data.Catches[catchId]
	if catch then
		buildCarryVisual(player, catch)
	else
		clearCarryVisual(player)
	end
end

-- ===== Pedestales =====

local function clearDisplays(index: number)
	local plot = plotFolder(index)
	local displays = plot and plot:FindFirstChild("Displays")
	if displays then
		displays:ClearAllChildren()
	end
end

local function buildDisplay(parent: Instance, pedestal: BasePart, catch: any)
	local meme = Memes.Get(catch.MemeId)
	if not meme then
		return
	end
	local rarity = Memes.Rarities[meme.Rarity]
	local color = if catch.Golden then Color3.fromRGB(255, 200, 50) else rarity.Color
	-- el pedestal es un cilindro girado: su altura es Size.X
	local top = CFrame.new(pedestal.Position + Vector3.new(0, pedestal.Size.X / 2, 0))

	local holder = Instance.new("Model")
	holder.Name = "Display"
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.3, 4.4, 4.4)
	glow.CFrame = top * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	glow.Color = color
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.3
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = glow

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(6, 7)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	bb.Parent = glow
	local emoji = Instance.new("TextLabel")
	emoji.BackgroundTransparency = 1
	emoji.Size = UDim2.fromScale(1, 0.62)
	emoji.Text = meme.Emoji
	emoji.TextScaled = true
	emoji.Parent = bb
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0.62)
	name.Size = UDim2.fromScale(1, 0.2)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = color
	name.TextStrokeTransparency = 0
	name.Text = (if catch.Golden then "✨ " else "") .. meme.Name
	name.Parent = bb
	local income = Instance.new("TextLabel")
	income.BackgroundTransparency = 1
	income.Position = UDim2.fromScale(0, 0.82)
	income.Size = UDim2.fromScale(1, 0.18)
	income.Font = Enum.Font.FredokaOne
	income.TextScaled = true
	income.TextColor3 = Color3.fromRGB(255, 220, 90)
	income.TextStrokeTransparency = 0
	income.Text = incomeText(catch)
	income.Parent = bb
	holder.Parent = parent
end

-- Sincroniza los memes expuestos con los datos: solo reconstruye los pedestales que cambiaron.
function PlotService.Refresh(player: Player)
	local index = plotOf[player]
	local data = PlayerData.Get(player)
	local plot = index and plotFolder(index)
	if not index or not data or not plot then
		return
	end
	local pedestals = plot:FindFirstChild("Pedestals")
	local displays = plot:FindFirstChild("Displays")
	if not pedestals or not displays then
		return
	end
	for slot = 1, GameConfig.PlotSlots do
		local pedestal = pedestals:FindFirstChild("Pedestal" .. slot) :: BasePart?
		local prompt = pedestal and pedestal:FindFirstChildOfClass("ProximityPrompt")
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
			if catch and pedestal then
				buildDisplay(slotFolder, pedestal, catch)
			end
		end
		if prompt then
			prompt.ActionText = if catch then "Recoger" else "Colocar meme"
		end
	end
end

local function resetPrompts(index: number)
	local plot = plotFolder(index)
	local pedestals = plot and plot:FindFirstChild("Pedestals")
	if not pedestals then
		return
	end
	for _, pedestal in ipairs(pedestals:GetChildren()) do
		local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.ActionText = "Colocar meme"
		end
	end
end

local function onPedestal(player: Player, index: number, slot: number)
	if plotOf[player] ~= index then
		PlayerData.Notify(player, "🚫 Esta no es tu parcela", "Error")
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local current = data.Plot[slot]
	local carried = getCarrying(player)
	if carried then
		if current ~= "" then
			PlayerData.Notify(player, "Este pedestal está ocupado: elige uno vacío", "Warning")
			return
		end
		local catch = data.Catches[carried]
		if not catch or Inventory.InPlot(data, carried) then
			setCarry(player, nil)
			return
		end
		data.Plot[slot] = carried
		setCarry(player, nil)
		PlayerData.Push(player)
		PlotService.Refresh(player)
		local meme = Memes.Get(catch.MemeId)
		PlayerData.Notify(player, ("🏠 %s colocado: genera %s"):format(meme and meme.Name or "Meme", incomeText(catch)), "Success")
	elseif current ~= "" then
		if FishingService.IsFishing(player) then
			PlayerData.Notify(player, "Termina de pescar primero", "Warning")
			return
		end
		if Inventory.BackpackCount(data) >= GameConfig.MaxBackpack then
			PlayerData.Notify(player, "🎒 Mochila llena: vende algo antes de recogerlo", "Error")
			return
		end
		data.Plot[slot] = ""
		PlayerData.Push(player)
		PlotService.Refresh(player)
		setCarry(player, current)
		PlayerData.Notify(player, "Lo llevas encima: colócalo en otro pedestal o guárdalo en la mochila", "Info")
	else
		PlayerData.Notify(player, "🎣 Pesca un meme y tráelo aquí para colocarlo", "Info")
	end
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
	player:SetAttribute("PlotBank", 0)
	PlayerData.Push(player)
	setBankLabel(index, 0)
	PlayerData.Notify(player, ("💰 ¡Cobrado! +%s MemeCoins"):format(Util.formatNumber(amount)), "Success")
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
			setSign(index, "🏠 Parcela de " .. player.DisplayName)
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
	PlayerData.Notify(player, "⚠️ No quedan parcelas libres en este servidor: tus memes expuestos no generan hasta que tengas una. Cambia de servidor.", "Error")
end

local function release(player: Player)
	setCarry(player, nil)
	local index = plotOf[player]
	if index then
		owners[index] = nil
		clearDisplays(index)
		resetPrompts(index)
		setSign(index, "Parcela libre")
		setBankLabel(index, nil)
	end
	plotOf[player] = nil
	bankRemainder[player] = nil
	lastRequest[player] = nil
	lastCollect[player] = nil
	lastHome[player] = nil
end

local function grantOffline(player: Player, data: any)
	local now = os.time()
	if data.LastSeen > 0 then
		local elapsed = math.clamp(now - data.LastSeen, 0, GameConfig.OfflineCapHours * 3600)
		local earned = math.floor(Inventory.PlotIncomePerMinute(data, GameConfig.PlotIncomeRate) * GameConfig.OfflineIncomeMultiplier * elapsed / 60)
		if earned > 0 then
			data.PlotBank += earned
			PlayerData.Notify(player, ("🏠 Tu parcela ganó %s 🪙 mientras no estabas: ¡ve a cobrarlo!"):format(Util.formatNumber(earned)), "Success")
		end
	end
	data.LastSeen = now
end

-- ===== Remotes =====

local function onCarry(player: Player, catchId: any): any
	if rateLimited(player) then
		return fail("Más despacio")
	end
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	if not plotOf[player] then
		return fail("No tienes parcela en este servidor")
	end
	if type(catchId) ~= "string" or not data.Catches[catchId] then
		return fail("No tienes esa captura")
	end
	if Inventory.InPlot(data, catchId) then
		return fail("Ya está en tu parcela")
	end
	if FishingService.IsFishing(player) then
		return fail("Termina de pescar primero")
	end
	setCarry(player, catchId)
	return { ok = true }
end

local function onDrop(player: Player): any
	if rateLimited(player) then
		return fail("Más despacio")
	end
	if not getCarrying(player) then
		return fail("No llevas nada")
	end
	setCarry(player, nil)
	return { ok = true }
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
	Remotes.Get("CarryCatch").OnServerInvoke = onCarry
	Remotes.Get("DropCarry").OnServerInvoke = onDrop
	Remotes.Get("GoHome").OnServerInvoke = onGoHome

	-- prompts de pedestales y cobradores de todas las parcelas
	for index = 1, GameConfig.Plots.Count do
		local plot = plotFolder(index)
		if plot then
			local pedestals = plot:FindFirstChild("Pedestals")
			for slot = 1, GameConfig.PlotSlots do
				local pedestal = pedestals and pedestals:FindFirstChild("Pedestal" .. slot)
				local prompt = pedestal and pedestal:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt.Triggered:Connect(function(player)
						onPedestal(player, index, slot)
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
			player:SetAttribute("Carrying", "") -- al morir, lo que llevabas vuelve a la mochila
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
							+ (bankRemainder[player] or 0)
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

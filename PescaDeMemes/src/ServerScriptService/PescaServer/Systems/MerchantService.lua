--[[
	PescaDeMemes • MerchantService (ModuleScript)
	ServerScriptService > PescaServer > Systems > MerchantService

	El MERCADER AMBULANTE (reglas y ofertas en Config/Merchant):
	  · Su BARCA-TIENDA amarra junto al puente (lado sur) mientras está abierto; si no, desaparece.
	  · Publica en Workspace: MerchantOpen (bool), MerchantVisit (nº de visita), MerchantNext (segundos de
	    servidor en que se va o vuelve). El cliente lo usa para el panel y la cuenta atrás.
	  · BuyMerchant(index): el servidor recalcula las ofertas de la visita y valida todo (abierto, cerca, precio,
	    límite por jugador, sitio en la mochila).
	Modo prueba (Studio): GameConfig.DevMode.MerchantAlways = true → siempre está.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local Boosts = require(Root.Config.Boosts)
local Merchant = require(Root.Config.Merchant)
local Remotes = require(Root.Shared.Remotes)
local Inventory = require(Root.Shared.Inventory)
local FishMath = require(Root.Shared.FishMath)

local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local FishingService = require(script.Parent.FishingService)

local MerchantService = {}

local RGB = Color3.fromRGB
local ALWAYS = RunService:IsStudio() and GameConfig.DevMode.Enabled and GameConfig.DevMode.MerchantAlways == true

local boat: Model? = nil
local counter: BasePart? = nil
local lastAction: { [Player]: number } = {}

local function fail(err: string): any
	return { ok = false, err = err }
end

-- ===== La barca-tienda (modelo de bloques) =====
-- Diseño: casco de tablas con la proa y la popa escalonadas (estilo bloques del juego), franja morada,
-- borda dorada, cubierta de tablas, defensas de cuerda hacia el puente, toldo a rayas morado/dorado con
-- flecos, farolillos, mostrador con cajas, barril, cofre y pociones, y el MERCADER (túnica, cinturón,
-- barba, sombrero de ala ancha con pluma y una mochila enorme). Mira hacia el puente (+Z).

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function buildBoat(origin: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "MerchantBoat"
	local rng = Random.new(42)
	local wood, woodDark, woodLight = RGB(150, 100, 60), RGB(105, 68, 40), RGB(185, 135, 85)
	local purple, gold = RGB(120, 60, 190), RGB(240, 190, 60)
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local function vary(c: Color3): Color3
		return c:Lerp(woodDark, rng:NextNumber(0, 0.25))
	end

	-- casco: fondo, tres hiladas de tablas por banda, proa/popa escalonadas
	piece(m, "Keel", Vector3.new(13, 0.8, 4.6), at(0, -0.4, 0), woodDark, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		for row = 0, 2 do
			piece(m, "Strake", Vector3.new(13 - row * 0.2, 0.55, 0.35), at(0, 0.1 + row * 0.55, side * (2.45 + row * 0.08)), vary(wood),
				Enum.Material.WoodPlanks)
		end
		piece(m, "Stripe", Vector3.new(13.2, 0.25, 0.1), at(0, 0.65, side * 2.72), purple)
		piece(m, "Gunwale", Vector3.new(13.4, 0.25, 0.55), at(0, 1.55, side * 2.55), gold, Enum.Material.Wood)
	end
	for _, dir in ipairs({ -1, 1 }) do
		for step = 1, 3 do
			local width = 4.8 - step * 1.25
			piece(m, "BowStep", Vector3.new(1, 1.6 + step * 0.15, width), at(dir * (6 + step * 0.9), 0.4 + step * 0.08, 0), vary(wood),
				Enum.Material.WoodPlanks)
			piece(m, "BowTrim", Vector3.new(1, 0.22, width + 0.3), at(dir * (6 + step * 0.9), 1.3 + step * 0.15, 0), gold, Enum.Material.Wood)
		end
		piece(m, "Figurehead", Vector3.new(0.8, 0.8, 0.8), at(dir * 9.3, 1.9, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
	end
	-- cubierta
	for x = -5.5, 5.5, 1 do
		piece(m, "Deck", Vector3.new(0.95, 0.2, 4.6), at(x, 0.45, 0), vary(woodLight), Enum.Material.WoodPlanks)
	end
	-- defensas de cuerda hacia el puente (+Z)
	for _, x in ipairs({ -4, 0, 4 }) do
		piece(m, "Fender", Vector3.new(1, 0.6, 0.6), at(x, 0.6, 2.95) * CFrame.Angles(0, 0, math.rad(90)), RGB(60, 50, 45), Enum.Material.Fabric,
			Enum.PartType.Cylinder)
	end

	-- toldo: postes, tejado a dos aguas con lamas de colores y flecos
	for _, x in ipairs({ -4.5, 4.5 }) do
		for _, z in ipairs({ -2.1, 2.1 }) do
			piece(m, "Post", Vector3.new(0.35, 5, 0.35), at(x, 3, z), woodDark, Enum.Material.Wood)
		end
	end
	for i = 0, 9 do
		local x = -4.5 + i
		local color = if i % 2 == 0 then purple else gold
		for _, side in ipairs({ -1, 1 }) do
			piece(m, "Awning", Vector3.new(1, 0.15, 2.6), at(x + 0.5, 5.9, side * 1.15) * CFrame.Angles(side * math.rad(-18), 0, 0), color, Enum.Material.Fabric)
			piece(m, "Fringe", Vector3.new(0.5, 0.35, 0.08), at(x + 0.5, 5.3, side * 2.45), if i % 2 == 0 then gold else purple, Enum.Material.Fabric)
		end
	end
	piece(m, "Ridge", Vector3.new(10.2, 0.3, 0.3), at(0, 6.35, 0), woodDark, Enum.Material.Wood)
	-- cartel en lo alto, legible desde el puente
	local signBoard = piece(m, "Sign", Vector3.new(7, 1.6, 0.25), at(0, 7.4, 0), woodDark, Enum.Material.WoodPlanks)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = signBoard
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "🧳 MERCADER"
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = gold
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = RGB(40, 20, 50)
		stroke.Parent = label
	end
	-- farolillos en las esquinas del toldo
	for _, x in ipairs({ -4.5, 4.5 }) do
		piece(m, "LanternString", Vector3.new(0.08, 0.8, 0.08), at(x, 4.9, 2.3), RGB(60, 50, 40))
		piece(m, "LanternCage", Vector3.new(0.6, 0.75, 0.6), at(x, 4.2, 2.3), RGB(60, 45, 30), Enum.Material.Metal).Transparency = 0.25
		local bulb = piece(m, "LanternBulb", Vector3.new(0.4, 0.4, 0.4), at(x, 4.2, 2.3), RGB(255, 200, 120), Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = RGB(255, 190, 120)
		light.Range = 14
		light.Brightness = 1.3
		light.Parent = bulb
	end

	-- mostrador hacia el puente con su mercancía
	local top = piece(m, "Counter", Vector3.new(7, 0.3, 1.2), at(0, 1.95, 1.7), woodLight, Enum.Material.WoodPlanks)
	piece(m, "CounterFront", Vector3.new(7, 1.4, 0.25), at(0, 1.2, 2.2), wood, Enum.Material.WoodPlanks)
	piece(m, "CounterTrim", Vector3.new(7.2, 0.2, 0.35), at(0, 2.15, 2.25), purple)
	for i, color in ipairs({ RGB(255, 80, 120), RGB(80, 220, 255), RGB(120, 255, 120), RGB(255, 210, 60) }) do
		local x = -2.8 + i * 0.6
		piece(m, "Potion", Vector3.new(0.4, 0.4, 0.4), at(x, 2.32, 1.6), color, Enum.Material.Neon, Enum.PartType.Ball)
		piece(m, "PotionNeck", Vector3.new(0.14, 0.25, 0.14), at(x, 2.6, 1.6), RGB(230, 230, 240), Enum.Material.Glass)
	end
	piece(m, "Chest", Vector3.new(1.2, 0.7, 0.8), at(2, 2.45, 1.6), RGB(120, 70, 35), Enum.Material.Wood)
	piece(m, "ChestLid", Vector3.new(1.25, 0.25, 0.85), at(2, 2.92, 1.6), RGB(140, 85, 40), Enum.Material.Wood)
	piece(m, "ChestBand", Vector3.new(1.27, 0.95, 0.1), at(2, 2.55, 1.6), gold, Enum.Material.Metal)
	piece(m, "ChestGold", Vector3.new(1, 0.15, 0.6), at(2, 2.85, 1.55), RGB(255, 215, 80), Enum.Material.Neon)
	for i = 0, 1 do
		local x = -3.6 + i * 1.3
		piece(m, "Crate", Vector3.new(1.1, 1.1, 1.1), at(x, 1.1 + i * 0.1, -1.6) * CFrame.Angles(0, i * 0.3, 0), vary(woodLight), Enum.Material.WoodPlanks)
		piece(m, "CrateEdge", Vector3.new(1.15, 0.12, 1.15), at(x, 1.65 + i * 0.1, -1.6) * CFrame.Angles(0, i * 0.3, 0), woodDark, Enum.Material.Wood)
	end
	piece(m, "Barrel", Vector3.new(1.5, 1.1, 1.1), at(3.6, 1.3, -1.5) * CFrame.Angles(0, 0, math.rad(90)), wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	for _, y in ipairs({ 0.85, 1.75 }) do
		piece(m, "BarrelHoop", Vector3.new(0.12, 1.15, 1.15), at(3.6, y, -1.5) * CFrame.Angles(0, 0, math.rad(90)), RGB(70, 70, 75), Enum.Material.Metal,
			Enum.PartType.Cylinder)
	end

	-- el mercader (detrás del mostrador, mirando al puente)
	local skin, robe, pants = RGB(240, 195, 150), RGB(95, 45, 150), RGB(55, 45, 60)
	local base = at(0, 0.55, 0.3)
	for _, side in ipairs({ -1, 1 }) do
		piece(m, "Leg", Vector3.new(0.5, 1.3, 0.5), base * CFrame.new(side * 0.3, 0.65, 0), pants)
		piece(m, "Boot", Vector3.new(0.55, 0.35, 0.75), base * CFrame.new(side * 0.3, 0.17, 0.1), RGB(70, 45, 30))
		piece(m, "Arm", Vector3.new(0.45, 1.3, 0.45), base * CFrame.new(side * 0.95, 2.05, 0.15) * CFrame.Angles(math.rad(-25), 0, side * 0.1), robe)
		piece(m, "Hand", Vector3.new(0.4, 0.4, 0.4), base * CFrame.new(side * 1.0, 1.45, 0.5), skin)
	end
	piece(m, "Robe", Vector3.new(1.5, 1.7, 0.9), base * CFrame.new(0, 2.05, 0), robe, Enum.Material.Fabric)
	piece(m, "RobeHem", Vector3.new(1.6, 0.35, 1), base * CFrame.new(0, 1.3, 0), RGB(70, 30, 115), Enum.Material.Fabric)
	piece(m, "Belt", Vector3.new(1.55, 0.25, 0.95), base * CFrame.new(0, 1.75, 0), RGB(80, 50, 30))
	piece(m, "Buckle", Vector3.new(0.35, 0.3, 0.1), base * CFrame.new(0, 1.75, 0.5), gold, Enum.Material.Metal)
	piece(m, "Head", Vector3.new(1, 1, 1), base * CFrame.new(0, 3.4, 0), skin)
	piece(m, "Nose", Vector3.new(0.25, 0.3, 0.25), base * CFrame.new(0, 3.35, 0.55), RGB(230, 170, 130))
	for _, side in ipairs({ -1, 1 }) do
		piece(m, "Eye", Vector3.new(0.15, 0.18, 0.05), base * CFrame.new(side * 0.22, 3.55, 0.5), RGB(30, 30, 35))
		piece(m, "Brow", Vector3.new(0.3, 0.08, 0.05), base * CFrame.new(side * 0.22, 3.72, 0.51) * CFrame.Angles(0, 0, side * -0.2), RGB(235, 235, 235))
	end
	piece(m, "Beard", Vector3.new(0.9, 0.7, 0.3), base * CFrame.new(0, 2.95, 0.42), RGB(240, 240, 240), Enum.Material.Fabric)
	piece(m, "Moustache", Vector3.new(0.75, 0.15, 0.12), base * CFrame.new(0, 3.2, 0.56), RGB(250, 250, 250))
	piece(m, "HatBrim", Vector3.new(0.12, 2.1, 2.1), base * CFrame.new(0, 3.95, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(60, 35, 25), Enum.Material.Fabric,
		Enum.PartType.Cylinder)
	piece(m, "HatCrown", Vector3.new(1.05, 0.8, 1.05), base * CFrame.new(0, 4.35, 0), RGB(75, 45, 30), Enum.Material.Fabric)
	piece(m, "HatBand", Vector3.new(1.1, 0.2, 1.1), base * CFrame.new(0, 4.1, 0), purple, Enum.Material.Fabric)
	piece(m, "Feather", Vector3.new(0.12, 1, 0.3), base * CFrame.new(0.5, 4.6, -0.1) * CFrame.Angles(0, 0, -0.4), RGB(255, 90, 150), Enum.Material.Fabric)
	piece(m, "Backpack", Vector3.new(1.3, 1.6, 0.9), base * CFrame.new(0, 2.3, -0.9), RGB(130, 90, 55), Enum.Material.Fabric)
	piece(m, "Bedroll", Vector3.new(1.6, 0.5, 0.5), base * CFrame.new(0, 3.25, -0.9), RGB(170, 60, 60), Enum.Material.Fabric,
		Enum.PartType.Cylinder)
	piece(m, "Pot", Vector3.new(0.5, 0.4, 0.5), base * CFrame.new(0.5, 1.6, -1.35), RGB(80, 80, 85), Enum.Material.Metal)

	-- todo anclado y sin colisión salvo el casco (para que no estorbe en el puente)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = d.Name == "Keel" or d.Name == "Deck"
			d.CastShadow = d.Size.Magnitude > 2
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MerchantPrompt"
	prompt.ActionText = "Ver ofertas"
	prompt.ObjectText = "🧳 Mercader ambulante"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = top
	counter = top
	m.PrimaryPart = top
	return m
end

-- ===== Abierto / cerrado =====

local function isOpen(now: number): (boolean, number, number)
	local open, visit, nextAt = Merchant.State(now)
	if ALWAYS then
		return true, visit, nextAt
	end
	return open, visit, nextAt
end

local function setOpen(open: boolean)
	if not boat then
		return
	end
	local map = Workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	boat.Parent = if open then (hub or Workspace) else nil
end

local function nearCounter(player: Player): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and counter ~= nil and boat ~= nil and boat.Parent ~= nil
		and (hrp.Position - (counter :: BasePart).Position).Magnitude <= Merchant.Range
end

local function onBuy(player: Player, index: any): any
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.4 then
		return fail("Más despacio")
	end
	lastAction[player] = now
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	local open, visit = isOpen(os.time())
	if not open then
		return fail("🧳 El mercader ya se ha ido. Vuelve cada hora")
	end
	if FishingService.IsFishing(player) then
		return fail("🎣 Termina de pescar primero")
	end
	if not nearCounter(player) then
		return fail("Acércate a la barca del mercader (junto al puente)")
	end
	local offer = type(index) == "number" and Merchant.Offers(visit)[index]
	if not offer then
		return fail("Esa oferta no existe")
	end
	if data.MerchantVisit ~= visit then
		data.MerchantVisit = visit
		data.MerchantBought = {}
	end
	local key = tostring(index)
	local bought = data.MerchantBought[key] or 0
	if bought >= offer.Limit then
		return fail("Ya has comprado todas las que te deja (máx. " .. offer.Limit .. ")")
	end
	if data.MemeCoin < offer.Price then
		return fail("No tienes suficientes MemeCoins")
	end

	local text
	if offer.Kind == "Meme" then
		local meme = Memes.Get(offer.MemeId)
		if not meme then
			return fail("Esa oferta no existe")
		end
		local size = Inventory.SizeOf(offer.Weight)
		if size > Inventory.Free(data) then
			return fail(("🐠 No cabe en tu mochila (ocupa %d kg): descarga en tu parcela"):format(size))
		end
		local id = HttpService:GenerateGUID(false)
		data.Catches[id] = {
			Id = id, MemeId = meme.Id, Weight = offer.Weight, Size = size, Golden = false, Impossible = false,
			Value = FishMath.Value(meme, offer.Weight, false), Time = os.time(), Bought = true,
		}
		text = ("🧳 ¡%s (%s) es tuyo! Está en tu mochila"):format(meme.Name, FishMath.FormatWeight(offer.Weight))
	elseif offer.Kind == "Item" then
		local item = Rods.Items[offer.ItemId]
		if item.Kind == "Gear" and (data.Items[item.Id] or 0) >= 1 then
			return fail("Ya tienes ese objeto")
		end
		data.Items[item.Id] = (data.Items[item.Id] or 0) + 1
		if not table.find(data.EquippedItems, item.Id) and #data.EquippedItems < BoostService.ItemSlots(player) then
			table.insert(data.EquippedItems, item.Id)
		end
		text = ("🧳 +1 %s %s"):format(item.Emoji, item.Name)
	else
		local boost = Boosts.List[offer.BoostId]
		BoostService.Grant(player, boost.Id, boost.Duration)
		text = ("🧳 ¡%s %s activado!"):format(boost.Emoji, boost.Name)
	end
	data.MemeCoin -= offer.Price
	data.MerchantBought[key] = bought + 1
	PlayerData.Push(player)
	return { ok = true, Text = text }
end

function MerchantService.Init()
	Remotes.Get("BuyMerchant").OnServerInvoke = onBuy
	-- la barca amarra en el lado sur del puente, con el mostrador mirando al puente
	boat = buildBoat(CFrame.new(0, GameConfig.River.SurfaceY + 0.2, -9.6))
	local wasOpen: boolean? = nil
	task.spawn(function()
		while true do
			local now = os.time()
			local open, visit, nextAt = isOpen(now)
			Workspace:SetAttribute("MerchantOpen", open)
			Workspace:SetAttribute("MerchantVisit", visit)
			Workspace:SetAttribute("MerchantNext", nextAt)
			if open ~= wasOpen then
				setOpen(open)
				if open and wasOpen ~= nil then
					for _, player in ipairs(Players:GetPlayers()) do
						PlayerData.Notify(player, ("🧳 ¡Ha llegado el MERCADER AMBULANTE al puente! Solo %d minutos"):format(Merchant.Open // 60), "Info")
					end
				end
				wasOpen = open
			end
			task.wait(1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return MerchantService

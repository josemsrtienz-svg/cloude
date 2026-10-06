--[[
	PescaDeMemes • FishingService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > FishingService

	Autoridad total sobre la pesca. Flujo:
	  Cast(power, useReinforced)  → valida y DECIDE aquí qué meme picará, su peso y si es dorado.
	                                Al cliente solo le dice cuánto tarda la picada.
	  Hook()                      → valida que el toque llegó a tiempo. Revela peso estimado,
	                                capacidad, aguante y parámetros de la pelea (no el meme).
	                                Con sobrecarga queda en "Deciding" hasta Engage() (PELEAR).
	  Engage()                    → empieza la pelea (el tiempo de decisión no cuenta).
	  Tug(inGreen)                → resuelve un tirón fuerte (solo si hay sobrecarga).
	  FinishFight(success)        → valida tiempo mínimo y tirones; crea la captura con id único.
	  Release()                   → soltar / cancelar.
	El cliente nunca envía qué meme, cuánto pesa ni cuánto vale.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local Remotes = require(Root.Shared.Remotes)
local FishMath = require(Root.Shared.FishMath)
local Util = require(Root.Shared.Util)
local Inventory = require(Root.Shared.Inventory)

local PlayerData = require(script.Parent.PlayerData)

local F = GameConfig.Fishing
local FishingService = {}

type Session = {
	State: string, -- "Waiting" | "Deciding" | "Fighting"
	CastAt: number,
	BiteAt: number,
	Meme: any,
	Weight: number,
	Golden: boolean,
	Ratio: number,
	Survival: number,
	Params: { [string]: number }?,
	FightStart: number,
	TugsRequired: number,
	TugsDone: number,
	LastTugAt: number,
}

local sessions: { [Player]: Session } = {}
local lastCast: { [Player]: number } = {}
local rng = Random.new()

local function fail(err: string): any
	return { ok = false, err = err }
end

local ZONE = 1 -- el prototipo solo tiene la Charca del Noob

local function rollRarity(luck: number): string
	local total = 0
	local weights = {}
	for _, id in ipairs(Memes.RarityOrder) do
		local rarity = Memes.Rarities[id]
		local w = rarity.Odds * (luck ^ (rarity.Order - 1))
		-- solo rarezas que existen en esta zona
		if #Memes.InZone(ZONE, id) == 0 then
			w = 0
		end
		weights[id] = w
		total += w
	end
	local roll = rng:NextNumber() * total
	for _, id in ipairs(Memes.RarityOrder) do
		roll -= weights[id]
		if roll <= 0 and weights[id] > 0 then
			return id
		end
	end
	return "COMMON"
end

local function rollWeight(meme: any): number
	-- más ejemplares pequeños que gigantes
	local u = rng:NextNumber() ^ 2.2
	local w = meme.WeightMin + (meme.WeightMax - meme.WeightMin) * u
	return math.floor(w * 10 + 0.5) / 10
end

local function nearPond(player: Player): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local offset = hrp.Position - GameConfig.Pond.Center
	return Vector2.new(offset.X, offset.Z).Magnitude <= GameConfig.Pond.FishingRadius and math.abs(offset.Y) < 40
end

local function addXP(data: any, amount: number): boolean
	data.XP += amount
	local leveled = false
	while data.XP >= GameConfig.XPForLevel(data.Level) do
		data.XP -= GameConfig.XPForLevel(data.Level)
		data.Level += 1
		leveled = true
	end
	return leveled
end

-- ===== Caña visible en la mano (la ven todos los jugadores) =====
local function buildRod(character: Model, rod: any)
	local old = character:FindFirstChild("FishingRod")
	if old then
		old:Destroy()
	end
	local hand: BasePart? = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: any
	if not hand then
		return
	end
	local gripOffset = if hand.Name == "RightHand" then CFrame.new(0, -0.15, 0) else CFrame.new(0, -0.9, 0)
	-- la caña apunta hacia delante y hacia arriba; el eje X de los cilindros sigue la caña
	local dir = Vector3.new(0, math.sin(math.rad(40)), -math.cos(math.rad(40)))
	local base = hand.CFrame * gripOffset * CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, math.pi / 2, 0)

	local model = Instance.new("Model")
	model.Name = "FishingRod"
	local function part(name: string, size: Vector3, offset: number, color: Color3, material: Enum.Material): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = base * CFrame.new(offset, 0, 0)
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	local length = 7
	part("Grip", Vector3.new(1.6, 0.32, 0.32), 0, Color3.fromRGB(40, 32, 30), Enum.Material.Fabric)
	local reel = part("Reel", Vector3.new(0.3, 0.6, 0.6), 0.35, Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	reel.CFrame = reel.CFrame * CFrame.new(0, -0.35, 0)
	local shaft = part("Shaft", Vector3.new(length, 0.16, 0.16), 0.8 + length / 2, rod.Color, Enum.Material.SmoothPlastic)
	local tip = Instance.new("Attachment")
	tip.Name = "RodTip"
	tip.Position = Vector3.new(length / 2, 0, 0)
	tip.Parent = shaft
	model.Parent = character
end

local function refreshRod(player: Player)
	local data = PlayerData.Get(player)
	local character = player.Character
	if data and character then
		buildRod(character, Rods.Get(data.EquippedRod) or Rods.List[1])
	end
end
FishingService.RefreshRod = refreshRod

-- ===== Remotes =====

local function onCast(player: Player, power: any, useReinforced: any): any
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	local now = os.clock()
	if lastCast[player] and now - lastCast[player] < F.CastCooldown then
		return fail("Espera un momento")
	end
	local current = sessions[player]
	if current and now - current.CastAt < F.SessionTimeout + F.FightTimeout then
		return fail("Ya estás pescando")
	end
	if type(power) ~= "number" or power ~= power then
		return fail("Lanzamiento inválido")
	end
	if not nearPond(player) then
		return fail("Acércate al agua para pescar")
	end
	local carrying = player:GetAttribute("Carrying")
	if type(carrying) == "string" and carrying ~= "" then
		return fail("🏠 Primero lleva el meme a tu parcela (o guárdalo en la mochila)")
	end
	if Inventory.BackpackCount(data) >= GameConfig.MaxBackpack then
		return fail("🎒 Mochila llena: vende o pon memes en tu parcela")
	end
	lastCast[player] = now
	power = math.clamp(power, 0, 1)

	local rod = Rods.Get(data.EquippedRod) or Rods.List[1]
	local reinforced = false
	if useReinforced == true and data.Items.SedalReforzado > 0 then
		data.Items.SedalReforzado -= 1
		reinforced = true
		PlayerData.Push(player)
	end

	local perfect = power >= F.PerfectPower.Min and power <= F.PerfectPower.Max
	local luck = rod.Luck * (1 + 0.4 * power) * (if perfect then 1.1 else 1)
	local rarityId = rollRarity(luck)
	local pool = Memes.InZone(ZONE, rarityId)
	local meme = pool[rng:NextInteger(1, #pool)]
	local weight = rollWeight(meme)
	local capacity = rod.Capacity * (if reinforced then 1 + Rods.Items.SedalReforzado.CapacityBonus else 1)
	local ratio = weight / capacity
	local delay = rng:NextNumber(F.BiteDelay.Min, F.BiteDelay.Max)

	sessions[player] = {
		State = "Waiting",
		CastAt = now,
		BiteAt = now + delay,
		Meme = meme,
		Weight = weight,
		Golden = rng:NextNumber() < F.GoldenChance,
		Ratio = ratio,
		Survival = FishMath.Survival(ratio),
		Params = nil,
		FightStart = 0,
		TugsRequired = if ratio > 1 then F.TugCount else 0,
		TugsDone = 0,
		LastTugAt = 0,
	}
	return { ok = true, BiteDelay = delay, Perfect = perfect, Reinforced = reinforced, Capacity = capacity }
end

local function onHook(player: Player): any
	local session = sessions[player]
	if not session or session.State ~= "Waiting" then
		return fail("No hay nada picando")
	end
	local now = os.clock()
	if now < session.BiteAt - 0.05 then
		sessions[player] = nil
		return { ok = false, err = "¡Demasiado pronto! Se ha asustado.", Lost = true }
	end
	if now > session.BiteAt + F.HookWindow + F.HookServerGrace then
		sessions[player] = nil
		return { ok = false, err = "¡Demasiado tarde! Se ha escapado.", Lost = true }
	end

	local data = PlayerData.Get(player)
	local rod = Rods.Get(data and data.EquippedRod) or Rods.List[1]
	local meme = session.Meme
	local estimate = session.Weight * rng:NextNumber(0.9, 1.1)
	local info = {
		ok = true,
		Rarity = meme.Rarity,
		Personality = meme.Personality,
		Known = data ~= nil and data.Discovered[meme.Id] ~= nil,
		MemeId = nil :: string?,
		EstimatedWeight = math.floor(estimate * 10 + 0.5) / 10,
		Capacity = session.Weight / session.Ratio,
		Survival = session.Survival,
		Snapped = false,
	}
	-- solo se revela qué meme es si ya lo has pescado antes (bestiario)
	if info.Known then
		info.MemeId = meme.Id
	end

	if session.Ratio > F.MaxOverload then
		sessions[player] = nil
		info.Snapped = true
		return info
	end

	local params = FishMath.FightParams(meme, rod, session.Ratio)
	session.Params = params
	-- con sobrecarga se espera a PELEAR (Engage) o SOLTAR (Release); FightStart caduca la decisión
	session.State = if session.Ratio > 1 then "Deciding" else "Fighting"
	session.FightStart = now
	info.Params = params
	info.Tugs = session.TugsRequired
	return info
end

local function onEngage(player: Player): any
	local session = sessions[player]
	if not session or session.State ~= "Deciding" then
		return fail("No hay nada que pelear")
	end
	if os.clock() - session.FightStart > F.FightTimeout then
		sessions[player] = nil
		return fail("Se cansó de esperar y se fue")
	end
	session.State = "Fighting"
	session.FightStart = os.clock()
	return { ok = true }
end

local function onTug(player: Player, inGreen: any): any
	local session = sessions[player]
	if not session or session.State ~= "Fighting" then
		return fail("No hay pelea")
	end
	local now = os.clock()
	if session.TugsDone >= session.TugsRequired then
		return fail("No quedan tirones")
	end
	if now - session.FightStart < 0.5 or now - session.LastTugAt < 0.4 then
		return fail("Demasiado rápido")
	end
	session.TugsDone += 1
	session.LastTugAt = now
	local chance = FishMath.TugChance(session.Survival, inGreen == true)
	if rng:NextNumber() < chance then
		return { ok = true, Survived = true, Remaining = session.TugsRequired - session.TugsDone }
	end
	sessions[player] = nil
	return { ok = true, Survived = false }
end

local function onFinish(player: Player, success: any): any
	local session = sessions[player]
	if not session or session.State ~= "Fighting" or not session.Params then
		return fail("No hay pelea")
	end
	sessions[player] = nil
	if success ~= true then
		return { ok = true, Escaped = true }
	end
	local now = os.clock()
	local elapsed = now - session.FightStart
	if elapsed < FishMath.MinFightTime(session.Params.FillRate) then
		warn(("[PescaDeMemes] %s terminó una pelea demasiado rápido (%.2fs)"):format(player.Name, elapsed))
		return fail("Pelea inválida")
	end
	if elapsed > F.FightTimeout then
		return fail("Se cansó de esperar y se fue")
	end
	if session.TugsDone < session.TugsRequired then
		return fail("Pelea inválida")
	end

	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	local meme = session.Meme
	local catch = {
		Id = HttpService:GenerateGUID(false),
		MemeId = meme.Id,
		Weight = session.Weight,
		Golden = session.Golden,
		Impossible = session.Ratio > 1,
		Value = FishMath.Value(meme, session.Weight, session.Golden),
		Time = os.time(),
	}
	data.Catches[catch.Id] = catch

	local entry = data.Discovered[meme.Id]
	local firstTime = entry == nil
	if firstTime then
		entry = { Count = 0, Heaviest = 0 }
		data.Discovered[meme.Id] = entry
	end
	entry.Count += 1
	entry.Heaviest = math.max(entry.Heaviest, catch.Weight)
	data.Stats.TotalCatches += 1
	data.Stats.Heaviest = math.max(data.Stats.Heaviest, catch.Weight)
	if catch.Impossible then
		data.Stats.Impossible += 1
	end

	local rarity = Memes.Rarities[meme.Rarity]
	local xp = rarity.XP * (if firstTime then 3 else 1) * (if catch.Impossible then 2 else 1)
	local leveled = addXP(data, xp)
	PlayerData.Push(player)

	-- aviso a todo el servidor en capturas épicas
	local sizeName = FishMath.SizeName(FishMath.Fraction(meme, catch.Weight))
	local text = nil
	if catch.Impossible and session.Ratio >= 1.5 then
		local rod = Rods.Get(data.EquippedRod) or Rods.List[1]
		text = ("🏆 ¡%s pescó %s de %s con una %s! (IMPOSIBLE)"):format(player.DisplayName, meme.Name, FishMath.FormatWeight(catch.Weight), rod.Name)
	elseif rarity.Order >= 4 or catch.Golden then
		text = ("✨ ¡%s ha pescado %s%s %s (%s)!"):format(player.DisplayName, if catch.Golden then "un DORADO " else "", meme.Name, sizeName, FishMath.FormatWeight(catch.Weight))
	end
	if text then
		Remotes.Get("Announce"):FireAllClients(text, meme.Rarity)
	end
	if rarity.Order >= 4 or catch.Impossible then
		task.spawn(PlayerData.SaveNow, player)
	end

	return { ok = true, Catch = Util.deepCopy(catch), FirstTime = firstTime, LevelUp = leveled, XP = xp }
end

-- Una sesión abandonada (sin Release ni Finish) caduca igual que en onCast.
function FishingService.IsFishing(player: Player): boolean
	local session = sessions[player]
	if session and os.clock() - session.CastAt >= F.SessionTimeout + F.FightTimeout then
		sessions[player] = nil
		return false
	end
	return session ~= nil
end

local function onRelease(player: Player): any
	sessions[player] = nil
	return { ok = true }
end

function FishingService.Init()
	Remotes.Get("Cast").OnServerInvoke = onCast
	Remotes.Get("Hook").OnServerInvoke = onHook
	Remotes.Get("Engage").OnServerInvoke = onEngage
	Remotes.Get("Tug").OnServerInvoke = onTug
	Remotes.Get("FinishFight").OnServerInvoke = onFinish
	Remotes.Get("Release").OnServerInvoke = onRelease

	local function onCharacter(player: Player, character: Model)
		sessions[player] = nil
		character:WaitForChild("Humanoid")
		task.wait(0.2) -- deja que el avatar termine de montarse
		if player.Character == character and PlayerData.IsLoaded(player) then
			refreshRod(player)
		end
	end
	local function onPlayer(player: Player)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	-- si los datos tardan en cargar, la caña aparece en cuanto llegan
	PlayerData.Loaded:Connect(function(player)
		local character = player.Character
		if character and not character:FindFirstChild("FishingRod") then
			refreshRod(player)
		end
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		lastCast[player] = nil
	end)
end

return FishingService

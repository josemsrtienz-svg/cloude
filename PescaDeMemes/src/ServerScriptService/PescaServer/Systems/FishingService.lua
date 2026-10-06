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
	  ResolvePending(action)      → captura ganada que no cabe en el acuario: "sell" o soltar.
	Requisitos para lanzar: caña en la mano, estar al final de TU muelle, caña sin romper y sitio en el acuario.
	Fallar un TIRÓN con sobrecarga ROMPE la caña (salvo la de palo).
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
local GearService = require(script.Parent.GearService)

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
-- captura ganada que no cabía en el acuario: el jugador decide venderla o soltarla
local pending: { [Player]: any } = {}

-- Una captura pendiente que el jugador no resolvió (lanzó otra vez, reapareció o se fue) se VENDE sola:
-- así nunca se pierde un dorado o un mítico.
local function autoSellPending(player: Player)
	local catch = pending[player]
	pending[player] = nil
	local data = catch and PlayerData.Get(player)
	if catch and data then
		data.MemeCoin += catch.Value
		PlayerData.Push(player)
		PlayerData.Notify(player, ("💰 No cabía en tu acuario: se vendió solo por %d MemeCoins"):format(catch.Value), "Info")
	end
end
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

-- Solo se pesca desde el final de TU muelle, con la caña en la mano.
local function onOwnDock(player: Player): (boolean, string?)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not hrp or not humanoid or humanoid.Health <= 0 then
		return false, "Sin personaje"
	end
	if not character:FindFirstChild(GearService.ToolName) then
		return false, "🎣 Saca la caña (tecla 1) para pescar"
	end
	local index = player:GetAttribute("PlotIndex")
	if type(index) ~= "number" or index < 1 then
		return false, "No tienes parcela (ni muelle) en este servidor"
	end
	local spot = GameConfig.DockSpot(index)
	local offset = hrp.Position - spot
	if Vector2.new(offset.X, offset.Z).Magnitude > GameConfig.Plots.FishingRange or math.abs(offset.Y) > 15 then
		return false, "🚶 Ve al final de TU muelle para pescar"
	end
	return true, nil
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
	local onDock, dockErr = onOwnDock(player)
	if not onDock then
		return fail(dockErr or "No puedes pescar aquí")
	end
	if data.BrokenRods[data.EquippedRod] then
		return fail("💥 Tu caña está rota: repárala en la tienda o equipa otra")
	end
	if Inventory.Free(data) < 1 then
		return fail("🐠 Tu acuario está lleno: vuelve a tu parcela para descargarlo")
	end
	autoSellPending(player) -- una captura que no cabía y no se resolvió, se vende sola
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
	-- fallar un TIRÓN con sobrecarga rompe la caña (salvo la de palo, que es irrompible)
	local data = PlayerData.Get(player)
	local rod = data and Rods.Get(data.EquippedRod)
	if data and rod and rod.RepairCost > 0 then
		data.BrokenRods[rod.Id] = true
		data.EquippedRod = "Palo"
		PlayerData.Push(player)
		GearService.Refresh(player)
		return { ok = true, Survived = false, Broke = true, RodName = rod.Name }
	end
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
		Size = Inventory.SizeOf(session.Weight),
		Golden = session.Golden,
		Impossible = session.Ratio > 1,
		Value = FishMath.Value(meme, session.Weight, session.Golden),
		Time = os.time(),
	}
	-- si no cabe en la mochila-acuario, queda pendiente: venderla ya o soltarla
	local fits = catch.Size <= Inventory.Free(data)
	if fits then
		data.Catches[catch.Id] = catch
	else
		pending[player] = catch
	end

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

	return { ok = true, Catch = Util.deepCopy(catch), FirstTime = firstTime, LevelUp = leveled, XP = xp, NoSpace = not fits }
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

-- Captura que no cabía: "sell" la vende al momento, cualquier otra cosa la suelta al agua.
local function onResolvePending(player: Player, action: any): any
	local catch = pending[player]
	pending[player] = nil
	if not catch then
		return fail("No hay nada pendiente")
	end
	if action ~= "sell" then
		return { ok = true, Released = true }
	end
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	data.MemeCoin += catch.Value
	PlayerData.Push(player)
	return { ok = true, Earned = catch.Value }
end

function FishingService.Init()
	Remotes.Get("Cast").OnServerInvoke = onCast
	Remotes.Get("Hook").OnServerInvoke = onHook
	Remotes.Get("Engage").OnServerInvoke = onEngage
	Remotes.Get("Tug").OnServerInvoke = onTug
	Remotes.Get("FinishFight").OnServerInvoke = onFinish
	Remotes.Get("Release").OnServerInvoke = onRelease
	Remotes.Get("ResolvePending").OnServerInvoke = onResolvePending

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			sessions[player] = nil
			autoSellPending(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		autoSellPending(player) -- PlayerData guarda en un task.defer, así que esto entra en el guardado final
		lastCast[player] = nil
	end)
end

return FishingService

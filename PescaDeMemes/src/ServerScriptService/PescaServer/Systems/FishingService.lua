--[[
	PescaDeMemes • FishingService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > FishingService

	Autoridad total sobre la pesca. Flujo v0.4 (INMERSIÓN):
	  Cast(power, useReinforced) → valida y GENERA aquí la inmersión: qué memes hay, a qué profundidad,
	                               cuánto pesa cada uno y si es dorado. El cliente solo la dibuja.
	  Grab(index)                → el anzuelo toca un meme. Se valida que el anzuelo PUEDE estar a esa
	                               profundidad (baja a velocidad fija), que quedan anzuelos y que cabe en
	                               el acuario. Si pesa ≤ tu caña se engancha; si pesa más → "Deciding".
	  Engage()                   → PELEAR (el tiempo de decisión y de pelea no cuenta para la bajada).
	  Release()                  → SOLTAR ese meme y seguir bajando.
	  Tug(inGreen)               → resuelve un tirón fuerte. Fallarlo ROMPE la caña (salvo la de palo).
	  FinishFight(success)       → ganar = enganchado y sigues bajando; perder = el sedal sube de golpe
	                               y la inmersión termina (te llevas lo que ya tenías enganchado).
	  Surface()                  → subir: los memes enganchados entran en tu mochila-acuario.
	Requisitos para lanzar: caña en la mano, estar al final de TU muelle, caña sin romper y sitio en el acuario.
	El cliente nunca envía qué meme, cuánto pesa ni cuánto vale: solo el índice del que ha tocado.
	Una inmersión abandonada (muerte, salida, timeout) se cierra sola y se guarda lo enganchado.
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
local BoostService = require(script.Parent.BoostService)

local F = GameConfig.Fishing
local D = GameConfig.Dive
local FishingService = {}

type DiveMeme = {
	Meme: any,
	Weight: number,
	Golden: boolean,
	Depth: number,
	X: number,
	Amp: number,
	Freq: number,
	Phase: number,
	Ratio: number,
	Size: number,
	Taken: boolean,
}

type Session = {
	State: string, -- "Diving" | "Deciding" | "Fighting"
	CastAt: number,
	DiveStart: number,
	Paused: number, -- segundos acumulados de decisión/pelea (el anzuelo no baja)
	PauseAt: number?,
	Rod: any,
	Capacity: number,
	Hooks: number,
	MaxDepth: number,
	Speed: number,
	Memes: { DiveMeme },
	Grabbed: { number },
	UsedSize: number,
	HookX: number, -- última x (m) del anzuelo aceptada y cuándo (límite de velocidad lateral)
	HookXAt: number,
	-- pelea en curso
	Current: number?,
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

local ZONE = 1 -- el prototipo solo tiene la Charca del Noob

local function fail(err: string): any
	return { ok = false, err = err }
end

-- ¿Hay algún meme de esa rareza que viva a esa profundidad?
local function existsAt(rarityId: string, depth: number): boolean
	for _, meme in ipairs(Memes.InZone(ZONE, rarityId)) do
		if (meme.MinDepth or 0) <= depth then
			return true
		end
	end
	return false
end

-- luck sube las rarezas altas de forma exponencial (caña, fuerza, profundidad); boost es un multiplicador
-- LINEAL sobre Raro o más (boost ×1.5 = de verdad 1,5 veces más memes raros, no 11 veces más secretos).
local function rollRarity(luck: number, depth: number, boost: number): string
	local total = 0
	local weights = {}
	for _, id in ipairs(Memes.RarityOrder) do
		local rarity = Memes.Rarities[id]
		local w = rarity.Odds * (luck ^ (rarity.Order - 1)) * (if rarity.Order >= 3 then boost else 1)
		-- solo rarezas que existen en esta zona y a esta profundidad
		if not existsAt(id, depth) then
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

-- Meme de esa rareza que viva a esa profundidad (MinDepth). Si no hay ninguno tan arriba,
-- baja de rareza hasta encontrar uno: los memes difíciles solo aparecen en el fondo.
local function pickMeme(rarityId: string, depth: number): any
	local order = Memes.Rarities[rarityId].Order
	for o = order, 1, -1 do
		local id = Memes.RarityOrder[o]
		local candidates = {}
		for _, meme in ipairs(Memes.InZone(ZONE, id)) do
			if (meme.MinDepth or 0) <= depth then
				table.insert(candidates, meme)
			end
		end
		if #candidates > 0 then
			return candidates[rng:NextInteger(1, #candidates)]
		end
	end
	return Memes.List[1]
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

-- Segundos que lleva bajando el anzuelo (sin contar decisiones ni peleas).
local function diveTime(session: Session, now: number): number
	local paused = session.Paused + (if session.PauseAt then now - session.PauseAt else 0)
	return now - session.DiveStart - paused
end

local function pause(session: Session, now: number)
	if not session.PauseAt then
		session.PauseAt = now
	end
end

local function resume(session: Session, now: number)
	if session.PauseAt then
		session.Paused += now - session.PauseAt
		session.PauseAt = nil
	end
	session.State = "Diving"
	session.Current = nil
	session.Params = nil
end

-- Genera los memes de la columna de agua. Más hondo = más suerte (rarezas altas abajo).
local function generateDive(rod: any, power: number, perfect: boolean, capacity: number, luckBoost: number): { DiveMeme }
	local list: { DiveMeme } = {}
	local span = rod.MaxDepth - D.StartDepth - 0.5
	local count = math.clamp(math.floor(rod.MaxDepth / rod.DiveSpeed * D.MemesPerSecond), 6, D.MaxMemes)
	local baseLuck = rod.Luck * (1 + 0.4 * power) * (if perfect then 1.1 else 1)
	for i = 1, count do
		-- muestreo estratificado: repartidos por toda la profundidad, sin huecos enormes
		local depth = D.StartDepth + span * (i - rng:NextNumber(0.1, 0.9)) / count
		local luck = baseLuck * (1 + D.DepthLuck * depth / D.MaxWorldDepth)
		local meme = pickMeme(rollRarity(luck, depth, luckBoost), depth)
		local weight = rollWeight(meme)
		local lane = D.LaneHalfWidth - 1
		table.insert(list, {
			Meme = meme,
			Weight = weight,
			Golden = rng:NextNumber() < F.GoldenChance,
			Depth = math.floor(depth * 10 + 0.5) / 10,
			X = rng:NextNumber(-lane, lane),
			Amp = rng:NextNumber(0, 2.5),
			Freq = rng:NextNumber(0.4, 1.1),
			Phase = rng:NextNumber(0, math.pi * 2),
			Ratio = weight / capacity,
			Size = Inventory.SizeOf(weight),
			Taken = false,
		})
	end
	return list
end

-- Cierra la inmersión: lo enganchado entra en la mochila-acuario. Devuelve el resumen para el cliente.
local function surface(player: Player): any
	local session = sessions[player]
	sessions[player] = nil
	local data = PlayerData.Get(player)
	if not session or not data then
		return { ok = true, Catches = {}, NewIds = {}, XP = 0 }
	end
	local catches = {}
	local newIds = {}
	local totalXP = 0
	local leveled = false
	local soldValue = 0
	local autoSoldValue = 0
	for _, index in ipairs(session.Grabbed) do
		local spec = session.Memes[index]
		local meme = spec.Meme
		local catch = {
			Id = HttpService:GenerateGUID(false),
			MemeId = meme.Id,
			Weight = spec.Weight,
			Size = spec.Size,
			Golden = spec.Golden,
			Impossible = spec.Ratio > 1,
			Value = FishMath.Value(meme, spec.Weight, spec.Golden),
			Time = os.time(),
		}
		-- Grab ya comprobó el sitio; si mientras tanto se llenó (no debería), se vende solo
		local sold = false
		local autoSell = data.Settings.AutoSell[meme.Rarity] == true and not catch.Golden -- los dorados nunca se venden solos
		if autoSell then
			-- filtro de venta automática: se vende al subir (con el multiplicador de dinero)
			local earned = math.floor(catch.Value * BoostService.Money(player))
			data.MemeCoin += earned
			autoSoldValue += earned
			sold = true
		elseif catch.Size <= Inventory.Free(data) then
			data.Catches[catch.Id] = catch
		else
			soldValue += catch.Value
			sold = true
		end

		local entry = data.Discovered[meme.Id]
		if entry == nil then
			entry = { Count = 0, Heaviest = 0 }
			data.Discovered[meme.Id] = entry
			table.insert(newIds, meme.Id)
		end
		entry.Count += 1
		entry.Heaviest = math.max(entry.Heaviest, catch.Weight)
		data.Stats.TotalCatches += 1
		data.Stats.Heaviest = math.max(data.Stats.Heaviest, catch.Weight)
		if catch.Impossible then
			data.Stats.Impossible += 1
		end
		local rarity = Memes.Rarities[meme.Rarity]
		local firstTime = table.find(newIds, meme.Id) ~= nil and entry.Count == 1
		local xp = rarity.XP * (if firstTime then 3 else 1) * (if catch.Impossible then 2 else 1)
		totalXP += xp
		leveled = addXP(data, xp) or leveled
		local copy = Util.deepCopy(catch)
		copy.Sold = sold -- la tarjeta no ofrece "Vender" para lo que ya se vendió solo
		copy.AutoSold = autoSell
		table.insert(catches, copy)

		-- aviso a todo el servidor en capturas épicas
		local text = nil
		if catch.Impossible and spec.Ratio >= 1.5 then
			text = ("🏆 ¡%s pescó %s de %s con una %s! (IMPOSIBLE)"):format(player.DisplayName, meme.Name,
				FishMath.FormatWeight(catch.Weight), session.Rod.Name)
		elseif rarity.Order >= 4 or catch.Golden then
			local sizeName = FishMath.SizeName(FishMath.Fraction(meme, catch.Weight))
			text = ("✨ ¡%s ha pescado %s%s %s (%s)!"):format(player.DisplayName, if catch.Golden then "un DORADO " else "",
				meme.Name, sizeName, FishMath.FormatWeight(catch.Weight))
		end
		if text then
			Remotes.Get("Announce"):FireAllClients(text, meme.Rarity)
		end
	end
	if soldValue > 0 then
		data.MemeCoin += soldValue
		PlayerData.Notify(player, ("💰 No cabía en tu acuario: se vendió solo por %d MemeCoins"):format(soldValue), "Info")
	end
	if autoSoldValue > 0 then
		PlayerData.Notify(player, ("💰 Venta automática: +%s MemeCoins"):format(Util.formatShort(autoSoldValue)), "Success")
	end
	if #catches > 0 then
		PlayerData.Push(player)
		-- guardado inmediato si hay algo que duele perder (épico o más, o un IMPOSIBLE)
		local important = false
		for _, c in ipairs(catches) do
			important = important or Memes.GetRarity(c.MemeId).Order >= 4 or c.Impossible
		end
		if important then
			task.spawn(PlayerData.SaveNow, player)
		end
	end
	return { ok = true, Catches = catches, NewIds = newIds, XP = totalXP, LevelUp = leveled }
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
	if FishingService.IsFishing(player) then
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
	-- con el acuario lleno solo se puede pescar si hay rarezas que se venden solas (no ocupan sitio)
	if Inventory.Free(data) < 1 and next(data.Settings.AutoSell) == nil then
		return fail("🐠 Tu acuario está lleno: vuelve a tu parcela para descargarlo")
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
	local capacity = rod.Capacity * (if reinforced then 1 + Rods.Items.SedalReforzado.CapacityBonus else 1)
	local memes = generateDive(rod, power, perfect, capacity, BoostService.Luck(player))
	local hooks = rod.Hooks + BoostService.ExtraHooks(player)
	local speed = rod.DiveSpeed * BoostService.Speed(player)

	sessions[player] = {
		State = "Diving",
		CastAt = now,
		DiveStart = now + D.IntroTime,
		Paused = 0,
		PauseAt = nil,
		Rod = rod,
		Capacity = capacity,
		Hooks = hooks,
		MaxDepth = rod.MaxDepth,
		Speed = speed,
		Memes = memes,
		Grabbed = {},
		UsedSize = 0,
		HookX = 0,
		HookXAt = now + D.IntroTime,
		Current = nil,
		Survival = 1,
		Params = nil,
		FightStart = 0,
		TugsRequired = 0,
		TugsDone = 0,
		LastTugAt = 0,
	}

	-- al cliente solo lo que necesita para dibujar la inmersión
	local visible = {}
	for i, spec in ipairs(memes) do
		visible[i] = { MemeId = spec.Meme.Id, Weight = spec.Weight, Golden = spec.Golden, Depth = spec.Depth,
			X = spec.X, Amp = spec.Amp, Freq = spec.Freq, Phase = spec.Phase }
	end
	return {
		ok = true,
		Perfect = perfect,
		Reinforced = reinforced,
		Capacity = capacity,
		Hooks = hooks,
		MaxDepth = rod.MaxDepth,
		Speed = speed,
		IntroTime = D.IntroTime,
		Free = Inventory.Free(data),
		Memes = visible,
	}
end

local function onGrab(player: Player, index: any, hookX: any): any
	local session = sessions[player]
	if not session or session.State ~= "Diving" then
		return fail("No estás buceando")
	end
	if type(index) ~= "number" or index % 1 ~= 0 then
		return fail("Meme inválido")
	end
	if type(hookX) ~= "number" or hookX ~= hookX or math.abs(hookX) > D.LaneHalfWidth + 0.01 then
		return fail("Anzuelo inválido")
	end
	local spec = session.Memes[index]
	if not spec or spec.Taken then
		return fail("Ese meme ya no está")
	end
	if #session.Grabbed >= session.Hooks then
		return fail("No te quedan anzuelos")
	end
	-- ¿puede estar el anzuelo a esa profundidad ahora? (baja a velocidad fija desde DiveStart)
	local now = os.clock()
	local t = diveTime(session, now)
	local earliest = (spec.Depth - D.GrabRadius) / session.Speed - D.GrabEarly
	local latest = (spec.Depth + D.GrabRadius) / session.Speed + D.GrabLate
	local nearBottom = spec.Depth >= session.MaxDepth - D.GrabRadius
	if t < earliest or (t > latest and not nearBottom) then
		return fail("El anzuelo no está ahí")
	end
	if t > D.Timeout then
		return fail("Se acabó el tiempo")
	end
	-- ¿puede estar el anzuelo en esa x? (se mueve de lado a velocidad limitada desde la última x aceptada)
	local travel = D.SteerSpeed * math.max(0, now - session.HookXAt) + D.GrabSlack
	if math.abs(hookX - session.HookX) > travel then
		return fail("El anzuelo no está ahí")
	end
	-- ¿y el meme está cerca de esa x? (el servidor calcula dónde nada con su propio reloj)
	if math.abs(FishMath.SwimX(spec, t) - hookX) > D.GrabRadius + D.GrabSlack then
		return fail("El anzuelo no está ahí")
	end
	session.HookX = hookX
	session.HookXAt = now
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	if spec.Ratio > F.MaxOverload then
		return fail("⛔ Demasiado pesado para tu caña")
	end
	if data.Settings.CatchSkip[spec.Meme.Rarity] then
		return fail("🚫 Filtrado: tu anzuelo ignora esa rareza")
	end
	-- lo que se vende solo al subir no ocupa sitio en el acuario (los dorados nunca se venden solos)
	local autoSell = data.Settings.AutoSell[spec.Meme.Rarity] == true and not spec.Golden
	if not autoSell and spec.Size > Inventory.Free(data) - session.UsedSize then
		return fail("🐠 No cabe en tu acuario")
	end

	if spec.Ratio <= 1 then
		spec.Taken = true
		session.UsedSize += if autoSell then 0 else spec.Size
		table.insert(session.Grabbed, index)
		return { ok = true, Grabbed = true, Count = #session.Grabbed }
	end

	-- pesa más que tu caña: el anzuelo se para y toca decidir PELEAR o SOLTAR
	pause(session, now)
	session.State = "Deciding"
	session.Current = index
	session.Survival = FishMath.Survival(spec.Ratio)
	session.Params = FishMath.FightParams(spec.Meme, session.Rod, spec.Ratio)
	session.FightStart = now
	session.TugsRequired = F.TugCount
	session.TugsDone = 0
	session.LastTugAt = 0
	local estimate = spec.Weight * rng:NextNumber(0.95, 1.05)
	return {
		ok = true,
		Fight = true,
		MemeId = spec.Meme.Id,
		Rarity = spec.Meme.Rarity,
		Personality = spec.Meme.Personality,
		EstimatedWeight = math.floor(estimate * 10 + 0.5) / 10,
		Capacity = session.Capacity,
		Survival = session.Survival,
		Params = session.Params,
		Tugs = session.TugsRequired,
	}
end

local function onEngage(player: Player): any
	local session = sessions[player]
	if not session or session.State ~= "Deciding" then
		return fail("No hay nada que pelear")
	end
	if os.clock() - session.FightStart > F.FightTimeout then
		resume(session, os.clock())
		return fail("Se cansó de esperar y se fue")
	end
	session.State = "Fighting"
	session.FightStart = os.clock()
	return { ok = true }
end

-- SOLTAR (antes de pelear): el meme se va y el anzuelo sigue bajando.
-- Una vez empezada la pelea ya no se puede soltar gratis: rendirse cuenta como perder (FinishFight false).
local function onRelease(player: Player): any
	local session = sessions[player]
	if not session or session.State ~= "Deciding" then
		return fail("No hay nada que soltar")
	end
	local spec = session.Current and session.Memes[session.Current]
	if spec then
		spec.Taken = true
	end
	resume(session, os.clock())
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
	-- tirón perdido: el sedal sube de golpe (fin de la inmersión) y la caña se ROMPE salvo la de palo
	local data = PlayerData.Get(player)
	local rod = session.Rod
	local broke = false
	if data and rod.RepairCost > 0 then
		data.BrokenRods[rod.Id] = true
		data.EquippedRod = "Palo"
		broke = true
	end
	local summary = surface(player)
	if broke and data then
		PlayerData.Push(player)
		GearService.Refresh(player)
	end
	return { ok = true, Survived = false, Broke = broke, RodName = rod.Name, Summary = summary }
end

local function onFinish(player: Player, success: any): any
	local session = sessions[player]
	if not session or session.State ~= "Fighting" or not session.Params or not session.Current then
		return fail("No hay pelea")
	end
	local spec = session.Memes[session.Current]
	spec.Taken = true
	if success ~= true then
		-- perdiste la pelea: el sedal sube de golpe con lo que ya tenías. Si quedaban TIRONES, el sedal
		-- se juega uno: así rendirse a mitad de pelea no evita el riesgo de romper la caña.
		local broke = false
		local rod = session.Rod
		local data = PlayerData.Get(player)
		if data and rod.RepairCost > 0 and session.TugsDone < session.TugsRequired
			and rng:NextNumber() >= FishMath.TugChance(session.Survival, false) then
			data.BrokenRods[rod.Id] = true
			data.EquippedRod = "Palo"
			broke = true
		end
		local summary = surface(player)
		if broke and data then
			PlayerData.Push(player)
			GearService.Refresh(player)
		end
		return { ok = true, Escaped = true, Broke = broke, RodName = rod.Name, Summary = summary }
	end
	local now = os.clock()
	local elapsed = now - session.FightStart
	if elapsed < FishMath.MinFightTime(session.Params.FillRate) or session.TugsDone < session.TugsRequired then
		warn(("[PescaDeMemes] %s terminó una pelea inválida (%.2fs, %d tirones)"):format(player.Name, elapsed, session.TugsDone))
		resume(session, now)
		return fail("Pelea inválida")
	end
	if elapsed > F.FightTimeout then
		resume(session, now)
		return fail("Se cansó de esperar y se fue")
	end
	local data = PlayerData.Get(player)
	local autoSell = data ~= nil and data.Settings.AutoSell[spec.Meme.Rarity] == true and not spec.Golden
	session.UsedSize += if autoSell then 0 else spec.Size
	table.insert(session.Grabbed, session.Current)
	resume(session, now)
	return { ok = true, Grabbed = true, Count = #session.Grabbed }
end

local function onSurface(player: Player): any
	if not sessions[player] then
		return fail("No estás buceando")
	end
	return surface(player)
end

-- Una inmersión abandonada se cierra sola (y se guarda lo enganchado): demasiado tiempo buceando
-- (sin contar peleas), una pelea/decisión que no termina, o un tope absoluto de 15 minutos.
local HARD_CAP = 15 * 60
function FishingService.IsFishing(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	local now = os.clock()
	local stale = now - session.CastAt > HARD_CAP
		or (session.State == "Diving" and diveTime(session, now) > D.Timeout + 10)
		or (session.State ~= "Diving" and now - session.FightStart > F.FightTimeout + 10)
	if stale then
		surface(player)
		return false
	end
	return true
end

function FishingService.Init()
	Remotes.Get("Cast").OnServerInvoke = onCast
	Remotes.Get("Grab").OnServerInvoke = onGrab
	Remotes.Get("Engage").OnServerInvoke = onEngage
	Remotes.Get("Release").OnServerInvoke = onRelease
	Remotes.Get("Tug").OnServerInvoke = onTug
	Remotes.Get("FinishFight").OnServerInvoke = onFinish
	Remotes.Get("Surface").OnServerInvoke = onSurface

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if sessions[player] then
				surface(player) -- reapareciste a mitad de inmersión: te quedas lo enganchado
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- PlayerData guarda en un task.defer, así que lo enganchado entra en el guardado final
		if sessions[player] then
			surface(player)
		end
		lastCast[player] = nil
	end)
	-- barrido de inmersiones abandonadas
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				FishingService.IsFishing(player)
			end
		end
	end)
end

return FishingService

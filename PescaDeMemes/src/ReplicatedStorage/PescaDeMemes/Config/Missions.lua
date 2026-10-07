--[[
	PescaDeMemes • Missions (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Missions

	MISIONES DIARIAS + REGALO DE RACHA (Fase 3: "obligatorio", decidido por el equipo).
	  · Cada día (UTC) tocan 3 misiones distintas. Se generan con una semilla (jugador + día), así son
	    las mismas aunque cambies de servidor, y nadie puede "volver a tirar" para que salgan fáciles.
	  · Objetivos y premios crecen con tu NIVEL (un jugador de nivel 30 no tiene misiones de nivel 1).
	  · Completar las 3 → premio extra: 🍀 Suerte ×2 durante 5 min.
	  · Regalo diario: se recoge una vez al día. Si vuelves al día siguiente, la racha sube (7 días y vuelve
	    a empezar, con un premio gordo el día 7). Si fallas un día, vuelve al día 1.
	El servidor es quien cuenta el progreso; el cliente solo lo enseña.
]]

local Missions = {}

-- Kind → texto (%s = objetivo ya formateado), objetivos por dificultad y premio base (× dificultad × nivel)
Missions.Kinds = {
	Catch = { Emoji = "🎣", Text = "Pesca %s memes", Targets = { 5, 10, 15 }, Reward = 250 },
	Rare = { Emoji = "💎", Text = "Pesca %s memes RAROS o mejores", Targets = { 1, 2, 3 }, Reward = 450 },
	Kilos = { Emoji = "⚖️", Text = "Pesca %s en total", Targets = { 30, 80, 150 }, Reward = 300, Unit = "kg", Scales = true },
	Dives = { Emoji = "🌊", Text = "Haz %s inmersiones", Targets = { 4, 8, 12 }, Reward = 200 },
	Sell = { Emoji = "💰", Text = "Gana %s 🪙 vendiendo memes", Targets = { 300, 1000, 3000 }, Reward = 300, Scales = true },
	Collect = { Emoji = "🏠", Text = "Cobra %s 🪙 en tu parcela", Targets = { 100, 400, 1200 }, Reward = 300, Scales = true },
}
Missions.KindOrder = { "Catch", "Rare", "Kilos", "Dives", "Sell", "Collect" }
Missions.PerDay = 3

Missions.AllDoneBoost = { Id = "Luck", Seconds = 300 } -- premio por completar las 3
-- Regalo de racha: MemeCoins de cada día (× nivel); el día 7 además da 💰 Dinero ×2 durante 5 min
Missions.StreakCoins = { 200, 350, 500, 750, 1000, 1500, 2500 }
Missions.StreakBoost = { Id = "Money", Seconds = 300 }

local DAY = 24 * 60 * 60

function Missions.Today(now: number): number
	return math.floor(now / DAY)
end

-- Premios y objetivos "de dinero/kg" crecen con el nivel: nivel 1 = ×1, nivel 30 ≈ ×8.
function Missions.LevelScale(level: number): number
	return 1 + 0.25 * (math.max(1, level) - 1)
end

-- Las 3 misiones de un jugador para un día. Siempre las mismas para (userId, día, nivel de ese día).
function Missions.Generate(userId: number, day: number, level: number): { any }
	local rng = Random.new(userId * 7919 + day * 104729)
	local pool = table.clone(Missions.KindOrder)
	local list = {}
	local scale = Missions.LevelScale(level)
	for _ = 1, Missions.PerDay do
		local kind = table.remove(pool, rng:NextInteger(1, #pool))
		local def = Missions.Kinds[kind]
		local difficulty = rng:NextInteger(1, #def.Targets)
		local target = def.Targets[difficulty]
		if def.Scales then
			target = math.floor(target * scale)
		end
		table.insert(list, {
			Kind = kind,
			Target = target,
			Progress = 0,
			Reward = math.floor(def.Reward * difficulty * scale),
			Claimed = false,
		})
	end
	return list
end

-- Día de racha (1..7) que tocaría al recoger el regalo hoy.
function Missions.NextStreak(daily: any, today: number): number
	if daily.LastGift == today then
		return daily.Streak
	elseif daily.LastGift == today - 1 then
		return daily.Streak + 1
	end
	return 1
end

function Missions.StreakDay(streak: number): number
	return (math.max(1, streak) - 1) % #Missions.StreakCoins + 1
end

function Missions.GiftCoins(streak: number, level: number): number
	return math.floor(Missions.StreakCoins[Missions.StreakDay(streak)] * Missions.LevelScale(level))
end

-- ¿Hay algo que recoger? (para el aviso rojo del botón)
function Missions.HasClaimable(daily: any, today: number): boolean
	if type(daily) ~= "table" then
		return false
	end
	if daily.LastGift ~= today then
		return true
	end
	if daily.Day ~= today then
		return false
	end
	for _, m in ipairs(daily.Missions) do
		if not m.Claimed and m.Progress >= m.Target then
			return true
		end
	end
	return false
end

-- Texto de una misión ("Pesca 10 memes").
function Missions.Describe(m: any): string
	local def = Missions.Kinds[m.Kind]
	if not def then
		return "?"
	end
	local target = if def.Unit then ("%d %s"):format(m.Target, def.Unit) else tostring(m.Target)
	return def.Emoji .. " " .. def.Text:format(target)
end

return Missions

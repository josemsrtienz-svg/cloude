--[[
	PescaDeMemes • PlayerData (ModuleScript)
	ServerScriptService > PescaServer > Systems > PlayerData

	Carga y guarda el perfil de cada jugador con DataStoreService:
	  - Session locking: un perfil solo puede estar abierto en un servidor → no se duplican objetos
	    aunque el jugador entre y salga rápido o cambie de servidor.
	  - Reintentos, autosave, guardado al salir y en BindToClose.
	  - Si la carga falla, el jugador juega con datos temporales que NO se guardan
	    (para no pisar sus datos reales).
	  - Migraciones por versión del schema.
	En Studio, activa Game Settings → Security → Enable Studio Access to API Services (el place
	debe estar publicado) para que se guarde. Si no, se juega con datos temporales.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local Boosts = require(Root.Config.Boosts)
local Missions = require(Root.Config.Missions)
local Remotes = require(Root.Shared.Remotes)
local Util = require(Root.Shared.Util)
local Inventory = require(Root.Shared.Inventory)
local FishMath = require(Root.Shared.FishMath)

local PlayerData = {}
PlayerData.Loaded = Util.Signal() -- (player, data)
PlayerData.Changed = Util.Signal() -- (player, data)

local DATASTORE_NAME = "PescaDeMemes_PlayerData_v1"
local AUTOSAVE_INTERVAL = 120
local LOCK_TIMEOUT = 600
local IS_STUDIO = RunService:IsStudio()
local LOAD_ATTEMPTS = IS_STUDIO and 2 or 5
local SAVE_ATTEMPTS = 3

-- Saving: hay un guardado en curso (los guardados de un perfil nunca se solapan)
-- Released: el jugador salió; los guardados normales pendientes se cancelan
type Profile = { Data: any, CanSave: boolean, Saving: boolean, Released: boolean }
local profiles: { [Player]: Profile } = {}
local pendingSaves = 0
local store: DataStore? = nil

local MIGRATIONS: { [number]: (any) -> any } = {
	-- 1 → 2: el acuario (6 huecos) pasa a ser la parcela (8 pedestales) con su cobrador
	[1] = function(data)
		data.Plot = type(data.Aquarium) == "table" and data.Aquarium or {}
		data.Aquarium = nil
		data.PlotBank = 0
		return data
	end,
	-- 2 → 3: mochila-acuario con capacidad (tamaño = peso) y cañas que se pueden romper
	[2] = function(data)
		data.BrokenRods = {}
		-- la mochila antigua (30 huecos) pasa a ser una mochila-acuario donde quepa todo lo que tenía
		local inPlot = {}
		for _, id in ipairs(type(data.Plot) == "table" and data.Plot or {}) do
			inPlot[id] = true
		end
		local used = 0
		for id, c in pairs(type(data.Catches) == "table" and data.Catches or {}) do
			if not inPlot[id] and type(c) == "table" then
				used += Inventory.SizeOf(tonumber(c.Weight) or 1)
			end
		end
		data.AquariumTier = #Rods.Aquariums
		for _, aq in ipairs(Rods.Aquariums) do
			if aq.Capacity >= used then
				data.AquariumTier = aq.Tier
				break
			end
		end
		return data
	end,
	-- 3 → 4: nueva economía (valor por peso y rareza) → recalcula el valor de los memes guardados
	[3] = function(data)
		for _, c in pairs(type(data.Catches) == "table" and data.Catches or {}) do
			local meme = type(c) == "table" and Memes.Get(c.MemeId)
			if meme then
				c.Value = FishMath.Value(meme, tonumber(c.Weight) or 1, c.Golden == true)
			end
		end
		return data
	end,
	-- 4 → 5: tutorial nuevo; quien ya jugaba no lo necesita
	[4] = function(data)
		data.TutorialDone = true
		return data
	end,
}

local function migrate(data: any): any
	data.Version = tonumber(data.Version) or 1
	while MIGRATIONS[data.Version] do
		data = MIGRATIONS[data.Version](data)
		data.Version += 1
	end
	data.Version = math.max(data.Version, GameConfig.DataVersion)
	return data
end

-- Limpia datos corruptos o inválidos (memes o cañas que ya no existen, huecos rotos...).
local function sanitize(data: any): any
	Util.reconcile(data, GameConfig.StartingData)
	for _, key in ipairs({ "Stats", "Items" }) do
		if type(data[key]) ~= "table" then
			data[key] = {}
		end
		Util.reconcile(data[key], GameConfig.StartingData[key])
	end
	data.MemeCoin = math.max(0, math.floor(tonumber(data.MemeCoin) or 0))
	data.Level = math.max(1, math.floor(tonumber(data.Level) or 1))
	data.XP = math.max(0, math.floor(tonumber(data.XP) or 0))
	data.LastSeen = math.max(0, math.floor(tonumber(data.LastSeen) or 0))
	for _, id in ipairs(Rods.ItemOrder) do
		local item = Rods.Items[id]
		local count = math.max(0, math.floor(tonumber(data.Items[id]) or 0))
		data.Items[id] = if item.Kind == "Gear" then math.min(1, count) else count
	end
	-- equipados: válidos, sin repetir y como mucho MaxItemSlots (los huecos reales los aplica el servidor al usarlos)
	local equipped, equippedSeen = {}, {}
	if type(data.EquippedItems) == "table" then
		for _, id in ipairs(data.EquippedItems) do
			if type(id) == "string" and Rods.Items[id] and not equippedSeen[id] and #equipped < Rods.MaxItemSlots then
				equippedSeen[id] = true
				table.insert(equipped, id)
			end
		end
	end
	data.EquippedItems = equipped

	local catches = {}
	if type(data.Catches) == "table" then
		for id, c in pairs(data.Catches) do
			if type(id) == "string" and type(c) == "table" and Memes.Get(c.MemeId) and tonumber(c.Weight) then
				catches[id] = {
					Id = id,
					MemeId = c.MemeId,
					Weight = tonumber(c.Weight),
					Size = Inventory.SizeOf(tonumber(c.Weight) :: number),
					Golden = c.Golden == true,
					Impossible = c.Impossible == true,
					Value = math.max(1, math.floor(tonumber(c.Value) or 1)),
					Time = tonumber(c.Time) or 0,
				}
			end
		end
	end
	data.Catches = catches

	local plot, seen = {}, {}
	for slot = 1, GameConfig.PlotSlots do
		local id = type(data.Plot) == "table" and data.Plot[slot] or ""
		if type(id) == "string" and catches[id] and not seen[id] then
			plot[slot] = id
			seen[id] = true
		else
			plot[slot] = ""
		end
	end
	data.Plot = plot
	data.PlotBank = math.max(0, math.floor(tonumber(data.PlotBank) or 0))

	local rods = { Palo = true }
	if type(data.Rods) == "table" then
		for id, owned in pairs(data.Rods) do
			if owned == true and Rods.Get(id) then
				rods[id] = true
			end
		end
	end
	data.Rods = rods
	if not rods[data.EquippedRod] then
		data.EquippedRod = "Palo"
	end
	local broken = {}
	if type(data.BrokenRods) == "table" then
		for id, value in pairs(data.BrokenRods) do
			local rod = Rods.Get(id)
			if value == true and rods[id] and rod and rod.RepairCost > 0 then
				broken[id] = true
			end
		end
	end
	data.BrokenRods = broken
	local tier = math.floor(tonumber(data.AquariumTier) or 1)
	data.AquariumTier = if Rods.GetAquarium(tier) then tier else 1

	local discovered = {}
	if type(data.Discovered) == "table" then
		for id, entry in pairs(data.Discovered) do
			if Memes.Get(id) and type(entry) == "table" then
				discovered[id] = { Count = math.max(1, math.floor(tonumber(entry.Count) or 1)), Heaviest = tonumber(entry.Heaviest) or 0 }
			end
		end
	end
	data.Discovered = discovered

	-- boosts: solo los que existen y siguen activos
	local boosts = {}
	if type(data.Boosts) == "table" then
		local now = os.time()
		for id, untilTime in pairs(data.Boosts) do
			if Boosts.Get(id) and type(untilTime) == "number" and untilTime > now then
				boosts[id] = math.floor(untilTime)
			end
		end
	end
	data.Boosts = boosts
	data.FreeRound = math.max(0, math.floor(tonumber(data.FreeRound) or 0))

	-- filtros: solo rarezas que existen, guardadas como [rarityId] = true
	local settings = if type(data.Settings) == "table" then data.Settings else {}
	data.Settings = { CatchSkip = Memes.CleanRaritySet(settings.CatchSkip), AutoSell = Memes.CleanRaritySet(settings.AutoSell),
		Music = settings.Music ~= false, SFX = settings.SFX ~= false }
	-- mercader: solo contadores numéricos por oferta
	local bought = {}
	for k, v in pairs(type(data.MerchantBought) == "table" and data.MerchantBought or {}) do
		if type(k) == "string" and type(v) == "number" then
			bought[k] = math.max(0, math.floor(v))
		end
	end
	data.MerchantBought = bought
	data.MerchantVisit = tonumber(data.MerchantVisit) or 0
	-- misiones diarias: si algo está roto se regeneran (Day = 0 → MissionService las crea al cargar)
	local daily = if type(data.Daily) == "table" then data.Daily else {}
	local missions = {}
	for _, m in ipairs(type(daily.Missions) == "table" and daily.Missions or {}) do
		if type(m) == "table" and Missions.Kinds[m.Kind] and type(m.Target) == "number" and m.Target > 0 and type(m.Reward) == "number" then
			table.insert(missions, { Kind = m.Kind, Target = m.Target, Reward = m.Reward,
				Progress = math.clamp(tonumber(m.Progress) or 0, 0, m.Target), Claimed = m.Claimed == true })
		end
	end
	local valid = #missions == Missions.PerDay
	data.Daily = {
		Day = if valid then tonumber(daily.Day) or 0 else 0,
		Missions = if valid then missions else {},
		Bonus = valid and daily.Bonus == true,
		Streak = math.max(0, math.floor(tonumber(daily.Streak) or 0)),
		LastGift = tonumber(daily.LastGift) or 0,
	}
	return data
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function isFatalStudioError(err: any): boolean
	local msg = tostring(err)
	return IS_STUDIO and (msg:find("403") ~= nil or msg:find("API") ~= nil or msg:find("publish") ~= nil)
end

local function loadData(player: Player): (any?, boolean)
	if not store then
		return sanitize(Util.deepCopy(GameConfig.StartingData)), false
	end
	local key = keyFor(player)
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedByOther, loaded = false, nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				old = type(old) == "table" and old or Util.deepCopy(GameConfig.StartingData)
				local lock = old.SessionLock
				local lockActive = type(lock) == "table" and lock.JobId ~= game.JobId
					and os.time() - (tonumber(lock.Time) or 0) < LOCK_TIMEOUT
				if lockActive and attempt < LOAD_ATTEMPTS then
					lockedByOther = true
					return nil
				end
				old.SessionLock = { JobId = game.JobId, Time = os.time() }
				loaded = old
				return old
			end)
		end)
		if ok and loaded then
			loaded.SessionLock = nil
			return sanitize(migrate(loaded)), true
		end
		if not ok then
			warn(("[PescaDeMemes] Error cargando datos de %s (intento %d): %s"):format(player.Name, attempt, tostring(err)))
			if isFatalStudioError(err) then
				break
			end
		end
		if player.Parent ~= Players then
			return nil, false
		end
		task.wait(lockedByOther and 3 or attempt * 1.5)
	end
	return sanitize(Util.deepCopy(GameConfig.StartingData)), false
end

local function saveProfile(player: Player, profile: Profile, release: boolean): boolean
	if not store or not profile.CanSave then
		return false
	end
	if release then
		-- el guardado final espera a que termine cualquier guardado en curso
		local t0 = os.clock()
		while profile.Saving and os.clock() - t0 < 20 do
			task.wait(0.1)
		end
	elseif profile.Saving or profile.Released then
		return false
	end
	profile.Saving = true
	local key = keyFor(player)
	local saved = false
	for attempt = 1, SAVE_ATTEMPTS do
		if not release and profile.Released then
			break -- el jugador ya salió: solo cuenta el guardado final
		end
		local snapshot = Util.deepCopy(profile.Data)
		local stolen = false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				if type(old) == "table" and type(old.SessionLock) == "table" and old.SessionLock.JobId ~= game.JobId then
					stolen = true
					return nil -- otro servidor tiene la sesión: no pisamos sus datos
				end
				snapshot.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return snapshot
			end)
		end)
		if ok and stolen then
			warn(("[PescaDeMemes] %s tiene la sesión abierta en otro servidor: no se guarda aquí"):format(player.Name))
			profile.CanSave = false
			break
		elseif ok then
			saved = true
			break
		end
		warn(("[PescaDeMemes] Error guardando a %s (intento %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(attempt * 1.5)
	end
	profile.Saving = false
	return saved
end

local function updateLeaderstats(player: Player, data: any)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		for _, name in ipairs({ "Nivel", GameConfig.CurrencyName }) do
			local v = Instance.new("IntValue")
			v.Name = name
			v.Parent = stats
		end
		stats.Parent = player
	end
	stats.Nivel.Value = data.Level
	stats[GameConfig.CurrencyName].Value = data.MemeCoin
end

-- ===== API =====

function PlayerData.Get(player: Player): any?
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function PlayerData.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Llama a esto después de modificar los datos: actualiza la UI del cliente y leaderstats.
function PlayerData.Push(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	updateLeaderstats(player, profile.Data)
	Remotes.Get("DataChanged"):FireClient(player, profile.Data)
	PlayerData.Changed:Fire(player, profile.Data)
end

-- Guardado inmediato (tras capturas muy valiosas).
function PlayerData.SaveNow(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and saveProfile(player, profile, false)
end

function PlayerData.Notify(player: Player, text: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, text, kind or "Info")
end

local function onPlayerAdded(player: Player)
	local devMode = IS_STUDIO and GameConfig.DevMode.Enabled
	local data, canSave
	if devMode then
		-- MODO PRUEBA: datos nuevos con dinero infinito; no se carga ni se guarda nada (tus datos reales no se tocan)
		data, canSave = sanitize(Util.deepCopy(GameConfig.StartingData)), false
		data.MemeCoin = GameConfig.DevMode.Money
		data.Level = GameConfig.DevMode.Level
		data.TutorialDone = not GameConfig.DevMode.Tutorial
	else
		data, canSave = loadData(player)
	end
	if not data then
		return
	end
	if player.Parent ~= Players then
		if canSave then
			saveProfile(player, { Data = data, CanSave = true, Saving = false, Released = true }, true)
		end
		return
	end
	profiles[player] = { Data = data, CanSave = canSave, Saving = false, Released = false }
	PlayerData.Push(player)
	PlayerData.Loaded:Fire(player, data)
	if devMode then
		PlayerData.Notify(player, "🧪 MODO PRUEBA (Studio): dinero infinito y NO se guarda. Se desactiva en GameConfig.DevMode", "Info")
	elseif not canSave then
		PlayerData.Notify(player, store and "⚠️ No se pudieron cargar tus datos: esta sesión no se guardará."
			or "⚠️ DataStore no disponible (¿place sin publicar?): esta sesión no se guardará.", "Error")
	end
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	profile.Released = true
	pendingSaves += 1
	saveProfile(player, profile, true)
	pendingSaves -= 1
end

function PlayerData.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PescaDeMemes] DataStore no disponible:", result)
	end

	Remotes.Get("GetData").OnServerInvoke = function(player: Player)
		local t0 = os.clock()
		while not profiles[player] and player.Parent == Players and os.clock() - t0 < 15 do
			task.wait(0.1)
		end
		return PlayerData.Get(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- se deja un frame para que otros sistemas (pesca) cierren antes de guardar
		task.defer(releaseProfile, player)
	end)

	game:BindToClose(function()
		for player in pairs(profiles) do
			task.spawn(releaseProfile, player)
		end
		local t0 = os.clock()
		while pendingSaves > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in pairs(profiles) do
				task.spawn(saveProfile, player, profile, false)
			end
		end
	end)
end

return PlayerData

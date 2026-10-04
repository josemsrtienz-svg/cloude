--[[
	V2MMW • PlayerData (ModuleScript)
	ServerScriptService > V2MMWServer > Systems > PlayerData

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

local Shared = ReplicatedStorage:WaitForChild("V2MMW")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)
local Remotes = require(Shared.Shared.Remotes)
local Util = require(Shared.Shared.Util)

local PlayerData = {}
PlayerData.Loaded = Util.Signal() -- (player, data)
PlayerData.Changed = Util.Signal() -- (player, data)

local DATASTORE_NAME = "V2MMW_PlayerData_v1"
local AUTOSAVE_INTERVAL = 120
local LOCK_TIMEOUT = 600
local IS_STUDIO = RunService:IsStudio()
local LOAD_ATTEMPTS = IS_STUDIO and 2 or 5
local SAVE_ATTEMPTS = 3

type Profile = { Data: any, CanSave: boolean }
local profiles: { [Player]: Profile } = {}
local pendingSaves = 0
local store: DataStore? = nil

local MIGRATIONS: { [number]: (any) -> any } = {
	-- [1] = function(data) ... return data end, -- de la versión 1 a la 2
}

local function migrate(data: any): any
	data.Version = tonumber(data.Version) or 1
	while MIGRATIONS[data.Version] do
		data = MIGRATIONS[data.Version](data)
		data.Version += 1
	end
	return data
end

-- Limpia datos corruptos o inválidos (memes que ya no existen, slots rotos...).
local function sanitize(data: any): any
	Util.reconcile(data, GameConfig.StartingData)
	Util.reconcile(data.Settings, GameConfig.StartingData.Settings)
	Util.reconcile(data.Stats, GameConfig.StartingData.Stats)
	data.MemeCoin = math.max(0, math.floor(tonumber(data.MemeCoin) or 0))
	data.Level = math.max(1, math.floor(tonumber(data.Level) or 1))
	data.XP = math.max(0, math.floor(tonumber(data.XP) or 0))

	local owned = {}
	if type(data.OwnedMemes) == "table" then
		for id, count in pairs(data.OwnedMemes) do
			count = math.floor(tonumber(count) or 0)
			if MemeCatalog.Get(id) and count > 0 then
				owned[id] = count
			end
		end
	end
	data.OwnedMemes = owned

	local equipped = { "", "", "" }
	local seen = {}
	if type(data.EquippedMemes) == "table" then
		for slot = 1, GameConfig.MaxEquipped do
			local id = data.EquippedMemes[slot]
			if type(id) == "string" and owned[id] and not seen[id] then
				equipped[slot] = id
				seen[id] = true
			end
		end
	end
	data.EquippedMemes = equipped
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
			warn(("[V2MMW] Error cargando datos de %s (intento %d): %s"):format(player.Name, attempt, tostring(err)))
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
	local snapshot = Util.deepCopy(profile.Data)
	local key = keyFor(player)
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				if type(old) == "table" and type(old.SessionLock) == "table" and old.SessionLock.JobId ~= game.JobId then
					return nil -- otro servidor tiene la sesión: no pisamos sus datos
				end
				snapshot.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return snapshot
			end)
		end)
		if ok then
			return true
		end
		warn(("[V2MMW] Error guardando a %s (intento %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(attempt * 1.5)
	end
	return false
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

-- Guardado inmediato (se usa tras trades para minimizar cualquier riesgo de duplicación).
function PlayerData.SaveNow(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and saveProfile(player, profile, false)
end

function PlayerData.Notify(player: Player, text: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, text, kind or "Info")
end

local function onPlayerAdded(player: Player)
	local data, canSave = loadData(player)
	if not data then
		return
	end
	if player.Parent ~= Players then
		if canSave then
			saveProfile(player, { Data = data, CanSave = true }, true)
		end
		return
	end
	profiles[player] = { Data = data, CanSave = canSave }
	PlayerData.Push(player)
	PlayerData.Loaded:Fire(player, data)
	if not canSave then
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
		warn("[V2MMW] DataStore no disponible:", result)
	end

	Remotes.Get("GetData").OnServerInvoke = function(player: Player)
		local t0 = os.clock()
		while not profiles[player] and player.Parent == Players and os.clock() - t0 < 15 do
			task.wait(0.1)
		end
		return PlayerData.Get(player)
	end

	local lastSettings: { [Player]: number } = {}
	Remotes.Get("UpdateSettings").OnServerEvent:Connect(function(player: Player, settings)
		local data = PlayerData.Get(player)
		if not data or type(settings) ~= "table" then
			return
		end
		if lastSettings[player] and os.clock() - lastSettings[player] < 0.25 then
			return
		end
		lastSettings[player] = os.clock()
		local s = data.Settings
		for _, key in ipairs({ "Music", "SFX", "Effects" }) do
			if type(settings[key]) == "boolean" then
				s[key] = settings[key]
			end
		end
		if type(settings.Volume) == "number" and settings.Volume == settings.Volume then
			s.Volume = math.clamp(settings.Volume, 0, 1)
		end
		if type(settings.Sensitivity) == "number" and settings.Sensitivity == settings.Sensitivity then
			s.Sensitivity = math.clamp(settings.Sensitivity, 0.2, 3)
		end
		if settings.Quality == "Low" or settings.Quality == "Medium" or settings.Quality == "High" then
			s.Quality = settings.Quality
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSettings[player] = nil
		-- se deja un frame para que otros sistemas (trade, partida) cierren antes de guardar
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

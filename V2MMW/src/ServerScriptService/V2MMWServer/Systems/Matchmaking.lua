--[[
	V2MMW • Matchmaking (ModuleScript)
	ServerScriptService > V2MMWServer > Systems > Matchmaking

	Cabinas físicas de partida (Workspace > MatchStations > CabinaN).
	Estados de una cabina:
	  Idle       → vacía
	  Config     → hay jugadores; el anfitrión (el primero que entró) elige dificultad y mapa
	  Countdown  → el anfitrión pulsó LISTO: cuenta regresiva de 10 s, jugadores congelados juntos
	  Launching  → GO! → MatchService transporta a todos al mapa
	La capacidad se respeta SIEMPRE aquí: si está llena, nadie más entra (y se le saca fuera).
	Detección física: cada 0.2 s se comprueba quién está dentro de la Part "Zone".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("V2MMW")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Teleport = require(script.Parent.Teleport)
local Trading = require(script.Parent.Trading)

local Matchmaking = {}

type Station = {
	Id: string,
	Cfg: any,
	Model: Model,
	Players: { Player },
	Slots: { [Player]: number },
	Difficulty: string?,
	Map: string?,
	Phase: string,
	EndsAt: number?,
	LastShown: number?,
}

local stations: { [string]: Station } = {}
local playerStation: { [Player]: Station } = {}
local rejectCooldown: { [Player]: number } = {}
local startMatch: ((players: { Player }, difficulty: string, mapId: string) -> ())? = nil

local function rootPart(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart? or nil
end

local function isInside(zone: BasePart, pos: Vector3): boolean
	local rel = zone.CFrame:PointToObjectSpace(pos)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function slotCFrame(station: Station, index: number): CFrame
	local slots = station.Model:FindFirstChild("Slots")
	local slot = slots and slots:FindFirstChild("Slot" .. index) :: BasePart?
	local zone = station.Model:FindFirstChild("Zone") :: BasePart
	local base = if slot then slot.CFrame else zone.CFrame
	-- mirando hacia la puerta (+Z de la cabina)
	local pos = base.Position + Vector3.new(0, 3.5, 0)
	return CFrame.lookAt(pos, pos + zone.CFrame.LookVector * -1)
end

local function freeSlot(station: Station): number?
	local used = {}
	for _, idx in pairs(station.Slots) do
		used[idx] = true
	end
	for i = 1, station.Cfg.Capacity do
		if not used[i] then
			return i
		end
	end
	return nil
end

-- ===== Cartel físico de la cabina (lo ven todos) =====
local function updateSign(station: Station)
	local board = station.Model:FindFirstChild("Sign")
	local gui = board and board:FindFirstChild("Display")
	local bg = gui and gui:FindFirstChildOfClass("Frame")
	if not bg then
		return
	end
	local n, cap = #station.Players, station.Cfg.Capacity
	bg.Count.Text = ("%d/%d"):format(n, cap)
	local status, color
	if station.Phase == "Countdown" then
		status = ("EMPIEZA EN %d"):format(math.max(0, math.ceil((station.EndsAt or 0) - os.clock())))
		color = Color3.fromRGB(255, 205, 40)
	elseif station.Phase == "Launching" then
		status, color = "¡EN PARTIDA!", Color3.fromRGB(255, 90, 90)
	elseif n >= cap then
		status, color = "LLENA", Color3.fromRGB(255, 90, 90)
	elseif n > 0 then
		status, color = "CONFIGURANDO · ENTRA", Color3.fromRGB(120, 220, 255)
	else
		status, color = "LIBRE · ENTRA", Color3.fromRGB(120, 255, 140)
	end
	bg.Status.Text = status
	bg.Status.TextColor3 = color
	local names = {}
	for _, p in ipairs(station.Players) do
		table.insert(names, p.DisplayName)
	end
	bg.Players.Text = table.concat(names, " · ")
end

-- ===== Estado para la UI de los jugadores dentro =====
local function broadcast(station: Station)
	updateSign(station)
	local names = {}
	for _, p in ipairs(station.Players) do
		table.insert(names, p.DisplayName)
	end
	local host = station.Players[1]
	local timeLeft = station.EndsAt and math.max(0, math.ceil(station.EndsAt - os.clock())) or nil
	for _, p in ipairs(station.Players) do
		Remotes.Get("StationState"):FireClient(p, {
			StationId = station.Id,
			Name = station.Cfg.Name,
			Capacity = station.Cfg.Capacity,
			Players = names,
			HostName = host and host.DisplayName or "",
			IsHost = p == host,
			Difficulty = station.Difficulty,
			Map = station.Map,
			Phase = station.Phase,
			TimeLeft = timeLeft,
		})
	end
end

local function reset(station: Station)
	station.Players = {}
	station.Slots = {}
	station.Difficulty = nil
	station.Map = nil
	station.Phase = "Idle"
	station.EndsAt = nil
	station.LastShown = nil
end

-- ===== Entrar / salir =====
function Matchmaking.Enter(player: Player, station: Station, snapToSlot: boolean): (boolean, string)
	if not PlayerData.IsLoaded(player) then
		return false, "Cargando tus datos... ⏳"
	end
	local current = playerStation[player]
	if current == station then
		return true, "Ya estás en esta cabina"
	end
	if current or player:GetAttribute("GameState") ~= "Lobby" then
		return false, "Ya estás en otra cabina o partida"
	end
	if station.Phase == "Launching" then
		return false, station.Cfg.Name .. " está empezando una partida"
	end
	if #station.Players >= station.Cfg.Capacity then
		return false, ("%s está llena (%d/%d)"):format(station.Cfg.Name, #station.Players, station.Cfg.Capacity)
	end
	local slot = freeSlot(station)
	if not slot then
		return false, station.Cfg.Name .. " está llena"
	end
	Trading.CancelFor(player, "❌ Intercambio cancelado: entraste a una cabina")
	table.insert(station.Players, player)
	station.Slots[player] = slot
	playerStation[player] = station
	player:SetAttribute("GameState", "Station")
	player:SetAttribute("StationId", station.Id)
	if station.Phase == "Idle" then
		station.Phase = "Config"
	end
	if snapToSlot or station.Phase == "Countdown" then
		Teleport.To(player, slotCFrame(station, slot))
	end
	if station.Phase == "Countdown" then
		Teleport.Freeze(player, true)
	end
	broadcast(station)
	return true, ("Entraste a %s"):format(station.Cfg.Name)
end

function Matchmaking.Leave(player: Player, moveOut: boolean)
	local station = playerStation[player]
	if not station then
		return
	end
	playerStation[player] = nil
	station.Slots[player] = nil
	local idx = table.find(station.Players, player)
	if idx then
		table.remove(station.Players, idx)
	end
	if player.Parent == Players then
		player:SetAttribute("GameState", "Lobby")
		player:SetAttribute("StationId", nil)
		Teleport.Freeze(player, false)
		Remotes.Get("StationState"):FireClient(player, nil)
		if moveOut then
			local exit = station.Model:FindFirstChild("Exit") :: BasePart?
			if exit then
				Teleport.To(player, exit.CFrame + Vector3.new(math.random(-3, 3), 3, 0))
			end
		end
	end
	if #station.Players == 0 then
		reset(station)
	elseif station.Phase == "Countdown" and idx == 1 then
		-- el anfitrión se fue: se vuelve a configurar con el nuevo anfitrión
		station.Phase = "Config"
		station.EndsAt = nil
		for _, p in ipairs(station.Players) do
			Teleport.Freeze(p, false)
		end
	end
	broadcast(station)
end

local function reject(player: Player, station: Station, message: string)
	local exit = station.Model:FindFirstChild("Exit") :: BasePart?
	if exit then
		Teleport.To(player, exit.CFrame + Vector3.new(math.random(-3, 3), 3, 0))
	end
	local now = os.clock()
	if not rejectCooldown[player] or now - rejectCooldown[player] > 2 then
		rejectCooldown[player] = now
		PlayerData.Notify(player, message, "Error")
	end
end

-- ===== Lanzamiento =====
local function launch(station: Station)
	station.Phase = "Launching"
	station.EndsAt = nil
	broadcast(station)
	local group = table.clone(station.Players)
	local difficulty, map = station.Difficulty :: string, station.Map :: string
	task.wait(1) -- deja ver el "GO!"
	for _, p in ipairs(group) do
		playerStation[p] = nil
		if p.Parent == Players then
			p:SetAttribute("StationId", nil)
			Remotes.Get("StationState"):FireClient(p, nil)
		end
	end
	reset(station)
	broadcast(station)
	local valid = {}
	for _, p in ipairs(group) do
		if p.Parent == Players then
			table.insert(valid, p)
		end
	end
	if #valid > 0 and startMatch then
		startMatch(valid, difficulty, map)
	end
end

-- MatchService registra aquí cómo empezar una partida.
function Matchmaking.SetMatchStarter(fn)
	startMatch = fn
end

function Matchmaking.Init()
	for _, cfg in ipairs(GameConfig.Stations) do
		local model = WorldBuilder.GetStation(cfg.Id)
		if model then
			local station: Station = {
				Id = cfg.Id, Cfg = cfg, Model = model, Players = {}, Slots = {},
				Difficulty = nil, Map = nil, Phase = "Idle", EndsAt = nil, LastShown = nil,
			}
			stations[cfg.Id] = station
			updateSign(station)
			local promptInst = model:FindFirstChild("EnterPrompt", true)
			if promptInst and promptInst:IsA("ProximityPrompt") then
				promptInst.Triggered:Connect(function(player)
					local ok, msg = Matchmaking.Enter(player, station, true)
					if not ok then
						PlayerData.Notify(player, msg, "Error")
					end
				end)
			end
		else
			warn("[V2MMW] No se encontró la cabina " .. cfg.Id)
		end
	end

	Remotes.Get("EnterStation").OnServerInvoke = function(player, stationId)
		local station = type(stationId) == "string" and stations[stationId]
		if not station then
			return false, "Cabina inválida"
		end
		return Matchmaking.Enter(player, station, true)
	end

	Remotes.Get("LeaveStation").OnServerInvoke = function(player)
		local station = playerStation[player]
		if not station then
			return false, "No estás en una cabina"
		end
		if station.Phase == "Launching" then
			return false, "¡La partida ya está empezando!"
		end
		Matchmaking.Leave(player, true)
		return true, "Saliste de la cabina"
	end

	Remotes.Get("ConfigureStation").OnServerInvoke = function(player, difficultyId, mapId)
		local station = playerStation[player]
		if not station then
			return false, "No estás en una cabina"
		end
		if station.Players[1] ~= player then
			return false, "Solo el anfitrión elige la dificultad y el mapa"
		end
		if station.Phase ~= "Config" then
			return false, "Ya no se puede cambiar"
		end
		if difficultyId ~= nil then
			if not GameConfig.GetDifficulty(difficultyId) then
				return false, "Dificultad inválida"
			end
			station.Difficulty = difficultyId
		end
		if mapId ~= nil then
			if not GameConfig.GetMap(mapId) then
				return false, "Mapa inválido"
			end
			station.Map = mapId
		end
		broadcast(station)
		return true
	end

	Remotes.Get("StationReady").OnServerInvoke = function(player)
		local station = playerStation[player]
		if not station then
			return false, "No estás en una cabina"
		end
		if station.Players[1] ~= player then
			return false, "Solo el anfitrión puede empezar"
		end
		if station.Phase ~= "Config" then
			return false, "La cuenta regresiva ya empezó"
		end
		if not (station.Difficulty and station.Map) then
			return false, "Elige dificultad y mapa primero"
		end
		station.Phase = "Countdown"
		station.EndsAt = os.clock() + GameConfig.CountdownSeconds
		for _, p in ipairs(station.Players) do
			local slot = station.Slots[p]
			if slot then
				Teleport.To(p, slotCFrame(station, slot))
			end
			Teleport.Freeze(p, true)
		end
		broadcast(station)
		return true, "¡Cuenta regresiva iniciada!"
	end

	Players.PlayerRemoving:Connect(function(player)
		Matchmaking.Leave(player, false)
		rejectCooldown[player] = nil
	end)
	local function watchDeath(player: Player)
		player.CharacterRemoving:Connect(function()
			if playerStation[player] and playerStation[player].Phase ~= "Launching" then
				Matchmaking.Leave(player, false)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchDeath)
	for _, p in ipairs(Players:GetPlayers()) do
		watchDeath(p)
	end

	-- Bucle principal: detección física + cuenta regresiva
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, player in ipairs(Players:GetPlayers()) do
				local root = rootPart(player)
				local current = playerStation[player]
				if root and current then
					local zone = current.Model:FindFirstChild("Zone") :: BasePart?
					if zone and current.Phase ~= "Launching" and current.Phase ~= "Countdown" and not isInside(zone, root.Position) then
						Matchmaking.Leave(player, false)
					end
				elseif root and player:GetAttribute("GameState") == "Lobby" then
					for _, station in pairs(stations) do
						local zone = station.Model:FindFirstChild("Zone") :: BasePart?
						if zone and isInside(zone, root.Position) then
							local ok, msg = Matchmaking.Enter(player, station, false)
							if not ok then
								reject(player, station, msg)
							end
							break
						end
					end
				end
			end
			for _, station in pairs(stations) do
				if station.Phase == "Countdown" and station.EndsAt then
					local left = math.ceil(station.EndsAt - os.clock())
					if left <= 0 then
						task.spawn(launch, station)
					elseif left ~= station.LastShown then
						station.LastShown = left
						broadcast(station)
					end
				end
			end
		end
	end)
end

return Matchmaking

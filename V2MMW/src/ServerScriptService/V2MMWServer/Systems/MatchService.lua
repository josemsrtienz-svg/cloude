--[[
	V2MMW • MatchService (ModuleScript)
	ServerScriptService > V2MMWServer > Systems > MatchService

	Ciclo de vida de una partida:
	  TRANSPORTAR → PARTIDA → FINAL → REGRESAR AL LOBBY
	  - Busca el mapa elegido (Workspace > Maps > MapN) y coloca a cada jugador en sus Spawns.
	  - Si el mapa tiene PlaceId (≠ 0) y el juego está publicado, usa TeleportService.
	  - Gameplay de prueba (PLACEHOLDER): el primero que toque la Part "Goal" gana.
	    Cuando exista el gameplay real, llama a MatchService.Finish(matchId, winner) desde tu sistema.
	  - Al terminar el tiempo o al ganar alguien: recompensas (× multiplicador de dificultad)
	    y vuelta al lobby.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("V2MMW")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local MemeCoin = require(script.Parent.MemeCoin)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Teleport = require(script.Parent.Teleport)
local Matchmaking = require(script.Parent.Matchmaking)

local MatchService = {}

type Match = {
	Id: number,
	Players: { Player },
	MapId: string,
	Map: Instance,
	Difficulty: string,
	EndsAt: number, -- Workspace:GetServerTimeNow()
	Phase: string, -- "Playing" | "Ended"
	Spawns: { CFrame },
	SpawnIndex: { [Player]: number },
}

local matches: { [number]: Match } = {}
local playerMatch: { [Player]: Match } = {}
local nextId = 0
local goalConnections: { [Instance]: RBXScriptConnection } = {}

local function scaled(reward: any, mult: number)
	return {
		MemeCoin = math.floor((reward.MemeCoin or 0) * mult),
		XP = math.floor((reward.XP or 0) * mult),
	}
end

local function sendState(match: Match, player: Player, extra: any?)
	local mapCfg = GameConfig.GetMap(match.MapId)
	local diff = GameConfig.GetDifficulty(match.Difficulty)
	local state = {
		MatchId = match.Id,
		Phase = match.Phase,
		MapId = match.MapId,
		MapName = mapCfg and mapCfg.Name or match.MapId,
		Placeholder = match.Map:GetAttribute("Placeholder") == true,
		Difficulty = diff and diff.Name or match.Difficulty,
		EndsAt = match.EndsAt,
		PlayerCount = #match.Players,
	}
	for k, v in pairs(extra or {}) do
		state[k] = v
	end
	Remotes.Get("MatchState"):FireClient(player, state)
end

function MatchService.IsPlaying(player: Player): boolean
	local match = playerMatch[player]
	return match ~= nil and match.Phase == "Playing"
end

function MatchService.GetMatch(player: Player): Match?
	return playerMatch[player]
end

-- Saca al jugador de la partida y lo devuelve al lobby.
function MatchService.ReturnToLobby(player: Player)
	local match = playerMatch[player]
	playerMatch[player] = nil
	if match then
		local idx = table.find(match.Players, player)
		if idx then
			table.remove(match.Players, idx)
		end
		match.SpawnIndex[player] = nil
		if #match.Players == 0 then
			matches[match.Id] = nil
		end
	end
	if player.Parent == Players then
		player:SetAttribute("GameState", "Lobby")
		player:SetAttribute("MatchId", nil)
		Teleport.ResetMovement(player)
		local char = player.Character
		local ff = char and char:FindFirstChild("AbilityShield")
		if ff then
			ff:Destroy()
		end
		Remotes.Get("MatchState"):FireClient(player, nil)
		if not Teleport.ToLobby(player) then
			player:LoadCharacter() -- si estaba muerto, reaparece directamente en el lobby
		end
	end
end

function MatchService.Finish(matchId: number, winner: Player?)
	local match = matches[matchId]
	if not match or match.Phase ~= "Playing" then
		return
	end
	match.Phase = "Ended"
	local diff = GameConfig.GetDifficulty(match.Difficulty)
	local mult = diff and diff.RewardMultiplier or 1
	for _, p in ipairs(match.Players) do
		local isWinner = p == winner
		local reward = scaled(isWinner and GameConfig.Match.WinReward or GameConfig.Match.ParticipationReward, mult)
		local data = PlayerData.Get(p)
		if data then
			data.Stats.MatchesPlayed += 1
			if isWinner then
				data.Stats.MatchesWon += 1
			end
		end
		MemeCoin.Grant(p, reward)
		Teleport.Freeze(p, true)
		sendState(match, p, {
			Winner = winner and winner.DisplayName or nil,
			YouWon = isWinner,
			Reward = MemeCoin.Describe(reward),
			ReturnIn = GameConfig.Match.ReturnDelay,
		})
	end
	task.delay(GameConfig.Match.ReturnDelay, function()
		for _, p in ipairs(table.clone(match.Players)) do
			if playerMatch[p] == match then
				MatchService.ReturnToLobby(p)
			end
		end
		matches[match.Id] = nil
	end)
end

local function hookGoal(map: Instance)
	local goal = map:FindFirstChild("Goal", true)
	if not (goal and goal:IsA("BasePart")) or goalConnections[goal] then
		return
	end
	goalConnections[goal] = goal.Touched:Connect(function(hit)
		local char = hit:FindFirstAncestorOfClass("Model")
		local player = char and Players:GetPlayerFromCharacter(char)
		local match = player and playerMatch[player]
		if match and match.Phase == "Playing" and match.Map == map then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				MatchService.Finish(match.Id, player)
			end
		end
	end)
end

function MatchService.Start(group: { Player }, difficultyId: string, mapId: string)
	local mapCfg = GameConfig.GetMap(mapId)
	if not mapCfg or not GameConfig.GetDifficulty(difficultyId) then
		for _, p in ipairs(group) do
			p:SetAttribute("GameState", "Lobby")
			Teleport.Freeze(p, false)
			PlayerData.Notify(p, "Configuración de partida inválida", "Error")
		end
		return
	end

	-- Teletransporte real a otro place (juego publicado + PlaceId configurado)
	if mapCfg.PlaceId ~= 0 and not RunService:IsStudio() then
		local ok, err = Teleport.ToPlace(mapCfg.PlaceId, group, { Mode = "Match", Map = mapId, Difficulty = difficultyId })
		if ok then
			return
		end
		warn("[V2MMW] Falló el teletransporte a otro place, se usa el mapa local:", err)
	end

	local map = WorldBuilder.GetMap(mapId)
	if not map then
		for _, p in ipairs(group) do
			p:SetAttribute("GameState", "Lobby")
			Teleport.Freeze(p, false)
			PlayerData.Notify(p, ("El mapa %s no existe todavía"):format(mapCfg.Name), "Error")
		end
		return
	end
	hookGoal(map)

	nextId += 1
	local match: Match = {
		Id = nextId,
		Players = {},
		MapId = mapId,
		Map = map,
		Difficulty = difficultyId,
		EndsAt = Workspace:GetServerTimeNow() + GameConfig.Match.Duration,
		Phase = "Playing",
		Spawns = WorldBuilder.GetMapSpawns(map),
		SpawnIndex = {},
	}
	matches[match.Id] = match
	for i, p in ipairs(group) do
		table.insert(match.Players, p)
		playerMatch[p] = match
		match.SpawnIndex[p] = ((i - 1) % #match.Spawns) + 1
		p:SetAttribute("GameState", "Match")
		p:SetAttribute("MatchId", match.Id)
		Teleport.Freeze(p, false)
		if not Teleport.To(p, match.Spawns[match.SpawnIndex[p]]) then
			p:LoadCharacter() -- el resolver de reaparición lo pondrá en el mapa
		end
	end
	for _, p in ipairs(match.Players) do
		sendState(match, p)
	end
end

function MatchService.Init()
	Matchmaking.SetMatchStarter(MatchService.Start)

	Teleport.SetRespawnResolver(function(player: Player): CFrame?
		local match = playerMatch[player]
		if match and match.Phase == "Playing" then
			return match.Spawns[match.SpawnIndex[player] or 1]
		end
		return nil
	end)

	Remotes.Get("LeaveMatch").OnServerInvoke = function(player)
		local match = playerMatch[player]
		if not match then
			return false, "No estás en una partida"
		end
		if match.Phase ~= "Playing" then
			return false, "Volviendo al lobby..."
		end
		MatchService.ReturnToLobby(player)
		return true, "Abandonaste la partida (sin recompensa)"
	end

	Players.PlayerRemoving:Connect(function(player)
		local match = playerMatch[player]
		if match then
			playerMatch[player] = nil
			local idx = table.find(match.Players, player)
			if idx then
				table.remove(match.Players, idx)
			end
			if #match.Players == 0 then
				matches[match.Id] = nil
			end
		end
	end)

	-- tiempo límite
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = Workspace:GetServerTimeNow()
			for id, match in pairs(matches) do
				if match.Phase == "Playing" then
					if #match.Players == 0 then
						matches[id] = nil
					elseif now >= match.EndsAt then
						MatchService.Finish(id, nil)
					end
				end
			end
		end
	end)
end

return MatchService

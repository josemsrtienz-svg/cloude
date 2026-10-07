--[[
	PescaDeMemes • MissionService (ModuleScript)
	ServerScriptService > PescaServer > Systems > MissionService

	Misiones diarias y regalo de racha (reglas en Config/Missions).
	  MissionService.Progress(player, kind, amount) → lo llaman FishingService (Catch, Rare, Kilos, Dives, Sell
	  automática), EconomyService (Sell) y PlotService (Collect). No guarda por sí mismo: quien lo llama ya hace Push.
	Remotes: ClaimMission(index), ClaimDailyGift().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Missions = require(Root.Config.Missions)
local Remotes = require(Root.Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)

local MissionService = {}

local lastAction: { [Player]: number } = {}

local function fail(err: string): any
	return { ok = false, err = err }
end

-- Al cambiar de día: misiones nuevas (según tu nivel de hoy). Devuelve true si cambió algo.
local function refresh(player: Player, data: any): boolean
	local today = Missions.Today(os.time())
	if data.Daily.Day == today then
		return false
	end
	data.Daily.Day = today
	data.Daily.Missions = Missions.Generate(player.UserId, today, data.Level)
	data.Daily.Bonus = false
	return true
end

function MissionService.Progress(player: Player, kind: string, amount: number)
	local data = PlayerData.Get(player)
	if not data or amount <= 0 then
		return
	end
	refresh(player, data)
	for _, m in ipairs(data.Daily.Missions) do
		if m.Kind == kind and not m.Claimed and m.Progress < m.Target then
			m.Progress = math.min(m.Target, m.Progress + amount)
			if m.Progress >= m.Target then
				PlayerData.Notify(player, "📜 ¡Misión completada! " .. Missions.Describe(m) .. " · recógela en Misiones", "Success")
			end
		end
	end
end

local function rateLimited(player: Player): boolean
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.3 then
		return true
	end
	lastAction[player] = now
	return false
end

local function onClaimMission(player: Player, index: any): any
	if rateLimited(player) then
		return fail("Más despacio")
	end
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	if refresh(player, data) then
		PlayerData.Push(player)
		return fail("¡Nuevo día! Tus misiones han cambiado")
	end
	local m = type(index) == "number" and data.Daily.Missions[index]
	if not m then
		return fail("Esa misión no existe")
	end
	if m.Claimed then
		return fail("Ya la recogiste")
	end
	if m.Progress < m.Target then
		return fail("Aún no la has completado")
	end
	m.Claimed = true
	data.MemeCoin += m.Reward
	local bonus = false
	if not data.Daily.Bonus then
		local all = true
		for _, other in ipairs(data.Daily.Missions) do
			all = all and other.Claimed
		end
		if all then
			data.Daily.Bonus = true
			bonus = true
			BoostService.Grant(player, Missions.AllDoneBoost.Id, Missions.AllDoneBoost.Seconds)
		end
	end
	PlayerData.Push(player)
	return { ok = true, Reward = m.Reward, Bonus = bonus }
end

local function onClaimDailyGift(player: Player): any
	if rateLimited(player) then
		return fail("Más despacio")
	end
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	local today = Missions.Today(os.time())
	if data.Daily.LastGift == today then
		return fail("🎁 Ya lo recogiste hoy: vuelve mañana para seguir la racha")
	end
	local streak = Missions.NextStreak(data.Daily, today)
	data.Daily.Streak = streak
	data.Daily.LastGift = today
	local coins = Missions.GiftCoins(streak, data.Level)
	data.MemeCoin += coins
	local boost = Missions.StreakDay(streak) == #Missions.StreakCoins
	if boost then
		BoostService.Grant(player, Missions.StreakBoost.Id, Missions.StreakBoost.Seconds)
	end
	PlayerData.Push(player)
	return { ok = true, Coins = coins, Streak = streak, Boost = boost }
end

function MissionService.Init()
	Remotes.Get("ClaimMission").OnServerInvoke = onClaimMission
	Remotes.Get("ClaimDailyGift").OnServerInvoke = onClaimDailyGift
	PlayerData.Loaded:Connect(function(player, data)
		refresh(player, data)
		PlayerData.Push(player)
		if data.Daily.LastGift ~= Missions.Today(os.time()) then
			PlayerData.Notify(player, "🎁 ¡Tu regalo diario te espera en 📜 Misiones!", "Info")
		end
	end)
	-- a medianoche (UTC) cambian las misiones de quien esté jugando
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data and refresh(player, data) then
					PlayerData.Push(player)
					PlayerData.Notify(player, "📜 ¡Nuevo día! Tienes misiones nuevas y tu regalo diario", "Info")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
	-- quien ya cargó antes de que arrancara este sistema (Studio)
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.Get(player)
		if data and refresh(player, data) then
			PlayerData.Push(player)
		end
	end
end

return MissionService

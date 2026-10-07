--[[
	PescaDeMemes • BossService (ModuleScript)
	ServerScriptService > PescaServer > Systems > BossService

	El JEFE DEL RÍO (reglas en Config/Boss). El servidor:
	  · decide cuándo sale (igual en todos los servidores), pone el modelo gigante en el río y publica en Workspace:
	    BossActive (bool), BossHP, BossMaxHP, BossEnds (segundos de servidor) y BossResult ("win" | "escape" | "").
	  · valida cada tirón (RemoteEvent BossPull): evento activo, cadencia, caña en la mano y estar en el río.
	  · al ganar reparte MemeCoins a quien ayudó y sortea el meme DIOS (papeletas = fuerza aportada).
	  · BossResult (RemoteEvent) avisa a cada jugador de lo que ganó, para su celebración.
	El cliente (BossController) anima el modelo, la barra de vida y el botón 🎣 ¡TIRA!.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Boss = require(Root.Config.Boss)
local Remotes = require(Root.Shared.Remotes)
local MemeModels = require(Root.Shared.MemeModels)
local FishMath = require(Root.Shared.FishMath)
local Inventory = require(Root.Shared.Inventory)

local PlayerData = require(script.Parent.PlayerData)
local GearService = require(script.Parent.GearService)

local BossService = {}

local TEST = RunService:IsStudio() and GameConfig.DevMode.Enabled and GameConfig.DevMode.BossTest == true
local RIVER = GameConfig.River

type Fight = { Cycle: number, HP: number, MaxHP: number, Ends: number, Done: boolean,
	Damage: { [Player]: number }, Pulls: { [Player]: number }, Model: Model? }
local fight: Fight? = nil
local lastCycle: number? = nil -- último ciclo que ya salió (si lo sacáis antes de tiempo, no vuelve a salir)
local lastPull: { [Player]: number } = {}
local rng = Random.new()

local function publish()
	local f = fight
	Workspace:SetAttribute("BossActive", f ~= nil and not f.Done)
	Workspace:SetAttribute("BossHP", if f then math.max(0, math.ceil(f.HP)) else 0)
	Workspace:SetAttribute("BossMaxHP", if f then f.MaxHP else 0)
	Workspace:SetAttribute("BossEnds", if f then f.Ends else 0)
end

local function notifyAll(text: string, kind: string)
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.Notify(player, text, kind)
	end
end

-- El jefe emerge: modelo gigante anclado en el centro del río (el cliente lo anima).
local function spawnModel(): Model
	local model = MemeModels.Build(Boss.MemeId, Boss.ModelScale, false, true)
	model.Name = "RiverBoss"
	model:PivotTo(CFrame.new(0, RIVER.SurfaceY - 2.2, Boss.Z))
	local map = Workspace:FindFirstChild("Map")
	model.Parent = map or Workspace
	return model
end

local function giveGodMeme(player: Player): boolean
	local data = PlayerData.Get(player)
	local meme = Memes.Get(Boss.MemeId)
	if not data or not meme then
		return false
	end
	local weight = math.floor((meme.WeightMin + (meme.WeightMax - meme.WeightMin) * rng:NextNumber()) * 10 + 0.5) / 10
	local id = HttpService:GenerateGUID(false)
	-- va a la mochila aunque no quepa: es un DIOS (no puedes pescar hasta descargarla en tu parcela)
	data.Catches[id] = { Id = id, MemeId = meme.Id, Weight = weight, Size = Inventory.SizeOf(weight), Golden = false, Impossible = false,
		Value = FishMath.Value(meme, weight, false), Time = os.time() }
	local entry = data.Discovered[meme.Id]
	if not entry then
		entry = { Count = 0, Heaviest = 0 }
		data.Discovered[meme.Id] = entry
	end
	entry.Count += 1
	entry.Heaviest = math.max(entry.Heaviest, weight)
	task.spawn(PlayerData.SaveNow, player)
	return true
end

local function finish(win: boolean)
	local f = fight
	if not f or f.Done then
		return
	end
	f.Done = true
	Workspace:SetAttribute("BossResult", if win then "win" else "escape")
	publish()
	local results: { [Player]: any } = {}
	if win then
		-- quién cobra: los que llegaron al mínimo de tirones y siguen en el servidor
		local total, helpers = 0, {}
		for player, dmg in pairs(f.Damage) do
			if player.Parent == Players and (f.Pulls[player] or 0) >= Boss.MinPulls then
				total += dmg
				table.insert(helpers, player)
			end
		end
		local share = if #helpers > 0 then 1 / #helpers else 1
		for _, player in ipairs(helpers) do
			local data = PlayerData.Get(player)
			if data then
				local part = math.clamp((f.Damage[player] / total) / share, 0.5, 2)
				local coins = math.floor(Boss.RewardCoins * Boss.LevelScale(data.Level) * part)
				data.MemeCoin += coins
				results[player] = { Win = true, Coins = coins }
				PlayerData.Push(player)
			end
		end
		-- sorteo del meme DIOS (papeletas = daño aportado)
		local roll = rng:NextNumber() * total
		for _, player in ipairs(helpers) do
			roll -= f.Damage[player]
			if roll <= 0 then
				if giveGodMeme(player) then
					results[player].God = Boss.MemeId
					PlayerData.Push(player)
					local meme = Memes.Get(Boss.MemeId)
					Remotes.Get("Announce"):FireAllClients(("🐋 ¡%s se lleva a la %s! (meme DIOS)"):format(player.DisplayName,
						if meme then meme.Name else "Ballena"), "GOD", player.UserId)
				end
				break
			end
		end
		notifyAll(("🐋 ¡Habéis sacado al JEFE DEL RÍO! %d jugadores cobran su parte"):format(#helpers), "Success")
	else
		notifyAll("🐋 El Jefe del río se ha escapado… ¡la próxima vez, más fuerza!", "Warning")
	end
	for player, info in pairs(results) do
		Remotes.Get("BossResult"):FireClient(player, info)
	end
	-- el modelo se queda unos segundos para la animación de salida (cliente) y desaparece
	local model = f.Model
	task.delay(5, function()
		if model then
			model:Destroy()
		end
		if fight == f then
			fight = nil
			Workspace:SetAttribute("BossResult", "")
			publish()
		end
	end)
end

local function start(cycle: number, ends: number)
	local hp = math.max(Boss.MinHP, Boss.HPPerPlayer * #Players:GetPlayers())
	fight = { Cycle = cycle, HP = hp, MaxHP = hp, Ends = ends, Done = false, Damage = {}, Pulls = {}, Model = spawnModel() }
	Workspace:SetAttribute("BossResult", "")
	publish()
	notifyAll("🐋 ¡El JEFE DEL RÍO ha salido! Saca la caña, ve al río y pulsa 🎣 ¡TIRA! entre todos", "Info")
end

local function onPull(player: Player)
	local f = fight
	if not f or f.Done then
		return
	end
	local now = os.clock()
	if lastPull[player] and now - lastPull[player] < Boss.PullCooldown * Boss.PullTolerance then
		return
	end
	lastPull[player] = now
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 or not character:FindFirstChild(GearService.ToolName) then
		return
	end
	-- en el río: tu muelle o el puente (dentro del cauce, con un margen)
	if not Boss.CanPullAt(hrp.Position) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local power = Boss.PowerForRod(data.EquippedRod)
	f.HP -= power
	f.Damage[player] = (f.Damage[player] or 0) + power
	f.Pulls[player] = (f.Pulls[player] or 0) + 1
	Workspace:SetAttribute("BossHP", math.max(0, math.ceil(f.HP)))
	if f.HP <= 0 then
		finish(true)
	end
end

function BossService.Init()
	Remotes.Get("BossPull").OnServerEvent:Connect(onPull)
	Players.PlayerRemoving:Connect(function(player)
		lastPull[player] = nil
	end)
	publish()
	task.spawn(function()
		while true do
			local now = os.time()
			local active, cycle, ends = Boss.State(now, TEST)
			if active and cycle ~= lastCycle then
				lastCycle = cycle
				start(cycle, ends)
			elseif fight and not fight.Done and now >= fight.Ends then
				finish(false)
			end
			task.wait(0.5)
		end
	end)
end

return BossService

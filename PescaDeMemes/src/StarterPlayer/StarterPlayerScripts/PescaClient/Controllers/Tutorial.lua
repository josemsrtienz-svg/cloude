--[[
	PescaDeMemes • Tutorial (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > Tutorial

	Tutorial de los primeros 60 s, JUGANDO (sin textos largos). Solo si data.TutorialDone es false.
	Pasos (se calculan cada vez a partir del estado real, así nunca se queda atascado):
	  1. 🚶 Ir al final de TU muelle      (flecha + rastro)
	  2. 🎣 Sacar la caña (tecla 1)
	  3. 🖱️ Mantener click y soltar
	  4. 🪝 Guiar el anzuelo hasta el meme asegurado (el servidor lo pone fácil y en el centro)
	  5. 🏠 Volver a la parcela           (los memes se colocan solos al entrar)
	  6. 💰 Pisar el cobrador cuando tenga monedas
	Al terminar: FinishTutorial → el servidor marca TutorialDone y da el premio (solo si pescó de verdad).
	"Saltar" lo termina sin premio.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Inventory = require(Root.Shared.Inventory)
local Util = require(Root.Shared.Util)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local HUD = require(Controllers.HUD)
local DiveScene = require(Controllers.DiveScene)

local T = UIKit.Theme
local player = Players.LocalPlayer
local Tutorial = {}

type Step = { Id: string, Text: string }
local STEPS: { Step } = {
	{ Id = "dock", Text = "🚶 Ve al final de TU muelle (sigue la flecha amarilla)" },
	{ Id = "rod", Text = "🎣 Saca la caña: tecla 1 o toca su icono abajo" },
	{ Id = "cast", Text = "🖱️ Mantén CLICK (o el dedo) y suelta para lanzar" },
	{ Id = "dive", Text = "🪝 Mueve el anzuelo con A/D o el ratón hasta el meme de la flecha. Mantén S para frenar" },
	{ Id = "home", Text = "🏠 ¡Lo tienes! Vuelve a tu parcela: tu meme se coloca solo" },
	{ Id = "collect", Text = "💰 Tu meme ya gana monedas. Cuando el cobrador tenga, písalo" },
}
local INDEX: { [string]: number } = {}
for i, s in ipairs(STEPS) do
	INDEX[s.Id] = i
end

local gui: ScreenGui
local card: Frame
local stepLabel: TextLabel
local textLabel: TextLabel
local current: string? = nil
local running = false
local finished = false -- ya se pidió terminar: no vuelve a arrancar aunque lleguen datos viejos
local collected = false
local lastBank = 0
local loop: RBXScriptConnection? = nil

-- puntero en el mundo: una pieza invisible SOLO de este cliente + flecha encima + rastro desde el jugador
local target: Part? = nil
local beam: Beam? = nil
local fromAttachment: Attachment? = nil

local function plotFolder(): Instance?
	local index = player:GetAttribute("PlotIndex")
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return if type(index) == "number" and plots then plots:FindFirstChild("Plot" .. index) else nil
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function hidePointer()
	if beam then
		beam.Enabled = false
	end
	if target then
		target.Parent = nil
	end
end

local function pointAt(position: Vector3?)
	local hrp = rootPart()
	if not position or not hrp then
		hidePointer()
		return
	end
	if not target then
		local part = UIKit.new("Part", { Name = "TutorialTarget", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, Size = Vector3.new(1, 1, 1) })
		local arrow = UIKit.new("BillboardGui", { Name = "Arrow", Size = UDim2.fromOffset(90, 90), StudsOffsetWorldSpace = Vector3.new(0, 6, 0),
			AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 2000, Parent = part })
		UIKit.label({ Name = "Icon", Text = "⬇", Size = UDim2.fromScale(1, 1), Font = T.FontTitle, TextColor3 = T.Primary, Parent = arrow },
			{ Stroke = 4 })
		UIKit.new("Attachment", { Name = "To", Parent = part })
		target = part
	end
	local part = target :: Part
	part.Position = position
	part.Parent = Workspace
	-- el rastro sale de los pies del personaje actual (se rehace si reapareces)
	if not fromAttachment or fromAttachment.Parent ~= hrp then
		if fromAttachment then
			fromAttachment:Destroy()
		end
		fromAttachment = UIKit.new("Attachment", { Name = "TutorialFrom", Position = Vector3.new(0, -2.5, 0), Parent = hrp })
		if beam then
			beam:Destroy()
		end
		beam = UIKit.new("Beam", { Name = "TutorialBeam", Attachment0 = fromAttachment, Attachment1 = part:FindFirstChild("To"),
			Width0 = 1, Width1 = 1, FaceCamera = true, LightInfluence = 0, Segments = 20, TextureSpeed = 1.5,
			Color = ColorSequence.new(T.Primary), Transparency = NumberSequence.new(0.3), Parent = hrp })
	end
	(beam :: Beam).Enabled = true
end

local function hasPlotMeme(data: any): boolean
	for _, id in ipairs(data.Plot) do
		if id ~= "" and data.Catches[id] then
			return true
		end
	end
	return false
end

local function onDock(): boolean
	local hrp = rootPart()
	local index = player:GetAttribute("PlotIndex")
	if not hrp or type(index) ~= "number" or index < 1 then
		return false
	end
	local offset = hrp.Position - GameConfig.DockSpot(index)
	return Vector2.new(offset.X, offset.Z).Magnitude <= GameConfig.Plots.FishingRange
end

local function holdingRod(): boolean
	local character = player.Character
	local tool = character and character:FindFirstChild(GameConfig.RodToolName)
	return tool ~= nil and tool:IsA("Tool")
end

-- Paso actual a partir del estado real (sin memoria: si vendes el meme o te caes, vuelve al paso que toque).
local function computeStep(data: any): string
	if hasPlotMeme(data) then
		return "collect"
	end
	if DiveScene.Active() then
		return "dive"
	end
	if #Inventory.Aquarium(data) > 0 then
		return "home"
	end
	if not onDock() then
		return "dock"
	end
	if not holdingRod() then
		return "rod"
	end
	return "cast"
end

local function setStep(id: string)
	if current == id then
		return
	end
	current = id
	local i = INDEX[id]
	stepLabel.Text = ("PASO %d/%d"):format(i, #STEPS)
	textLabel.Text = STEPS[i].Text
	UIKit.pop(card, 0.85)
	UIKit.playSound("Click")
end

local function stop()
	running = false
	if loop then
		loop:Disconnect()
		loop = nil
	end
	hidePointer()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if fromAttachment then
		fromAttachment:Destroy()
		fromAttachment = nil
	end
	if target then
		target:Destroy()
		target = nil
	end
	card.Visible = false
end

local function finish(skipped: boolean)
	if not running then
		return
	end
	finished = true
	stop()
	local result = State.Call("FinishTutorial", skipped)
	if skipped then
		HUD.Toast("Tutorial saltado. ¡Suerte pescando!", "Info")
	elseif result.ok then
		local reward = tonumber(result.Reward) or 0
		UIKit.playSound("Fanfare")
		UIKit.confetti(80)
		HUD.Toast(("🎉 ¡Tutorial completado!%s Pesca más memes y mejora tu caña en la tienda"):format(
			if reward > 0 then (" +%s 🪙."):format(Util.formatShort(reward)) else ""), "Success")
	end
end

local function tick()
	local data = State.Data
	if not running or not data then
		return
	end
	if data.TutorialDone then
		stop()
		return
	end
	local step = computeStep(data)
	-- cobrar: el cobrador tenía monedas y se ha vaciado → lo ha pisado
	local bank = player:GetAttribute("PlotBank")
	bank = if type(bank) == "number" then bank else 0
	if step == "collect" and lastBank > 0 and bank == 0 then
		collected = true
	end
	lastBank = bank
	if collected then
		finish(false)
		return
	end
	setStep(step)

	local plot = plotFolder()
	if step == "dock" then
		local index = player:GetAttribute("PlotIndex")
		pointAt(if type(index) == "number" and index > 0 then GameConfig.DockSpot(index) else nil)
	elseif step == "home" then
		local spawnPart = plot and plot:FindFirstChild("Spawn") :: BasePart?
		pointAt(spawnPart and spawnPart.Position)
	elseif step == "collect" then
		local collector = plot and plot:FindFirstChild("Collector") :: BasePart?
		pointAt(collector and collector.Position)
	else
		hidePointer()
	end
	-- durante la inmersión la tarjeta se queda arriba pero más discreta
	card.BackgroundTransparency = if step == "dive" then 0.35 else 0.05
end

local function start()
	if running or finished then
		return
	end
	running = true
	collected = false
	current = nil
	card.Visible = true
	local acc = 0
	loop = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			tick()
		end
	end)
end

function Tutorial.Init()
	gui = UIKit.new("ScreenGui", { Name = "PescaTutorial", ResetOnSpawn = false, DisplayOrder = 8,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	card = UIKit.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(560, 92), BackgroundColor3 = T.PanelDark, Visible = false, Parent = gui })
	UIKit.corner(card, 16)
	UIKit.stroke(card, 4, T.Primary)
	UIKit.responsive(card)
	stepLabel = UIKit.label({ Name = "Step", Text = "PASO 1/6", Size = UDim2.new(0, 120, 0, 26), Position = UDim2.fromOffset(14, 8),
		Font = T.FontTitle, TextColor3 = T.Primary, TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { MaxSize = 22 })
	textLabel = UIKit.label({ Name = "Text", Size = UDim2.new(1, -130, 0, 50), Position = UDim2.fromOffset(14, 34),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { MaxSize = 22 })
	local skip = UIKit.button({ Name = "Skip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(96, 40), Parent = card }, { Text = "Saltar", Color = T.PanelLight, TextSize = 20 })
	skip.Activated:Connect(function()
		finish(true)
	end)

	State.Changed:Connect(function(data)
		if data.TutorialDone then
			if running then
				stop()
			end
		elseif not running then
			start()
		end
	end)
	if State.Data and not State.Data.TutorialDone then
		start()
	end
end

return Tutorial

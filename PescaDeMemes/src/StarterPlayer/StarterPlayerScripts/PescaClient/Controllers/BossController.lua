--[[
	PescaDeMemes • BossController (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > BossController

	Lo que ves del JEFE DEL RÍO (las reglas y los premios son del servidor, BossService):
	  · Barra arriba: nombre, vida (de todo el servidor), tiempo y cuánto llevas aportado.
	  · Botón grande 🎣 ¡TIRA! (o tecla R). Cada tirón: sedal tenso desde TU caña hasta la ballena, nota que sube,
	    números que saltan y un pequeño temblor. El servidor decide si cuenta.
	  · Animación local del modelo: emerge, se balancea y se revuelve; al ganar salta del agua, al escapar se hunde.
	  · Al acabar: celebración según lo que te tocó (monedas o el meme DIOS).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Boss = require(Root.Config.Boss)
local Remotes = require(Root.Shared.Remotes)
local Util = require(Root.Shared.Util)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local HUD = require(Controllers.HUD)
local DiveScene = require(Controllers.DiveScene)

local T = UIKit.Theme
local RGB = Color3.fromRGB
local player = Players.LocalPlayer
local BossController = {}

local bar: Frame
local hpFill: Frame
local hpText: TextLabel
local timeText: TextLabel
local myText: TextLabel
local pullButton: TextButton
local myPower = 0
local combo = 0
local lastLocalPull = 0
local lastRiverToast = 0
local beam: Beam? = nil
local beamTo: Attachment? = nil
local beamUntil = 0
local spawnedAt = 0
local baseCFrame: CFrame? = nil
local trackedModel: Model? = nil
local shownRatio = -1

local function active(): boolean
	return Workspace:GetAttribute("BossActive") == true
end

local function bossModel(): Model?
	local map = Workspace:FindFirstChild("Map")
	local m = (map and map:FindFirstChild("RiverBoss")) or Workspace:FindFirstChild("RiverBoss")
	return if m and m:IsA("Model") then m else nil
end

local function rodTip(): Attachment?
	local character = player.Character
	local tool = character and character:FindFirstChild(GameConfig.RodToolName)
	local tip = tool and tool:FindFirstChild("RodTip", true)
	return if tip and tip:IsA("Attachment") then tip else nil
end

-- número que salta desde el botón ("-1.6")
local function popNumber(text: string)
	local label = UIKit.label({ Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(120, 40),
		Position = UDim2.new(0.5, math.random(-60, 60), 0, -10), Font = T.FontTitle, TextColor3 = T.Primary, Parent = pullButton }, { Stroke = 3 })
	UIKit.tween(label, 0.6, { Position = label.Position - UDim2.fromOffset(0, 70), TextTransparency = 1 })
	task.delay(0.65, function()
		label:Destroy()
	end)
end

local function pull()
	if not active() or DiveScene.Active() then
		return
	end
	local now = os.clock()
	if now - lastLocalPull < Boss.PullCooldown then
		return
	end
	if not rodTip() then
		HUD.Toast("🎣 Saca la caña (tecla 1) y ve al río para tirar", "Warning")
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or not Boss.CanPullAt(hrp.Position) then
		if now - lastRiverToast > 1.5 then
			lastRiverToast = now
			HUD.Toast("🌊 Ve al río (tu muelle o el puente) para tirar", "Warning")
		end
		return
	end
	combo = if now - lastLocalPull < 0.6 then combo + 1 else 1 -- tirones seguidos: la nota sube
	lastLocalPull = now
	Remotes.Get("BossPull"):FireServer()
	local power = Boss.PowerForRod(State.Data and State.Data.EquippedRod)
	myPower += power
	UIKit.playSound("Tug", 1 + math.min(combo, 12) * 0.04)
	UIKit.pop(pullButton, 0.9)
	UIKit.shake3D(0.12, 0.08)
	popNumber(("-%.1f"):format(power))
	beamUntil = now + 0.35
end

local function refreshBar()
	local result = Workspace:GetAttribute("BossResult")
	local on = active() or result == "win" or result == "escape"
	bar.Visible = on
	pullButton.Visible = active() and not DiveScene.Active()
	if not on then
		return
	end
	local hp = Workspace:GetAttribute("BossHP") or 0
	local maxHp = math.max(1, Workspace:GetAttribute("BossMaxHP") or 1)
	local ratio = math.clamp(hp / maxHp, 0, 1)
	if ratio ~= shownRatio then
		shownRatio = ratio
		UIKit.tween(hpFill, 0.15, { Size = UDim2.fromScale(ratio, 1) })
	end
	hpText.Text = ("%d / %d"):format(hp, maxHp)
	local ends = Workspace:GetAttribute("BossEnds") or 0
	local left = math.max(0, ends - Workspace:GetServerTimeNow())
	timeText.Text = if result == "win" then "🏆 ¡SACADA!" elseif result == "escape" then "💨 Se escapó"
		else ("⏳ %d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
	myText.Text = ("Tu fuerza: %s"):format(Util.formatShort(math.floor(myPower)))
end

-- animación local del modelo gigante (el servidor solo lo coloca)
local function animate()
	local model = bossModel()
	if model ~= trackedModel then
		trackedModel = model
		baseCFrame = model and model:GetPivot()
		spawnedAt = os.clock()
		myPower = 0
		if model then
			UIKit.playSound("Boom", 0.6)
			UIKit.shake3D(0.8, 0.8)
			UIKit.flash(RGB(80, 160, 255), 0.35)
		end
	end
	if not model or not baseCFrame then
		return
	end
	local t = os.clock() - spawnedAt
	local result = Workspace:GetAttribute("BossResult")
	local rise = math.min(1, t / 2.5) * 2.2 -- emerge del agua
	local y = rise + math.sin(t * 1.3) * 0.6
	local yaw = math.sin(t * 0.7) * 0.15 + (if active() and os.clock() < beamUntil then math.sin(t * 25) * 0.04 else 0)
	if result == "win" then
		y += math.min(1, (os.clock() - (model:GetAttribute("EndT") or os.clock())) / 1.5) * 14 -- salta fuera del agua
	elseif result == "escape" then
		y -= math.min(1, (os.clock() - (model:GetAttribute("EndT") or os.clock())) / 2) * 16 -- se hunde
	end
	if (result == "win" or result == "escape") and model:GetAttribute("EndT") == nil then
		model:SetAttribute("EndT", os.clock()) -- local: marca cuándo empezó la salida
	end
	model:PivotTo(baseCFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, math.sin(t * 0.9) * 0.05))
	-- sedal tenso desde tu caña al jefe mientras tiras
	local tip = rodTip()
	local showBeam = active() and tip ~= nil and os.clock() < beamUntil
	if showBeam and tip then
		if not beamTo or beamTo.Parent ~= model.PrimaryPart then
			if beamTo then
				beamTo:Destroy()
			end
			beamTo = UIKit.new("Attachment", { Name = "BossLine", Position = Vector3.new(0, 4 * Boss.ModelScale, -3 * Boss.ModelScale),
				Parent = model.PrimaryPart })
		end
		if not beam then
			beam = UIKit.new("Beam", { Name = "BossBeam", Width0 = 0.12, Width1 = 0.12, FaceCamera = true, LightInfluence = 0,
				Color = ColorSequence.new(RGB(255, 255, 255)), Parent = Workspace.Terrain })
		end
		local b = beam :: Beam
		b.Attachment0 = tip
		b.Attachment1 = beamTo
		b.Enabled = true
	elseif beam then
		beam.Enabled = false
	end
end

function BossController.Init()
	local gui = UIKit.new("ScreenGui", { Name = "PescaBoss", ResetOnSpawn = false, DisplayOrder = 9,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	local meme = Memes.Get(Boss.MemeId)
	bar = UIKit.new("Frame", { Name = "BossBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(560, 92), BackgroundColor3 = T.PanelDark, Visible = false, Parent = gui })
	UIKit.corner(bar, 16)
	UIKit.stroke(bar, 4, Memes.Rarities.GOD.Color)
	UIKit.responsive(bar)
	UIKit.label({ Text = ("🐋 JEFE DEL RÍO · %s"):format(if meme then meme.Name else "?"), Size = UDim2.new(1, -150, 0, 30),
		Position = UDim2.fromOffset(14, 6), Font = T.FontTitle, TextColor3 = Memes.Rarities.GOD.Color, TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar }, { Stroke = 3, MaxSize = 24 })
	timeText = UIKit.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(140, 30), Position = UDim2.new(1, -12, 0, 6),
		Font = T.FontTitle, TextXAlignment = Enum.TextXAlignment.Right, Parent = bar }, { Stroke = 2, MaxSize = 22 })
	local hp = UIKit.new("Frame", { Size = UDim2.new(1, -28, 0, 24), Position = UDim2.fromOffset(14, 40), BackgroundColor3 = T.Panel, Parent = bar })
	UIKit.corner(hp, 12)
	hpFill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(230, 60, 80), Parent = hp })
	UIKit.corner(hpFill, 12)
	UIKit.gradient(hpFill, { RGB(255, 120, 120), RGB(200, 30, 60) }, 90)
	hpText = UIKit.label({ Text = "", Size = UDim2.fromScale(1, 1), Font = T.FontTitle, ZIndex = 3, Parent = hp }, { Stroke = 2, MaxSize = 18 })
	myText = UIKit.label({ Text = "", Size = UDim2.new(1, -28, 0, 20), Position = UDim2.fromOffset(14, 68), Font = T.Font, TextColor3 = T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = bar }, { MaxSize = 16 })

	pullButton = UIKit.button({ Name = "BossPull", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(260, 86), Visible = false, Parent = gui },
		{ Color = RGB(255, 80, 120), Text = if UIKit.IsTouch() then "🎣 ¡TIRA!" else "🎣 ¡TIRA! (R)", TextSize = 34, Radius = 20, StrokeThickness = 5 })
	UIKit.responsive(pullButton)
	pullButton.Activated:Connect(pull)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.R then
			pull()
		end
	end)

	Remotes.Get("BossResult").OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then
			return
		end
		if info.God then
			local god = Memes.Rarities.GOD
			UIKit.celebrate(god.Order, god.Color)
			HUD.Toast(("🐋 ¡TE HA TOCADO EL MEME DIOS! +%s MemeCoins · está en tu mochila"):format(Util.formatShort(info.Coins or 0)), "Success")
		elseif info.Win then
			UIKit.celebrate(5, Memes.Rarities.GOD.Color)
			HUD.Toast(("🐋 ¡Jefe sacado! Tu parte: +%s MemeCoins"):format(Util.formatShort(info.Coins or 0)), "Success")
		end
	end)
	Workspace:GetAttributeChangedSignal("BossResult"):Connect(function()
		if Workspace:GetAttribute("BossResult") == "escape" then
			UIKit.playSound("Fail")
		end
	end)

	RunService.RenderStepped:Connect(animate)
	task.spawn(function()
		while true do
			refreshBar()
			task.wait(0.2)
		end
	end)
end

return BossController

--[[
	PescaDeMemes • FightUI (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > FightUI

	La PELEA con un meme que pesa más que tu caña (durante la inmersión):
	  1. DECISIÓN: foto del meme, kg vs. capacidad y % de aguante del sedal → ⚔️ PELEAR o ✂️ SOLTAR.
	  2. PELEA: mantener click/toque/espacio = más tensión. Indicador en la zona verde = el progreso sube.
	     Zona roja demasiado tiempo = se rompe el sedal. Hay 3 TIRONES fuertes (los resuelve el servidor).
	FightUI.Decide(info) → "fight" | "release"            (espera a que el jugador elija)
	FightUI.Run(info, onTug) → (won, reason, tugResult?)   reason: "win" | "escape" | "snap" | "tug" | "error"
	onTug(inGreen) llama al servidor y devuelve su respuesta { ok, Survived, Broke, Summary }.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local FishMath = require(Root.Shared.FishMath)
local FishBehaviors = require(Root.Shared.FishBehaviors)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)

local F = GameConfig.Fishing
local T = UIKit.Theme
local FightUI = {}

local gui: ScreenGui
local decision: Frame
local fight: Frame
local refs: { [string]: any } = {}
local decisionRefs: { [string]: any } = {}
local holding = false
local choice: string? = nil
local cancelToken = 0 -- FightUI.Hide() lo sube: termina cualquier pelea en curso

local function isHold(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.F
end

-- canNet = llevas una Red Dorada equipada y el meme no es secreto → aparece el botón 🥅 (devuelve "net").
function FightUI.Decide(info: any, canNet: boolean?): string
	local rarity = Memes.Rarities[info.Rarity] or Memes.Rarities.COMMON
	local meme = Memes.Get(info.MemeId)
	local d = decisionRefs
	d.Name.Text = if meme then meme.Name else "???"
	d.Name.TextColor3 = rarity.Color
	d.Weight.Text = ("⚖️ ~%s   /   🎣 %s"):format(FishMath.FormatWeight(info.EstimatedWeight), FishMath.FormatWeight(info.Capacity))
	local survival = info.Survival
	d.SurvivalFill.Size = UDim2.fromScale(math.max(0.02, survival), 1)
	d.SurvivalFill.BackgroundColor3 = if survival > 0.4 then T.Primary elseif survival > 0.1 then T.PrimaryDark else T.Danger
	d.SurvivalText.Text = "Aguante del sedal: " .. FishMath.FormatPercent(survival) .. " · si pierdes, el sedal sube de golpe"
	if d.Icon then
		d.Icon:Destroy()
	end
	d.Icon = UIKit.memeIcon(info.MemeId, { Name = "Icon", Size = UDim2.fromOffset(110, 110), Position = UDim2.fromOffset(20, 64),
		Parent = decision }, { Spin = 1.2 })
	UIKit.stroke(d.Icon, 4, rarity.Color)
	decisionRefs.Net.Visible = canNet == true
	decision.Visible = true
	UIKit.pop(decision, 0.7)
	UIKit.playSound("Bite")
	choice = nil
	while choice == nil and decision.Parent do
		task.wait()
	end
	decision.Visible = false
	return choice or "release"
end

function FightUI.Run(info: any, onTug: (boolean) -> any): (boolean, string, any?)
	local params = info.Params
	local meme = Memes.Get(info.MemeId)
	local rarity = Memes.Rarities[info.Rarity] or Memes.Rarities.COMMON
	refs.Name.Text = (if meme then meme.Name else "???") .. "  ·  " .. (Memes.PersonalityNames[info.Personality] or "")
	refs.Name.TextColor3 = rarity.Color
	refs.Weight.Text = ("⚖️ ~%s / 🎣 %s"):format(FishMath.FormatWeight(info.EstimatedWeight), FishMath.FormatWeight(info.Capacity))
	fight.Visible = true
	UIKit.pop(fight, 0.8)

	local behavior = FishBehaviors.new(info.Personality, params.GreenWidth, F.RedZoneStart)
	local tugs = info.Tugs or 0
	local nextTug = 1
	local tugState: string = "none" -- "none" | "warning" | "waiting"
	local tugTimer = 0
	local pos, vel = 0.3, 0
	local progress = F.StartProgress
	local redTime = 0
	local result: { won: boolean, reason: string, tug: any? }? = nil
	local myToken = cancelToken
	holding = false

	refs.Green.Size = UDim2.fromScale(params.GreenWidth, 1)
	refs.Red.Size = UDim2.fromScale(1 - F.RedZoneStart, 1)
	refs.Red.Position = UDim2.fromScale(F.RedZoneStart, 0)
	for i, marker in ipairs(refs.TugMarkers) do
		marker.Visible = i <= tugs
		marker.BackgroundColor3 = T.Primary
	end
	refs.Survival.Text = ("Aguante del sedal: %s"):format(FishMath.FormatPercent(info.Survival))
	refs.Tug.Visible = false

	local function finish(won: boolean, reason: string, tug: any?)
		if not result then
			result = { won = won, reason = reason, tug = tug }
		end
	end

	local conn = RunService.RenderStepped:Connect(function(dt)
		if result then
			return
		end
		if myToken ~= cancelToken then
			finish(false, "error")
			return
		end
		dt = math.min(dt, 0.05)
		local center, behaviorPull, event = behavior:Update(dt)
		if event == "jump" then
			UIKit.shake(refs.Bar)
		end
		if tugState ~= "waiting" then
			local push = math.min(2.8, params.Pull * behaviorPull * 0.9)
			local accel = (if holding then 3.4 else -2.0) - push
			vel = math.clamp((vel + accel * dt) * (0.9 ^ (dt * 60)), -1.4, 1.4)
			pos += vel * dt
			if pos <= 0 then
				pos, vel = 0, 0
			elseif pos >= 1 then
				pos, vel = 1, 0
			end
		end
		local inGreen = math.abs(pos - center) <= params.GreenWidth / 2
		if tugState ~= "waiting" then
			local rate = if inGreen then params.FillRate else -params.FillRate * F.DrainFactor * (if pos <= 0 then 1.5 else 1)
			progress = math.clamp(progress + rate * dt, 0, 1)
			if nextTug <= tugs then
				progress = math.min(progress, 0.97)
			end
			if pos >= F.RedZoneStart then
				redTime += dt
			else
				redTime = math.max(0, redTime - dt)
			end
		end

		-- tirones fuertes: el servidor decide si el sedal aguanta
		if nextTug <= tugs then
			if tugState == "none" and progress >= F.TugThresholds[nextTug] then
				tugState = "warning"
				tugTimer = F.TugWarning
				refs.Tug.Text = "⚡ ¡TIRÓN! Quédate en la zona verde"
				refs.Tug.Visible = true
				UIKit.pop(refs.Tug, 1.4)
			elseif tugState == "warning" then
				tugTimer -= dt
				if tugTimer <= 0 then
					tugState = "waiting"
					UIKit.playSound("Tug")
					UIKit.shake(refs.Bar)
					local wasGreen = inGreen
					task.spawn(function()
						local r = onTug(wasGreen)
						if result then
							return
						end
						if r.ok and r.Survived then
							refs.TugMarkers[nextTug].BackgroundColor3 = T.Success
							refs.Tug.Text = "✅ ¡AGUANTÓ!"
							nextTug += 1
							tugState = "none"
							task.delay(0.8, function()
								if refs.Tug.Text == "✅ ¡AGUANTÓ!" then
									refs.Tug.Visible = false
								end
							end)
						elseif r.ok then
							refs.TugMarkers[nextTug].BackgroundColor3 = T.Danger
							finish(false, "tug", r)
						else
							finish(false, "error", r)
						end
					end)
				end
			end
		end

		refs.Green.Position = UDim2.fromScale(center - params.GreenWidth / 2, 0)
		refs.Green.BackgroundColor3 = if inGreen then T.Success else Color3.fromRGB(60, 150, 80)
		refs.Indicator.Position = UDim2.new(pos, 0, 0.5, 0)
		refs.Red.BackgroundTransparency = if redTime > 0 then 0.1 + 0.3 * math.abs(math.sin(os.clock() * 20)) else 0.35
		refs.ProgressFill.Size = UDim2.fromScale(progress, 1)
		refs.ProgressFill.BackgroundColor3 = if progress > 0.66 then T.Success elseif progress > 0.33 then T.Primary else T.Danger

		if redTime > params.RedTolerance then
			finish(false, "snap")
		elseif progress <= 0 then
			finish(false, "escape")
		elseif progress >= 1 and nextTug > tugs then
			finish(true, "win")
		end
	end)
	while not result do
		task.wait()
	end
	conn:Disconnect()
	holding = false
	local r = result :: any
	if not r.won then
		if r.reason ~= "error" then -- cancelado/sin conexión: sin chasquido
			UIKit.playSound(if r.reason == "escape" then "Fail" else "Snap") -- se escapa: "uuhhh" · se rompe: chasquido
		end
		UIKit.shake(fight)
	end
	task.delay(0.3, function()
		fight.Visible = false
	end)
	return r.won, r.reason, r.tug
end

function FightUI.Hide()
	cancelToken += 1
	choice = choice or "release"
	decision.Visible = false
	fight.Visible = false
end

function FightUI.Init()
	gui = UIKit.new("ScreenGui", { Name = "PescaFight", ResetOnSpawn = false, DisplayOrder = 8,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })

	-- ===== Decisión (PELEAR / SOLTAR) =====
	decision = UIKit.new("Frame", { Name = "Decision", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(500, 340), BackgroundColor3 = T.Panel, Visible = false, Parent = gui })
	UIKit.corner(decision, 22)
	UIKit.stroke(decision, 5, T.PrimaryDark)
	UIKit.responsive(decision)
	local d = decisionRefs
	d.Title = UIKit.label({ Text = "⚔️ ¡PESA MÁS QUE TU CAÑA!", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 10),
		Font = T.FontTitle, TextColor3 = T.Primary, Parent = decision }, { Stroke = 3, MaxSize = 32 })
	d.Name = UIKit.label({ Text = "???", Size = UDim2.new(1, -160, 0, 34), Position = UDim2.fromOffset(146, 64), Font = T.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = decision }, { Stroke = 3, MaxSize = 30 })
	d.Weight = UIKit.label({ Text = "", Size = UDim2.new(1, -160, 0, 30), Position = UDim2.fromOffset(146, 100), Font = T.Font,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = decision }, { MaxSize = 24 })
	local survBar = UIKit.new("Frame", { Size = UDim2.new(1, -166, 0, 24), Position = UDim2.fromOffset(146, 140), BackgroundColor3 = T.PanelDark, Parent = decision })
	UIKit.corner(survBar, 12)
	UIKit.stroke(survBar, 3)
	d.SurvivalFill = UIKit.new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = T.Primary, Parent = survBar })
	UIKit.corner(d.SurvivalFill, 12)
	d.SurvivalText = UIKit.label({ Text = "", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 182), Font = T.Font,
		Parent = decision }, { MaxSize = 18 })
	local row = UIKit.new("Frame", { Size = UDim2.new(1, -40, 0, 66), Position = UDim2.new(0, 20, 1, -80), BackgroundTransparency = 1, Parent = decision })
	UIKit.list(row, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	local fightBtn = UIKit.button({ LayoutOrder = 1, Size = UDim2.fromOffset(200, 62), Parent = row }, { Color = T.Danger, Text = "⚔️ PELEAR", TextSize = 30 })
	local releaseBtn = UIKit.button({ LayoutOrder = 2, Size = UDim2.fromOffset(200, 62), Parent = row }, { Color = T.PanelLight, Text = "✂️ SOLTAR", TextSize = 30 })
	fightBtn.Activated:Connect(function()
		choice = "fight"
	end)
	releaseBtn.Activated:Connect(function()
		choice = "release"
	end)
	-- Red Dorada: engancharlo sin pelear (encima de los otros dos botones)
	d.Net = UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -88), Size = UDim2.fromOffset(300, 40), Visible = false,
		Parent = decision }, { Color = T.Coin, Text = "🥅 Usar Red Dorada (sin pelear)", TextSize = 20 })
	d.Net.Activated:Connect(function()
		choice = "net"
	end)

	-- ===== Pelea =====
	fight = UIKit.new("Frame", { Name = "Fight", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(640, 190), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, Visible = false, Parent = gui })
	UIKit.corner(fight, 20)
	UIKit.stroke(fight, 4)
	UIKit.responsive(fight)
	refs.Name = UIKit.label({ Text = "", Size = UDim2.new(0.62, -10, 0, 30), Position = UDim2.fromOffset(16, 8), Font = T.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = fight }, { Stroke = 2, MaxSize = 26 })
	refs.Weight = UIKit.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0.38, -10, 0, 30),
		Position = UDim2.new(1, -16, 0, 8), Font = T.Font, TextXAlignment = Enum.TextXAlignment.Right, Parent = fight }, { MaxSize = 22 })
	local bar = UIKit.new("Frame", { Name = "Bar", Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -40, 0, 46),
		BackgroundColor3 = T.PanelDark, Parent = fight })
	UIKit.corner(bar, 12)
	UIKit.stroke(bar, 3)
	refs.Bar = bar
	refs.Green = UIKit.new("Frame", { Name = "Green", Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = T.Success, Parent = bar })
	UIKit.corner(refs.Green, 10)
	refs.Red = UIKit.new("Frame", { Name = "Red", BackgroundColor3 = T.Danger, BackgroundTransparency = 0.35, Parent = bar })
	UIKit.corner(refs.Red, 10)
	UIKit.label({ Text = "💥", Size = UDim2.fromScale(1, 1), Parent = refs.Red }, { Stroke = false })
	refs.Indicator = UIKit.new("Frame", { Name = "Indicator", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 10, 1, 18),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = bar })
	UIKit.corner(refs.Indicator, 5)
	UIKit.stroke(refs.Indicator, 3)
	local progress = UIKit.new("Frame", { Name = "Progress", Position = UDim2.fromOffset(20, 106), Size = UDim2.new(1, -40, 0, 22),
		BackgroundColor3 = T.PanelDark, Parent = fight })
	UIKit.corner(progress, 11)
	UIKit.stroke(progress, 3)
	refs.ProgressFill = UIKit.new("Frame", { Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = T.Primary, Parent = progress })
	UIKit.corner(refs.ProgressFill, 11)
	refs.TugMarkers = {}
	for i, threshold in ipairs(F.TugThresholds) do
		local m = UIKit.new("Frame", { Name = "Tug" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(threshold, 0.5),
			Size = UDim2.fromOffset(16, 30), BackgroundColor3 = T.Primary, ZIndex = 4, Parent = progress })
		UIKit.corner(m, 4)
		UIKit.stroke(m, 2)
		refs.TugMarkers[i] = m
	end
	refs.Survival = UIKit.label({ Text = "", Size = UDim2.new(0.6, -20, 0, 24), Position = UDim2.fromOffset(16, 140), Font = T.Font,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = fight }, { MaxSize = 20 })
	UIKit.label({ Text = "Mantén click / toque / espacio = más tensión", AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0.45, 0, 0, 24),
		Position = UDim2.new(1, -16, 0, 140), Font = T.Font, TextColor3 = T.TextDim, TextXAlignment = Enum.TextXAlignment.Right,
		Parent = fight }, { MaxSize = 17 })
	refs.Tug = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(560, 50), Font = T.FontTitle, TextColor3 = T.Coin, Visible = false, Parent = fight }, { Stroke = 4, MaxSize = 40 })

	UserInputService.InputBegan:Connect(function(input, processed)
		if fight.Visible and isHold(input) and (not processed or input.UserInputType == Enum.UserInputType.Touch) then
			holding = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isHold(input) then
			holding = false
		end
	end)
end

return FightUI

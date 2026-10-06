--[[
	PescaDeMemes • PlotController (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > PlotController

	Ayudas visuales de la parcela (solo para ti):
	  · Marca "🏠 TU PARCELA" visible desde lejos sobre tu cartel.
	  · Oculta los pedestales de las parcelas de otros (no puedes usarlos).
	  · Mientras llevas un meme: aviso arriba + botón "🎒 A la mochila" + rastro hasta tu parcela.
	El estado viene de los atributos que pone el servidor: PlotIndex y Carrying.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local HUD = require(Controllers.HUD)

local T = UIKit.Theme
local player = Players.LocalPlayer
local PlotController = {}

local banner: Frame
local bannerText: TextLabel
local marker: BillboardGui? = nil
local trail: Beam? = nil
local trailAttachments: { Attachment } = {}

local function plotFolder(index: number): Instance?
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index)
end

local function myPlotIndex(): number
	local index = player:GetAttribute("PlotIndex")
	return if type(index) == "number" then index else 0
end

-- Solo puedes interactuar con los pedestales de tu parcela.
local function updatePrompts()
	local mine = myPlotIndex()
	for index = 1, GameConfig.Plots.Count do
		local plot = plotFolder(index)
		local pedestals = plot and plot:FindFirstChild("Pedestals")
		if pedestals then
			for _, prompt in ipairs(pedestals:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") then
					prompt.Enabled = index == mine
				end
			end
		end
	end
end

local function updateMarker()
	if marker then
		marker:Destroy()
		marker = nil
	end
	local plot = plotFolder(myPlotIndex())
	local ownerSign = plot and plot:FindFirstChild("OwnerSign") :: BasePart?
	if not ownerSign then
		return
	end
	local bb = UIKit.new("BillboardGui", { Name = "MyPlotMarker", Size = UDim2.fromOffset(200, 60), StudsOffsetWorldSpace = Vector3.new(0, 7, 0),
		AlwaysOnTop = true, MaxDistance = 1000, LightInfluence = 0, Parent = ownerSign })
	UIKit.label({ Text = "🏠 TU PARCELA", Size = UDim2.fromScale(1, 1), Font = T.FontTitle, TextColor3 = T.Primary, Parent = bb }, { Stroke = 3 })
	marker = bb
end

local function clearTrail()
	if trail then
		trail:Destroy()
		trail = nil
	end
	for _, a in ipairs(trailAttachments) do
		a:Destroy()
	end
	table.clear(trailAttachments)
end

local function updateTrail(active: boolean)
	clearTrail()
	if not active then
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local plot = plotFolder(myPlotIndex())
	local spawnPart = plot and plot:FindFirstChild("Spawn")
	if not hrp or not spawnPart then
		return
	end
	local a0 = UIKit.new("Attachment", { Name = "TrailFrom", Position = Vector3.new(0, -2.5, 0), Parent = hrp })
	local a1 = UIKit.new("Attachment", { Name = "TrailTo", Parent = spawnPart })
	trailAttachments = { a0, a1 }
	trail = UIKit.new("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 1.2, Width1 = 1.2, FaceCamera = true, LightInfluence = 0,
		Color = ColorSequence.new(T.Primary), Transparency = NumberSequence.new(0.35), Segments = 20, Parent = hrp })
end

local function updateCarry()
	local carrying = player:GetAttribute("Carrying")
	local active = type(carrying) == "string" and carrying ~= ""
	banner.Visible = active
	if active then
		local data = State.Data
		local catch = data and data.Catches[carrying :: string]
		local meme = catch and Memes.Get(catch.MemeId)
		bannerText.Text = ("🏠 Llevas %s %s → colócalo en un pedestal de tu parcela"):format(meme and meme.Emoji or "", meme and meme.Name or "un meme")
		UIKit.pop(banner, 0.8)
	end
	updateTrail(active)
end

function PlotController.Init()
	local gui = UIKit.new("ScreenGui", { Name = "PescaPlot", ResetOnSpawn = false, DisplayOrder = 7,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	banner = UIKit.new("Frame", { Name = "CarryBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(640, 60), BackgroundColor3 = T.PanelDark, Visible = false, Parent = gui })
	UIKit.corner(banner, 16)
	UIKit.stroke(banner, 4, T.Primary)
	UIKit.responsive(banner)
	bannerText = UIKit.label({ Text = "", Size = UDim2.new(1, -190, 1, -12), Position = UDim2.fromOffset(12, 6), Font = T.Font,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = banner }, { MaxSize = 22 })
	local drop = UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(170, 46),
		Parent = banner }, { Color = T.Success, Text = "🎒 A la mochila", TextSize = 20 })
	drop.Activated:Connect(function()
		local r = State.Call("DropCarry")
		if not r.ok and r.err then
			HUD.Toast(r.err, "Error")
		end
	end)

	player:GetAttributeChangedSignal("PlotIndex"):Connect(function()
		updatePrompts()
		updateMarker()
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		updateCarry()
	end)
	-- el mapa lo construye el servidor; esperamos a que exista antes de tocar parcelas
	task.spawn(function()
		local map = Workspace:WaitForChild("Map", 30)
		if map then
			map:WaitForChild("Plots", 30)
		end
		updatePrompts()
		updateMarker()
		updateCarry()
	end)
end

return PlotController

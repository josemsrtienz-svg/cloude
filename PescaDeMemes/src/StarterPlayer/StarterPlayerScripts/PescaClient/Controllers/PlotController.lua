--[[
	PescaDeMemes • PlotController (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > PlotController

	Ayudas visuales de la parcela (solo para ti):
	  · Marca "🏠 TU PARCELA" visible desde lejos sobre tu cartel.
	  · "Recoger" solo aparece en los huecos OCUPADOS de TU parcela (el servidor marca "Occupied").
	  · Con la mochila-acuario llena: aviso arriba + rastro amarillo hasta tu parcela para descargar.
	El estado viene de los atributos que pone el servidor: PlotIndex y Occupied (en cada hueco).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Inventory = require(Root.Shared.Inventory)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)

local T = UIKit.Theme
local player = Players.LocalPlayer
local PlotController = {}

local banner: Frame
local marker: BillboardGui? = nil
local trail: Beam? = nil
local trailAttachments: { Attachment } = {}
local watched: { [Instance]: RBXScriptConnection } = {}

local function plotFolder(index: number): Instance?
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index)
end

local function myPlotIndex(): number
	local index = player:GetAttribute("PlotIndex")
	return if type(index) == "number" then index else 0
end

-- "Recoger" solo en los huecos ocupados de tu parcela.
local function updatePrompts()
	local mine = myPlotIndex()
	for index = 1, GameConfig.Plots.Count do
		local plot = plotFolder(index)
		local spots = plot and plot:FindFirstChild("Spots")
		if spots then
			for _, spot in ipairs(spots:GetChildren()) do
				local prompt = spot:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt.Enabled = index == mine and spot:GetAttribute("Occupied") == true
				end
				if not watched[spot] then
					watched[spot] = spot:GetAttributeChangedSignal("Occupied"):Connect(updatePrompts)
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
	local bb = UIKit.new("BillboardGui", { Name = "MyPlotMarker", Size = UDim2.fromOffset(220, 64), StudsOffsetWorldSpace = Vector3.new(0, 7, 0),
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

local function setTrail(active: boolean)
	if active == (trail ~= nil) then
		return
	end
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

-- Acuario lleno → aviso + rastro hasta casa.
local function updateFull()
	local data = State.Data
	local full = data ~= nil and Inventory.Free(data) < 1
	if full and not banner.Visible then
		UIKit.pop(banner, 0.8)
	end
	banner.Visible = full
	setTrail(full)
end

function PlotController.Init()
	local gui = UIKit.new("ScreenGui", { Name = "PescaPlot", ResetOnSpawn = false, DisplayOrder = 7,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	banner = UIKit.new("Frame", { Name = "FullBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(600, 56), BackgroundColor3 = T.PanelDark, Visible = false, Parent = gui })
	UIKit.corner(banner, 16)
	UIKit.stroke(banner, 4, T.Primary)
	UIKit.responsive(banner)
	UIKit.label({ Text = "🐠 ¡Acuario lleno! Sigue el rastro hasta tu parcela para descargarlo", Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromOffset(10, 6), Font = T.Font, Parent = banner }, { MaxSize = 22 })

	player:GetAttributeChangedSignal("PlotIndex"):Connect(function()
		updatePrompts()
		updateMarker()
	end)
	State.Changed:Connect(updateFull)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		clearTrail()
		updateFull()
	end)
	-- el mapa lo construye el servidor; esperamos a que exista antes de tocar parcelas
	task.spawn(function()
		local map = Workspace:WaitForChild("Map", 30)
		if map then
			map:WaitForChild("Plots", 30)
		end
		updatePrompts()
		updateMarker()
		updateFull()
	end)
end

return PlotController

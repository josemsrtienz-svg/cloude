--[[
	PescaDeMemes • Ambience (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > Ambience

	Animaciones de ambiente, solo visuales y solo en tu pantalla:
	  · Los memes expuestos en las parcelas (etiqueta "PescaMemeDisplay") botan y se balancean,
	    cada uno a su ritmo, como en los juegos de "steal". Solo los que están cerca de la cámara.
	  · Al cobrar tu parcela, una lluvia de monedas sale del cobrador.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)

local Ambience = {}

local TAG = "PescaMemeDisplay"
local NEAR = 160 -- studs: más lejos no se anima (rendimiento)

type Entry = { Base: CFrame, Phase: number, Speed: number }
local displays: { [Model]: Entry } = {}

local function track(inst: Instance)
	if inst:IsA("Model") and not displays[inst] then
		displays[inst] = { Base = inst:GetPivot(), Phase = math.random() * 6, Speed = 0.8 + math.random() * 0.6 }
	end
end

local function coinBurst(at: Vector3)
	for _ = 1, 14 do
		local coin = UIKit.new("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.1, 1.1), Color = Color3.fromRGB(255, 200, 50),
			Material = Enum.Material.SmoothPlastic, Reflectance = 0.2, CanCollide = false, CanQuery = false, CanTouch = false,
			CFrame = CFrame.new(at) * CFrame.Angles(0, math.random() * 6, math.rad(90)), Parent = Workspace })
		coin.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), math.random(18, 30), math.random(-10, 10))
		coin.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), 0)
		task.delay(1.4, function()
			coin:Destroy()
		end)
	end
	UIKit.playSound("Coins")
end

function Ambience.Init()
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		track(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		displays[inst :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local now = os.clock()
		for model, e in pairs(displays) do
			if not model.Parent then
				displays[model] = nil
			elseif (e.Base.Position - camPos).Magnitude < NEAR then
				local t = now * e.Speed + e.Phase
				local hop = math.abs(math.sin(t * 2)) * 0.5
				model:PivotTo(e.Base * CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(t) * 0.35, math.sin(t * 2) * 0.04))
			end
		end
	end)

	-- lluvia de monedas al cobrar (el servidor pone PlotBank a 0)
	local player = Players.LocalPlayer
	local lastBank = player:GetAttribute("PlotBank")
	player:GetAttributeChangedSignal("PlotBank"):Connect(function()
		local bank = player:GetAttribute("PlotBank")
		if type(lastBank) == "number" and lastBank > 0 and bank == 0 then
			local index = player:GetAttribute("PlotIndex")
			local map = Workspace:FindFirstChild("Map")
			local plots = map and map:FindFirstChild("Plots")
			local plot = plots and type(index) == "number" and plots:FindFirstChild("Plot" .. index)
			local collector = plot and plot:FindFirstChild("Collector") :: BasePart?
			if collector then
				coinBurst(collector.Position + Vector3.new(0, 1, 0))
			end
		end
		lastBank = bank
	end)
end

return Ambience

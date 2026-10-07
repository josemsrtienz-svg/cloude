--[[
	PescaDeMemes • Inventory (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > Inventory

	Consultas sobre las capturas de un jugador (servidor y cliente).
	  · Una captura está en la PARCELA si su id está en data.Plot.
	  · Si no, va en la MOCHILA-ACUARIO de la espalda, que tiene una capacidad en kg.
	  · El TAMAÑO de un meme = su peso redondeado hacia arriba (un meme de 20 kg ocupa 20).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Rods = require(Root.Config.Rods)
local Util = require(Root.Shared.Util)

local Inventory = {}

function Inventory.SizeOf(weight: number): number
	return math.max(1, math.ceil(weight))
end

function Inventory.SlotOf(data: any, catchId: string): number?
	return table.find(data.Plot, catchId)
end

function Inventory.InPlot(data: any, catchId: string): boolean
	return table.find(data.Plot, catchId) ~= nil
end

-- Capturas que van en la mochila-acuario, de más a menos valiosas.
function Inventory.Aquarium(data: any): { any }
	local list = {}
	for id, c in pairs(data.Catches) do
		if not Inventory.InPlot(data, id) then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		return a.Time > b.Time
	end)
	return list
end

function Inventory.Capacity(data: any): number
	local tier = Rods.GetAquarium(data.AquariumTier) or Rods.Aquariums[1]
	return tier.Capacity
end

function Inventory.Used(data: any): number
	local used = 0
	for id, c in pairs(data.Catches) do
		if not Inventory.InPlot(data, id) then
			used += c.Size or Inventory.SizeOf(c.Weight)
		end
	end
	return used
end

function Inventory.Free(data: any): number
	return math.max(0, Inventory.Capacity(data) - Inventory.Used(data))
end

-- MemeCoins por minuto que genera UNA captura expuesta (única fórmula de ingresos).
function Inventory.CatchIncome(catch: any, rate: number): number
	return catch.Value * rate
end

-- MemeCoins por minuto que generan todos los memes expuestos en la parcela.
function Inventory.PlotIncomePerMinute(data: any, rate: number): number
	local total = 0
	for _, id in ipairs(data.Plot) do
		local c = id ~= "" and data.Catches[id]
		if c then
			total += Inventory.CatchIncome(c, rate)
		end
	end
	return total
end

-- Texto de un ingreso por minuto (con un decimal si es pequeño, para no mentir con "1/min").
function Inventory.FormatIncome(perMinute: number): string
	if perMinute < 10 then
		return string.format("%.1f/min", perMinute)
	end
	return Util.formatShort(math.floor(perMinute + 0.5)) .. "/min"
end

return Inventory

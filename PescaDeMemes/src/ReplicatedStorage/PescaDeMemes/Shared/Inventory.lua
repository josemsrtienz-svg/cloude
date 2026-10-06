--[[
	PescaDeMemes • Inventory (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > Inventory

	Consultas sobre las capturas de un jugador (servidor y cliente).
	Una captura está en la MOCHILA si no está puesta en ningún pedestal de la parcela.
]]

local Inventory = {}

function Inventory.SlotOf(data: any, catchId: string): number?
	return table.find(data.Plot, catchId)
end

function Inventory.InPlot(data: any, catchId: string): boolean
	return table.find(data.Plot, catchId) ~= nil
end

-- Capturas de la mochila, de más a menos valiosas.
function Inventory.Backpack(data: any): { any }
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

function Inventory.BackpackCount(data: any): number
	local n = 0
	for id in pairs(data.Catches) do
		if not Inventory.InPlot(data, id) then
			n += 1
		end
	end
	return n
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
	return string.format("%d/min", math.floor(perMinute + 0.5))
end

return Inventory

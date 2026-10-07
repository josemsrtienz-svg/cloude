--[[
	PescaDeMemes • Util (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > Util
	Utilidades compartidas por cliente y servidor.
]]

local Util = {}

-- Número entero con comas de miles: 1250000 → "1,250,000".
function Util.formatNumber(n: number?): string
	local value = math.floor(tonumber(n) or 0)
	local s = tostring(math.abs(value))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (value < 0 and "-" or "") .. formatted
end

-- Dinero para mostrar: con comas hasta 999,999,999 (se lee de un vistazo) y abreviado a partir de mil millones
-- (1.2B, 3.5T) para que quepa en botones y cartas.
function Util.formatShort(n: number?): string
	local value = tonumber(n) or 0
	local abs = math.abs(value)
	if abs < 1e9 then
		return Util.formatNumber(value)
	end
	local suffixes = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" } }
	for _, entry in ipairs(suffixes) do
		if abs >= entry[1] then
			local short = value / entry[1]
			local text = if math.abs(short) >= 100 then string.format("%d", math.floor(short)) else string.format("%.1f", short)
			text = text:gsub("%.0$", "")
			return text .. entry[2]
		end
	end
	return tostring(math.floor(value))
end

function Util.formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function Util.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = Util.deepCopy(v)
	end
	return copy
end

-- Rellena las claves que faltan (solo primer nivel) con las de la plantilla.
function Util.reconcile(data: any, template: any): any
	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = Util.deepCopy(value)
		end
	end
	return data
end

-- Señal mínima (sin BindableEvent) para comunicar módulos.
function Util.Signal()
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		table.insert(handlers, fn)
		return {
			Disconnect = function()
				local i = table.find(handlers, fn)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
	end
	function signal:Fire(...)
		for _, fn in ipairs(table.clone(handlers)) do
			task.spawn(fn, ...)
		end
	end
	return signal
end

return Util

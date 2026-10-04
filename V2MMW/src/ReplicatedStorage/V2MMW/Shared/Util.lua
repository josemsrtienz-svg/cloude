--[[
	V2MMW • Util (ModuleScript)
	ReplicatedStorage > V2MMW > Shared > Util
	Utilidades compartidas por cliente y servidor.
]]

local Util = {}

function Util.formatNumber(n: number?): string
	local value = math.floor(tonumber(n) or 0)
	local s = tostring(math.abs(value))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (value < 0 and "-" or "") .. formatted
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

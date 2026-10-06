--[[
	PescaDeMemes • State (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > State

	Copia local (solo lectura) de los datos del jugador que manda el servidor.
	State.Changed se dispara cada vez que llegan datos nuevos.
	State.Busy = true mientras se está pescando (para que los paneles no estorben).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Remotes = require(Root.Shared.Remotes)
local Util = require(Root.Shared.Util)
local Inventory = require(Root.Shared.Inventory)

local State = {}
State.Data = nil :: any
State.Changed = Util.Signal()
State.Busy = false

function State.Init()
	Remotes.Get("DataChanged").OnClientEvent:Connect(function(data)
		State.Data = data
		State.Changed:Fire(data)
	end)
	task.spawn(function()
		local data = Remotes.Get("GetData"):InvokeServer()
		if data and not State.Data then
			State.Data = data
			State.Changed:Fire(data)
		end
	end)
end

-- Capturas de la mochila (no puestas en la parcela), de más a menos valiosas.
function State.Backpack(): { any }
	return if State.Data then Inventory.Backpack(State.Data) else {}
end

-- Llama a una RemoteFunction y devuelve su resultado; si falla, devuelve { ok = false }.
function State.Call(name: string, ...: any): any
	local args = table.pack(...)
	local ok, result = pcall(function()
		return Remotes.Get(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { ok = false, err = "Error de conexión" }
end

return State

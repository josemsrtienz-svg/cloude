--[[
	MemeGame • State (ModuleScript, cliente)
	Copia local (solo lectura) de los datos que manda el servidor + señales para la UI.
	El cliente NUNCA modifica MemeCoin, inventario ni equipamiento: solo pide acciones al servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local Remotes = require(Shared.Shared.Remotes)
local Util = require(Shared.Shared.Util)

local State = {}
State.Data = nil :: any
State.DataChanged = Util.Signal() -- (data)
State.GameStateChanged = Util.Signal() -- ("Lobby" | "Station" | "Match")
State.Notify = Util.Signal() -- (text, kind)

local player = Players.LocalPlayer

function State.GameState(): string
	return player:GetAttribute("GameState") or "Lobby"
end

-- Invoca una RemoteFunction y muestra el mensaje que devuelva el servidor.
function State.Request(remoteName: string, ...): (boolean, string?, any?)
	local ok, success, message, extra = pcall(function(...)
		return Remotes.Get(remoteName):InvokeServer(...)
	end, ...)
	if not ok then
		State.Notify:Fire("Error de conexión 😵", "Error")
		return false
	end
	if message and message ~= "" then
		State.Notify:Fire(message, success and "Success" or "Error")
	end
	return success == true, message, extra
end

function State.Init()
	Remotes.Get("DataChanged").OnClientEvent:Connect(function(data)
		State.Data = data
		State.DataChanged:Fire(data)
	end)
	Remotes.Get("Notify").OnClientEvent:Connect(function(text, kind)
		State.Notify:Fire(text, kind)
	end)
	player:GetAttributeChangedSignal("GameState"):Connect(function()
		State.GameStateChanged:Fire(State.GameState())
	end)
	task.spawn(function()
		local data
		for _ = 1, 5 do
			local ok, result = pcall(function()
				return Remotes.Get("GetData"):InvokeServer()
			end)
			if ok and result then
				data = result
				break
			end
			task.wait(2)
		end
		if data and not State.Data then
			State.Data = data
			State.DataChanged:Fire(data)
		end
	end)
end

return State

--[[
	PescaDeMemes • Remotes (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > Remotes

	Lista única de RemoteEvents/RemoteFunctions. El servidor los crea (Remotes.Setup) y el cliente
	los espera (Remotes.Get). El cliente SOLO pide acciones; el servidor valida todo.
	Todas las RemoteFunction devuelven una tabla { ok = boolean, err = string?, ... }.
]]

local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Definitions = {
	-- Datos
	GetData = "RemoteFunction",
	DataChanged = "RemoteEvent", -- servidor → cliente (datos completos)
	Notify = "RemoteEvent", -- servidor → cliente (texto, tipo)
	Announce = "RemoteEvent", -- servidor → todos (capturas épicas)
	-- Pesca
	Cast = "RemoteFunction", -- (power, useReinforced) → { BiteDelay }
	Hook = "RemoteFunction", -- () → datos de la pelea
	Engage = "RemoteFunction", -- PELEAR tras ver el aguante (solo con sobrecarga)
	Tug = "RemoteFunction", -- (inGreen) → { Survived }
	FinishFight = "RemoteFunction", -- (success) → { Catch }
	Release = "RemoteFunction", -- soltar / cancelar
	-- Acuario, parcela y tienda
	SellCatch = "RemoteFunction",
	SellAll = "RemoteFunction",
	ResolvePending = "RemoteFunction", -- ("sell" | "release") captura que no cabía en el acuario
	GoHome = "RemoteFunction", -- teletransporte a tu parcela
	RepairRod = "RemoteFunction", -- (rodId) reparar una caña rota
	BuyAquarium = "RemoteFunction", -- (tier) mochila-acuario más grande
	BuyRod = "RemoteFunction",
	EquipRod = "RemoteFunction",
	BuyItem = "RemoteFunction",
}

local function root(): Instance
	return script.Parent.Parent
end

function Remotes.Setup(): Folder
	assert(RunService:IsServer(), "Remotes.Setup solo en el servidor")
	local folder = root():FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = root()
	end
	for name, className in pairs(Remotes.Definitions) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new(className)
			r.Name = name
			r.Parent = folder
		end
	end
	return folder :: Folder
end

local cache = {}
function Remotes.Get(name: string): any
	if cache[name] then
		return cache[name]
	end
	assert(Remotes.Definitions[name], "Remote desconocido: " .. tostring(name))
	local folder = root():WaitForChild("Remotes")
	local r = folder:WaitForChild(name)
	cache[name] = r
	return r
end

return Remotes

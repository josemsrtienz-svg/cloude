--[[
	V2MMW • Remotes (ModuleScript)
	ReplicatedStorage > V2MMW > Shared > Remotes

	Lista única de RemoteEvents/RemoteFunctions. El servidor los crea (Remotes.Setup)
	dentro de ReplicatedStorage > V2MMW > Remotes y el cliente los espera (Remotes.Get).
	El cliente SOLO pide acciones; el servidor valida todo.
]]

local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Definitions = {
	-- Datos
	GetData = "RemoteFunction",
	DataChanged = "RemoteEvent", -- servidor → cliente (datos completos)
	Notify = "RemoteEvent", -- servidor → cliente (texto, tipo)
	UpdateSettings = "RemoteEvent",
	-- Inventario / equipamiento
	EquipMeme = "RemoteFunction",
	UnequipSlot = "RemoteFunction",
	-- Tienda
	BuyMeme = "RemoteFunction",
	-- Cabinas
	EnterStation = "RemoteFunction",
	LeaveStation = "RemoteFunction",
	ConfigureStation = "RemoteFunction",
	StationReady = "RemoteFunction",
	StationState = "RemoteEvent", -- servidor → cliente
	-- Partidas
	MatchState = "RemoteEvent", -- servidor → cliente
	LeaveMatch = "RemoteFunction",
	UseAbility = "RemoteFunction",
	-- Trading
	TradeRequest = "RemoteFunction",
	TradeRespond = "RemoteFunction",
	TradeSetOffer = "RemoteFunction",
	TradeAccept = "RemoteFunction",
	TradeCancel = "RemoteFunction",
	TradeInvite = "RemoteEvent", -- servidor → cliente
	TradeState = "RemoteEvent", -- servidor → cliente
}

local function root(): Folder
	return script.Parent.Parent :: Folder
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
	return folder
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

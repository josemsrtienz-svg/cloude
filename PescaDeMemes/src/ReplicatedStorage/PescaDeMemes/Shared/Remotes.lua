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
	LevelUp = "RemoteEvent", -- servidor → cliente { Level, Coins, Boosts, Unlocked } (cofre de nivel)
	-- Pesca
	Cast = "RemoteFunction", -- (power, useReinforced) → inmersión: memes, profundidad, anzuelos
	Grab = "RemoteFunction", -- (index) el anzuelo toca un meme → enganchado o PELEA
	Engage = "RemoteFunction", -- PELEAR tras ver el aguante
	Tug = "RemoteFunction", -- (inGreen) → { Survived }
	FinishFight = "RemoteFunction", -- (success) → sigue la inmersión, o termina si perdiste
	Release = "RemoteFunction", -- SOLTAR el meme que pelea y seguir bajando
	Surface = "RemoteFunction", -- subir: termina la inmersión y te llevas lo enganchado
	-- Acuario, parcela y tienda
	SellCatch = "RemoteFunction",
	SellAll = "RemoteFunction",
	GoHome = "RemoteFunction", -- teletransporte a tu parcela
	RepairRod = "RemoteFunction", -- (rodId) reparar una caña rota
	BuyAquarium = "RemoteFunction", -- (tier) mochila-acuario más grande
	BuyRod = "RemoteFunction",
	EquipRod = "RemoteFunction",
	BuyItem = "RemoteFunction",
	BuyBoost = "RemoteFunction", -- (boostId) solo junto a la tienda física
	SetFilters = "RemoteFunction", -- (catchSkip, autoSell) filtros de rarezas
	EquipItem = "RemoteFunction", -- (itemId, on) equipar/quitar un objeto (huecos limitados)
	UseNet = "RemoteFunction", -- usar la Red Dorada en la pelea actual: enganchado sin pelear
	ClaimFreeBoost = "RemoteFunction", -- recoger el boost gratis (solo junto a la tienda física)
	ClaimMission = "RemoteFunction", -- (index) recoger el premio de una misión diaria completada
	ClaimDailyGift = "RemoteFunction", -- recoger el regalo diario (racha)
	BuyMerchant = "RemoteFunction", -- (index) comprar una oferta del mercader ambulante (junto a su barca)
	SetAudio = "RemoteFunction", -- ("Music" | "SFX" | "Shake", on) ajustes de sonido y temblor (se guardan)
	FinishTutorial = "RemoteFunction", -- (skipped) terminar o saltar el tutorial; premio solo si lo hizo
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

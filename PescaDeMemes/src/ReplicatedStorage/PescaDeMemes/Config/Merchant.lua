--[[
	PescaDeMemes • Merchant (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Merchant

	MERCADER AMBULANTE (idea decidida por el equipo; salió del debate de "comprar memes con monedas").
	  · Llega en su BARCA-TIENDA y amarra junto al PUENTE durante Open segundos de cada Period (cada hora, 10 min).
	  · Cada visita trae 3 ofertas, iguales en todos los servidores (semilla = número de visita):
	      1. Un meme RARO de verdad (Épico, Mítico o, a veces, Legendario) — NUNCA secretos: pescarlos
	         tiene que seguir siendo especial. Caro: 3 veces su valor. Máximo 1 por jugador y visita.
	      2. Un objeto al 50 % (consumibles hasta 3; equipo solo si no lo tienes).
	      3. Un boost al 40 % de descuento (hasta 2).
	  · Es un SUMIDERO de MemeCoins para el late game, no un atajo: lo que vende también se puede pescar.
	Cliente y servidor calculan las mismas ofertas con Merchant.Offers(visit); el servidor valida la compra.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local Boosts = require(Root.Config.Boosts)
local FishMath = require(Root.Shared.FishMath)

local Merchant = {}

Merchant.Period = 60 * 60 -- llega cada hora…
Merchant.Open = 10 * 60 -- …y se queda 10 minutos
Merchant.Range = 16 -- studs desde el mostrador de la barca para comprar
Merchant.MemePriceMultiplier = 3
Merchant.MemeOdds = { { "EPIC", 60 }, { "MYTHIC", 30 }, { "LEGENDARY", 10 } }
Merchant.ItemDiscount = 0.5
Merchant.BoostDiscount = 0.6 -- se paga el 60 %

function Merchant.Visit(now: number): number
	return math.floor(now / Merchant.Period)
end

-- ¿Está amarrado ahora? Devuelve (abierto, visita, segundos en que se va / llega).
function Merchant.State(now: number): (boolean, number, number)
	local visit = Merchant.Visit(now)
	local start = visit * Merchant.Period
	if now - start < Merchant.Open then
		return true, visit, start + Merchant.Open
	end
	return false, visit, start + Merchant.Period
end

local function pickWeighted(rng: Random, list: { { any } }): any
	local total = 0
	for _, e in ipairs(list) do
		total += e[2]
	end
	local roll = rng:NextNumber() * total
	for _, e in ipairs(list) do
		roll -= e[2]
		if roll <= 0 then
			return e[1]
		end
	end
	return list[#list][1]
end

-- Las 3 ofertas de una visita. Kind = "Meme" | "Item" | "Boost". Limit = máximo por jugador.
function Merchant.Offers(visit: number): { any }
	local rng = Random.new(visit * 7907 + 13)
	local offers = {}

	-- 1) meme raro (de los que viven en la zona; ejemplar grande: mitad alta de su rango de peso)
	local rarity = pickWeighted(rng, Merchant.MemeOdds)
	local pool = Memes.InZone(1, rarity)
	if #pool > 0 then
		local meme = pool[rng:NextInteger(1, #pool)]
		local weight = math.floor((meme.WeightMin + (meme.WeightMax - meme.WeightMin) * rng:NextNumber(0.5, 1)) * 10 + 0.5) / 10
		table.insert(offers, { Kind = "Meme", MemeId = meme.Id, Weight = weight, Limit = 1,
			Price = FishMath.Value(meme, weight, false) * Merchant.MemePriceMultiplier })
	end

	-- 2) objeto rebajado
	local itemId = Rods.ItemOrder[rng:NextInteger(1, #Rods.ItemOrder)]
	local item = Rods.Items[itemId]
	table.insert(offers, { Kind = "Item", ItemId = itemId, Limit = if item.Kind == "Gear" then 1 else 3,
		Price = math.floor(item.Price * Merchant.ItemDiscount) })

	-- 3) boost rebajado
	local boostId = Boosts.Order[rng:NextInteger(1, #Boosts.Order)]
	table.insert(offers, { Kind = "Boost", BoostId = boostId, Limit = 2,
		Price = math.floor(Boosts.List[boostId].Price * Merchant.BoostDiscount) })
	return offers
end

return Merchant

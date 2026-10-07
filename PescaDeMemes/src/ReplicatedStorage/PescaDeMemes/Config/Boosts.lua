--[[
	PescaDeMemes • Boosts (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Boosts

	Mejoras temporales que se compran en la GRAN TIENDA (hay que ir hasta ella) o salen gratis:
	  · TABLÓN DE LA GRAN TIENDA: cada Free.RotationSeconds (15 min) cambia el BOOST GRATIS del tablón
	    (el mismo para todo el servidor). Cada jugador puede recogerlo UNA vez por ronda y le dura
	    Duration segundos (5 min). El tablón enseña cuál es y cuánto falta para el siguiente.
	  · Comprar o recibir un boost que ya tienes activo SUMA tiempo.
	Valores iniciales de balance.
]]

local Boosts = {}

local RGB = Color3.fromRGB

Boosts.List = {
	Money = { Id = "Money", Name = "Dinero ×2", Emoji = "💰", Multiplier = 2, Duration = 300, Price = 3000, Color = RGB(90, 220, 90),
		Description = "Lo que vendes y lo que gana tu parcela vale el doble durante 5 min." },
	Luck = { Id = "Luck", Name = "Suerte ×2", Emoji = "🍀", Multiplier = 2, Duration = 300, Price = 4500, Color = RGB(80, 200, 255),
		Description = "El doble de memes raros (o más) en cada inmersión durante 5 min." },
	Speed = { Id = "Speed", Name = "Anzuelo ×1.5", Emoji = "⚡", Multiplier = 1.5, Duration = 300, Price = 2500, Color = RGB(255, 205, 40),
		Description = "El anzuelo baja un 50 % más rápido: llegas antes al fondo." },
	Hook = { Id = "Hook", Name = "+1 Anzuelo", Emoji = "🪝", Multiplier = 1, Duration = 300, Price = 6000, Color = RGB(255, 90, 150),
		Description = "Un anzuelo extra en cada lanzamiento durante 5 min." },
}
Boosts.Order = { "Money", "Luck", "Speed", "Hook" }

Boosts.Free = {
	RotationSeconds = 15 * 60,
	Pool = { "Luck", "Money", "Speed", "Hook" }, -- se van turnando en este orden
}

Boosts.ShopRange = 40 -- studs: distancia máxima al mostrador para comprar boosts o recoger el gratis

function Boosts.Get(id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	return Boosts.List[id]
end

-- Ronda actual del tablón (cambia cada RotationSeconds, igual en todos los servidores) y su boost gratis.
function Boosts.FreeRound(now: number): (number, any, number)
	local period = Boosts.Free.RotationSeconds
	local round = math.floor(now / period)
	local id = Boosts.Free.Pool[round % #Boosts.Free.Pool + 1]
	return round, Boosts.List[id], (round + 1) * period
end

-- Boost y fin de una ronda concreta.
function Boosts.RoundInfo(round: number): (any, number)
	local id = Boosts.Free.Pool[round % #Boosts.Free.Pool + 1]
	return Boosts.List[id], (round + 1) * Boosts.Free.RotationSeconds
end

-- Para el CLIENTE: ronda que publica el servidor (Workspace "FreeRound") y si este jugador aún puede recogerla.
-- Devuelve: disponible (nil si aún no hay datos), boost, segundos de servidor en que acaba la ronda.
function Boosts.FreeAvailable(data: any): (boolean?, any, number)
	local published = workspace:GetAttribute("FreeRound")
	local round = if type(published) == "number" then published else (Boosts.FreeRound(workspace:GetServerTimeNow()))
	local boost, endsAt = Boosts.RoundInfo(round)
	if data == nil then
		return nil, boost, endsAt
	end
	return data.FreeRound ~= round, boost, endsAt
end

return Boosts

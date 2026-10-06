--[[
	PescaDeMemes • Boosts (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Boosts

	Mejoras temporales que se compran en la TIENDA FÍSICA (hay que ir hasta ella) o salen gratis:
	  · Cada jugador tiene su propio reloj: entre FreeMinDelay y FreeMaxDelay segundos después de entrar
	    (o de recoger el anterior) le aparece un BOOST GRATIS en la tienda. No le sale a todos a la vez.
	    Si no lo recoge en ClaimWindow segundos, se pierde y empieza otro reloj.
	  · Comprar o recibir un boost que ya tienes activo SUMA tiempo.
	Valores iniciales de balance.
]]

local Boosts = {}

local RGB = Color3.fromRGB

Boosts.List = {
	Money = { Id = "Money", Name = "Dinero ×2", Emoji = "💰", Multiplier = 2, Duration = 300, Price = 600, Color = RGB(90, 220, 90),
		Description = "Lo que vendes y lo que gana tu parcela vale el doble durante 5 min." },
	Luck = { Id = "Luck", Name = "Suerte ×1.5", Emoji = "🍀", Multiplier = 1.5, Duration = 300, Price = 900, Color = RGB(80, 200, 255),
		Description = "Más memes raros en cada inmersión durante 5 min." },
}
Boosts.Order = { "Money", "Luck" }

Boosts.Free = {
	MinDelay = 9 * 60,
	MaxDelay = 20 * 60,
	ClaimWindow = 5 * 60,
}

Boosts.ShopRange = 22 -- studs: distancia máxima al mostrador para comprar boosts o recoger el gratis

function Boosts.Get(id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	return Boosts.List[id]
end

return Boosts

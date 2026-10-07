--[[
	PescaDeMemes • Monetization (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Monetization

	Game Passes (se compran con Robux en la pestaña 💎 de la TIENDA FÍSICA).
	CÓMO ACTIVARLOS: crea el pase en el Creator Dashboard (tu experiencia → Monetization → Passes),
	copia su ID y ponlo en Id. Con Id = 0 la tienda lo enseña como "Próximamente".
	Robux = precio que se ENSEÑA (el precio real se pone en el Dashboard: que coincidan).

	Regla de monetización ética: dan comodidad o multiplicadores moderados; nunca un meme ni una caña
	que no se pueda conseguir jugando.
]]

local Monetization = {}

local RGB = Color3.fromRGB

Monetization.GamePasses = {
	{ Key = "VIP", Id = 0, Name = "VIP", Emoji = "👑", Robux = 199, Color = RGB(255, 200, 50),
		MoneyMultiplier = 1.5, Description = "Dinero ×1.5 para siempre (ventas y parcela)." },
	{ Key = "Lucky", Id = 0, Name = "Suerte Eterna", Emoji = "🍀", Robux = 299, Color = RGB(80, 200, 255),
		LuckMultiplier = 1.25, Description = "Suerte ×1.25 para siempre en todas las inmersiones." },
	{ Key = "ExtraHook", Id = 0, Name = "+1 Anzuelo", Emoji = "🪝", Robux = 249, Color = RGB(255, 90, 150),
		ExtraHooks = 1, Description = "Un anzuelo más en TODAS tus cañas." },
	{ Key = "ItemSlot", Id = 0, Name = "+1 Hueco de objeto", Emoji = "🎒", Robux = 149, Color = RGB(255, 140, 40),
		ItemSlots = 1, Description = "Lleva un objeto más equipado (p. ej. Linterna + Imán)." },
}

function Monetization.Get(key: any): any?
	for _, pass in ipairs(Monetization.GamePasses) do
		if pass.Key == key then
			return pass
		end
	end
	return nil
end

return Monetization

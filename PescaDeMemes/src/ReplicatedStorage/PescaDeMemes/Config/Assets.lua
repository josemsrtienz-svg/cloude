--[[
	PescaDeMemes • Assets (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Assets

	Imágenes y sonidos en un solo sitio. Pega aquí "rbxassetid://ID".
	Si una imagen está vacía (""), la UI muestra el emoji del meme sobre el color de su rareza.
]]

local Assets = {}

Assets.MemeImages = {
	NoobFeliz = "",
	PerroBonk = "",
	Stonks = "",
	Sospechoso = "",
	PatoInfinito = "",
	GatoPianista = "",
	Moai = "",
	GigaChad = "",
}

-- "" = sin sonido.
Assets.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Bite = "rbxasset://sounds/electronicpingshort.wav",
	Snap = "rbxasset://sounds/uuhhh.mp3",
	Catch = "",
	Tug = "",
	Coins = "",
}

function Assets.MemeImage(id: string): string?
	local img = Assets.MemeImages[id]
	if img and img ~= "" then
		return img
	end
	return nil
end

return Assets

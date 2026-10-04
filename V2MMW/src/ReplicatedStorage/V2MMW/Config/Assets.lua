--[[
	V2MMW • Assets (ModuleScript)
	ReplicatedStorage > V2MMW > Config > Assets

	TODAS las imágenes y sonidos en un solo sitio.
	Sube tus PNG en create.roblox.com → Development Items → Decals/Images y pega aquí "rbxassetid://ID".
	Si un valor está vacío (""), la UI muestra el emoji del meme sobre el color de su rareza.
	Tus imágenes SIEMPRE tienen prioridad sobre el fallback.
]]

local Assets = {}

-- Imagen de cada meme, por Id (ver MemeCatalog).
Assets.MemeImages = {
	NoobFeliz = "",
	Sospechoso = "",
	PerroBonk = "",
	Stonks = "",
	CaraTroll = "",
	PatoInfinito = "",
	GatoPianista = "",
	GatoArcoiris = "",
	ChicoTienda = "",
	Moai = "",
	OgroPantano = "",
	RanaTriste = "",
	GigaChad = "",
	HeroeCalvo = "",
	InodoroCantante = "",
	DiosMeme = "",
}

-- Iconos de la interfaz ("" = usa emoji).
Assets.Icons = {
	MemeCoin = "",
	Shop = "",
	Inventory = "",
	Trade = "",
	Settings = "",
	Play = "",
	Logo = "",
}

-- Sonidos ("" = sin sonido). Usa "rbxassetid://ID" de la Creator Store.
Assets.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Purchase = "",
	Equip = "",
	Error = "",
	Countdown = "",
	Go = "",
	LobbyMusic = "",
	MatchMusic = "",
}

function Assets.MemeImage(id: string): string?
	local img = Assets.MemeImages[id]
	if img and img ~= "" then
		return img
	end
	return nil
end

return Assets

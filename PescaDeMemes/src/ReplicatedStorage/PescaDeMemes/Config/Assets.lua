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

-- ===== SONIDOS (Fase 3) =====
-- Cada sonido tiene una lista de candidatos: el cliente precarga y usa el PRIMERO que carga bien
-- (los sonidos rbxasset:// vienen dentro de Roblox; según la versión son .wav o .mp3, por eso hay dos).
-- Para usar uno tuyo o de la Creator Store, pon "rbxassetid://ID" el primero de la lista.
--   Volume = volumen (0–1) · Speed = velocidad/tono · Vary = ± variación aleatoria de tono (que no suene repetido)
local function classic(name: string): { string }
	return { "rbxasset://sounds/" .. name .. ".wav", "rbxasset://sounds/" .. name .. ".mp3" }
end

Assets.Sounds = {
	Click = { Ids = classic("electronicpingshort"), Volume = 0.35, Speed = 1.3 },
	Cast = { Ids = classic("swoosh"), Volume = 0.6, Vary = 0.08 },
	Splash = { Ids = { "rbxasset://sounds/impact_water.mp3" }, Volume = 0.8, Vary = 0.1 },
	Bite = { Ids = classic("Kerplunk"), Volume = 0.6, Vary = 0.1 },
	Catch = { Ids = classic("Rubber band sling shot"), Volume = 0.55, Speed = 1.2, Vary = 0.1 },
	Tug = { Ids = classic("Rubber band"), Volume = 0.6, Vary = 0.15 },
	Snap = { Ids = classic("snap"), Volume = 0.9 },
	Fail = { Ids = { "rbxasset://sounds/uuhhh.mp3" }, Volume = 0.5 },
	Coins = { Ids = classic("electronicpingshort"), Volume = 0.45, Speed = 1.8, Vary = 0.06 },
	Error = { Ids = classic("switch"), Volume = 0.5, Speed = 0.8 },
	LevelUp = { Ids = classic("victory"), Volume = 0.6 },
	Reward = { Ids = classic("victory"), Volume = 0.45, Speed = 1.15 },
	Dive = { Ids = { "rbxasset://sounds/action_swim.mp3" }, Volume = 0.5, Speed = 0.8 },
	Merchant = { Ids = classic("bass"), Volume = 0.6 },
	Rare = { Ids = classic("flashbulb"), Volume = 0.5, Speed = 1.2 },
	-- ===== "dopamina": notas que suben, tintineo de monedas y fanfarrias por rareza =====
	Combo = { Ids = classic("electronicpingshort"), Volume = 0.55 }, -- cada meme enganchado sube una nota de la escala
	Tick = { Ids = classic("clickfast"), Volume = 0.3, Speed = 1.4 }, -- el contador de monedas al subir
	Sparkle = { Ids = classic("electronicpingshort"), Volume = 0.4, Speed = 2.2, Vary = 0.05 }, -- ¡NUEVO! / dorado
	Fanfare = { Ids = classic("victory"), Volume = 0.8 },
	Boom = { Ids = classic("bass"), Volume = 0.8, Speed = 0.7 }, -- golpe grave para míticos o más
}

-- ===== MÚSICA Y AMBIENTE =====
-- Pistas en bucle (se puede apagar en ⚙️ Ajustes). Están vacías a propósito: pon IDs de música con licencia de
-- la Creator Store de Roblox (Toolbox → Audio → filtra por "Music", autor Roblox/APM) → "rbxassetid://ID".
-- Si una lista está vacía no suena nada (no da error).
Assets.Music = {
	Surface = {}, -- en el mapa: algo alegre y tranquilo
	Dive = {}, -- bajo el agua: algo misterioso
}
Assets.MusicVolume = 0.35

function Assets.MemeImage(id: string): string?
	local img = Assets.MemeImages[id]
	if img and img ~= "" then
		return img
	end
	return nil
end

return Assets

--[[
	PescaDeMemes • Boss (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Boss

	JEFE DEL RÍO (Fase 4 · Alpha, decidido por el equipo): evento GLOBAL del servidor.
	  · Cada Period (30 min), en el minuto Offset, emerge en el centro del río un meme DIOS gigante
	    (la Ballena Sigma) y se queda Duration (3 min).
	  · TODOS tiran a la vez: con la caña en la mano y en el río (tu muelle o el puente), pulsa 🎣 ¡TIRA!
	    Cada tirón quita vida según tu caña (las mejores tiran más fuerte). La vida crece con los jugadores.
	  · Si lo sacáis: todos los que ayudaron cobran MemeCoins (según su nivel y cuánto ayudaron) y UNO se lleva
	    el meme DIOS a su mochila (sorteo: cuanto más tiraste, más papeletas). Si se acaba el tiempo, se escapa.
	El servidor (BossService) cuenta los tirones y reparte; el cliente (BossController) pinta la barra y el botón.
]]

local GameConfig = require(script.Parent.GameConfig)
local Rods = require(script.Parent.Rods)

local Boss = {}

Boss.MemeId = "BallenaSigma"
Boss.Period = 30 * 60
Boss.Offset = 15 * 60 -- a mitad de cada media hora (el mercader llega en el minuto 0)
Boss.Duration = 3 * 60
-- prueba en Studio (GameConfig.DevMode.BossTest): aparece enseguida y cada 4 min
Boss.Test = { Period = 4 * 60, Offset = 20, Duration = 2 * 60 }

Boss.HPPerPlayer = 350 -- vida = jugadores × esto (mínimo MinHP)
Boss.MinHP = 450
Boss.PullCooldown = 0.18 -- s entre tirones válidos (más rápido no cuenta)
Boss.PullTolerance = 0.75 -- el servidor acepta tirones a PullCooldown × esto (el lag junta paquetes)
Boss.RiverMargin = 8 -- studs de margen alrededor del cauce donde se puede tirar (muelle o puente)
Boss.MinPulls = 5 -- tirones mínimos para cobrar
Boss.RewardCoins = 3000 -- × escala de nivel × tu parte (entre 0,5 y 2)
Boss.ModelScale = 3
Boss.Z = 70 -- dónde emerge (centro del río, x = 0)

-- Fuerza de cada tirón según la caña (posición en Config/Rods.List): Palo 1 … Divina 3,25.
function Boss.PullPower(rodIndex: number): number
	return 1 + 0.15 * (math.max(1, rodIndex) - 1)
end

-- Fuerza de la caña con ese Id (la misma cuenta en servidor y cliente).
function Boss.PowerForRod(rodId: string?): number
	for i, rod in ipairs(Rods.List) do
		if rod.Id == rodId then
			return Boss.PullPower(i)
		end
	end
	return Boss.PullPower(1)
end

-- ¿Se puede tirar desde aquí? (en el río: tu muelle o el puente, con un margen)
function Boss.CanPullAt(pos: Vector3): boolean
	return GameConfig.InRiver(pos, -Boss.RiverMargin)
end

function Boss.LevelScale(level: number): number
	return 1 + 0.25 * (math.max(1, level) - 1)
end

-- (activo, ciclo, segundos de servidor en que acaba si está activo / en que empieza el siguiente)
function Boss.State(now: number, test: boolean?): (boolean, number, number)
	local period = if test then Boss.Test.Period else Boss.Period
	local offset = if test then Boss.Test.Offset else Boss.Offset
	local duration = if test then Boss.Test.Duration else Boss.Duration
	local cycle = math.floor((now - offset) / period)
	local start = cycle * period + offset
	if now >= start and now < start + duration then
		return true, cycle, start + duration
	end
	return false, cycle, start + period
end

return Boss

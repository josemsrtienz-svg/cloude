--[[
	PescaDeMemes • FishBehaviors (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > FishBehaviors

	La "personalidad" de cada meme durante la pelea: cómo se mueve la zona verde y cuánto
	empuja tu indicador hacia la izquierda (Pull, 0..1, luego se multiplica por la rareza).
	Solo afecta al minijuego del cliente; el servidor valida tiempos y tirones.

	FishBehaviors.new(personality, greenWidth, redZoneStart) → behavior
	behavior:Update(dt) → (center: number, pull: number, event: string?)
	  event = "jump" cuando el meme hace un movimiento brusco (para sacudir la UI).
]]

local FishBehaviors = {}

type Behavior = { Update: (self: Behavior, dt: number) -> (number, number, string?) }

local function makeBase(width: number, redStart: number)
	local lo = width / 2 + 0.01
	local hi = redStart - width / 2 - 0.01
	if hi < lo then
		hi = lo
	end
	return {
		lo = lo,
		hi = hi,
		mid = (lo + hi) / 2,
		amp = (hi - lo) / 2,
		t = 0,
		rng = Random.new(),
	}
end

local function approach(current: number, target: number, maxDelta: number): number
	if math.abs(target - current) <= maxDelta then
		return target
	end
	return current + math.sign(target - current) * maxDelta
end

local builders: { [string]: (any) -> Behavior } = {}

-- Noob Feliz: vaivén lento y predecible.
builders.Calm = function(s)
	return {
		Update = function(_, dt)
			s.t += dt
			return s.mid + s.amp * 0.7 * math.sin(s.t * 0.8), 0.4, nil
		end,
	}
end

-- Perro Bonk: cambia de sitio de golpe cada poco.
builders.Jerky = function(s)
	local center, target, nextJump = s.mid, s.mid, 1
	return {
		Update = function(_, dt)
			s.t += dt
			local event = nil
			if s.t >= nextJump then
				target = s.rng:NextNumber(s.lo, s.hi)
				nextJump = s.t + s.rng:NextNumber(0.6, 1.4)
				event = "jump"
			end
			center = approach(center, target, 1.6 * dt)
			return center, if center ~= target then 1 else 0.4, event
		end,
	}
end

-- Señor Stonks: sube poco a poco y de repente se desploma.
builders.Market = function(s)
	local center, crashing = s.lo + s.amp * 0.3, false
	return {
		Update = function(_, dt)
			s.t += dt
			local event = nil
			if crashing then
				center -= 0.9 * dt
				if center <= s.lo + 0.02 then
					center = s.lo + 0.02
					crashing = false
				end
			else
				center += (0.16 + 0.08 * math.sin(s.t * 5)) * dt
				if center >= s.hi or s.rng:NextNumber() < 0.3 * dt then
					crashing = true
					event = "jump"
				end
			end
			center = math.clamp(center, s.lo, s.hi)
			return center, if crashing then 1 else 0.3, event
		end,
	}
end

-- El Sospechoso: se queda quieto y de pronto salta al otro lado.
builders.Freeze = function(s)
	local center, target, waitUntil = s.mid, s.mid, 1.5
	return {
		Update = function(_, dt)
			s.t += dt
			local event = nil
			if center == target and s.t >= waitUntil then
				target = if center > s.mid then s.rng:NextNumber(s.lo, s.mid) else s.rng:NextNumber(s.mid, s.hi)
				event = "jump"
			end
			local moving = center ~= target
			center = approach(center, target, 2.5 * dt)
			if moving and center == target then
				waitUntil = s.t + s.rng:NextNumber(1.2, 2.8)
			end
			return center, if moving then 1 else 0.2, event
		end,
	}
end

-- Pato Infinito: vueltas rápidas que nunca se repiten igual.
builders.Spin = function(s)
	return {
		Update = function(_, dt)
			s.t += dt
			return s.mid + s.amp * math.sin(s.t * 2.4) * math.cos(s.t * 0.7), 0.6, nil
		end,
	}
end

-- Gato Pianista: salta entre 4 "teclas" siguiendo siempre la misma melodía.
builders.Rhythm = function(s)
	local melody = { 1, 2, 3, 2, 4, 3, 2, 1 }
	local beat, step, center = 0.45, 0, s.lo
	return {
		Update = function(_, dt)
			s.t += dt
			local event = nil
			local newStep = math.floor(s.t / beat)
			if newStep ~= step then
				step = newStep
				event = "beat"
			end
			local key = melody[(step % #melody) + 1]
			local target = s.lo + (key - 1) / 3 * (s.hi - s.lo)
			center = approach(center, target, 3 * dt)
			return center, 0.5, event
		end,
	}
end

-- Moai: casi no se mueve, pero empuja con todo su peso.
builders.Heavy = function(s)
	return {
		Update = function(_, dt)
			s.t += dt
			return s.mid + s.amp * 0.4 * math.sin(s.t * 0.35), 1, nil
		end,
	}
end

-- GigaChad: zona amplia, pero con arreones de fuerza bruta.
builders.Brute = function(s)
	local surgeUntil, nextSurge = 0, 2.5
	return {
		Update = function(_, dt)
			s.t += dt
			local event = nil
			if s.t >= nextSurge then
				surgeUntil = s.t + 0.6
				nextSurge = s.t + s.rng:NextNumber(2, 4)
				event = "jump"
			end
			return s.mid + s.amp * 0.6 * math.sin(s.t * 0.9), if s.t < surgeUntil then 1.6 else 0.7, event
		end,
	}
end

function FishBehaviors.new(personality: string, greenWidth: number, redStart: number): Behavior
	local builder = builders[personality] or builders.Calm
	return builder(makeBase(greenWidth, redStart))
end

function FishBehaviors.Has(personality: string): boolean
	return builders[personality] ~= nil
end

return FishBehaviors

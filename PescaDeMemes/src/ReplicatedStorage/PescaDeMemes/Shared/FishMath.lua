--[[
	PescaDeMemes • FishMath (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > FishMath

	Fórmulas compartidas por servidor y cliente (el cliente solo las usa para MOSTRAR;
	el servidor es quien decide).

	Peso vs. capacidad:
	  r = peso / capacidad
	  r <= 1       → aguante 100 % (solo depende de la habilidad)
	  1 < r <= 5   → aguante = max(0,1 %, (1/r)^4)
	  r > 5        → ni se puede enganchar (el anzuelo lo atraviesa)
	En la inmersión: r <= 1 se engancha al tocarlo; r > 1 hay que PELEAR (3 tirones; cada uno se supera
	con aguante^(1/3), con bonus si estás en verde).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)

local F = GameConfig.Fishing

local FishMath = {}

function FishMath.Survival(ratio: number): number
	if ratio <= 1 then
		return 1
	end
	if ratio > F.MaxOverload then
		return 0
	end
	return math.max(F.MinSurvival, (1 / ratio) ^ 4)
end

-- Cómo reacciona un meme al anzuelo según su peso y la capacidad de tu caña:
-- "ok" (se engancha solo) · "fight" (pelea) · "heavy" (demasiado pesado, no se puede enganchar).
function FishMath.GrabKind(weight: number, capacity: number): string
	local ratio = weight / math.max(0.001, capacity)
	if ratio <= 1 then
		return "ok"
	elseif ratio <= F.MaxOverload then
		return "fight"
	end
	return "heavy"
end

-- Posición horizontal (m) de un meme que nada de lado a lado durante la inmersión (solo visual).
function FishMath.SwimX(spec: any, t: number): number
	return spec.X + spec.Amp * math.sin(spec.Freq * t + spec.Phase)
end

function FishMath.TugChance(survival: number, inGreen: boolean): number
	local p = survival ^ (1 / F.TugCount)
	if inGreen then
		p = math.max(p, math.min(F.TugGreenMax, p * F.TugGreenBonus))
	end
	return p
end

-- Dónde cae el peso dentro del rango del meme (0 = mínimo, 1 = máximo; MÁS de 1 = ejemplar gigante).
function FishMath.Fraction(meme: any, weight: number): number
	local span = meme.WeightMax - meme.WeightMin
	if span <= 0 then
		return 0.5
	end
	return math.clamp((weight - meme.WeightMin) / span, 0, 1)
end

FishMath.Sizes = {
	{ Max = 0.3, Name = "S" },
	{ Max = 0.55, Name = "M" },
	{ Max = 0.75, Name = "L" },
	{ Max = 1.01, Name = "XL" },
}

-- Tamaño de un ejemplar: S…XL dentro de su rango; por encima de su peso máximo es GIGANTE
-- (hasta 2,5× WeightMax) o COLOSAL (más de 2,5×), igual para todos los memes.
function FishMath.SizeOf(meme: any, weight: number): string
	if weight > meme.WeightMax * 2.5 then
		return "COLOSAL"
	elseif weight > meme.WeightMax * 1.01 then
		return "GIGANTE"
	end
	return FishMath.SizeName(FishMath.Fraction(meme, weight))
end

-- Peso medio de un meme (para comparar ejemplares).
function FishMath.AverageWeight(meme: any): number
	return (meme.WeightMin + meme.WeightMax) / 2
end

-- Escala visual de un ejemplar: el TAMAÑO IMPORTA. Raíz cúbica del peso relativo (el doble de kg no es el
-- doble de alto), con tope para que un colosal no tape la parcela ni se bugee.
function FishMath.DisplayScale(meme: any, weight: number): number
	return math.clamp((weight / FishMath.AverageWeight(meme)) ^ (1 / 3), 0.75, 2.1)
end

function FishMath.SizeName(fraction: number): string
	for _, size in ipairs(FishMath.Sizes) do
		if fraction < size.Max then
			return size.Name
		end
	end
	return "XL"
end

-- Valor = valor base de la rareza × (peso / peso medio)^0.85: los ejemplares grandes valen MUCHO más
-- (un Señor Stonks colosal de 30 kg vale ~5 veces uno normal).
function FishMath.Value(meme: any, weight: number, golden: boolean): number
	local rarity = Memes.Rarities[meme.Rarity]
	local value = rarity.BaseValue * (weight / FishMath.AverageWeight(meme)) ^ 0.85
	if golden then
		value *= F.GoldenMultiplier
	end
	return math.max(1, math.floor(value))
end

-- Parámetros del minijuego. Los usa el servidor para validar y el cliente para jugar.
function FishMath.FightParams(meme: any, rod: any, ratio: number): { [string]: number }
	local rarity = Memes.Rarities[meme.Rarity]
	local overload = math.max(0, ratio - 1)
	local width = F.BaseGreenWidth * rod.GreenWidth / (1 + 0.6 * overload)
	if meme.Personality == "Brute" then
		width *= 1.5
	end
	local fillRate = F.BaseFillRate * rod.FillSpeed / rarity.Difficulty
	local pull = rarity.Pull * (1 + 0.5 * math.min(overload, 3))
	return {
		GreenWidth = math.clamp(width, 0.08, 0.6),
		FillRate = fillRate,
		Pull = pull,
		RedTolerance = rod.RedTolerance,
	}
end

-- Tiempo mínimo humanamente posible para llenar la barra (el servidor rechaza peleas más cortas).
function FishMath.MinFightTime(fillRate: number): number
	return (1 - F.StartProgress) / fillRate * 0.8
end

function FishMath.FormatPercent(p: number): string
	local pct = p * 100
	if pct >= 99.5 then
		return "100 %"
	elseif pct >= 10 then
		return string.format("%d %%", math.floor(pct + 0.5))
	elseif pct >= 1 then
		return string.format("%.1f %%", pct)
	end
	return string.format("%.2f %%", pct)
end

function FishMath.FormatWeight(kg: number): string
	if kg >= 100 then
		return string.format("%d kg", math.floor(kg + 0.5))
	end
	return string.format("%.1f kg", kg)
end

return FishMath

--[[
	PescaDeMemes • Rods (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Rods

	Cañas y objetos de la tienda. Cada caña sube la CAPACIDAD de peso y cambia algo del minijuego:
	  Capacity      kg que aguanta sin riesgo.
	  GreenWidth    multiplicador del ancho de la zona verde.
	  FillSpeed     multiplicador de la velocidad del progreso.
	  Luck          multiplicador de suerte (rarezas altas).
	  RedTolerance  segundos que aguanta el sedal en la zona roja antes de romperse.
]]

local Rods = {}

local RGB = Color3.fromRGB

Rods.List = {
	{ Id = "Palo", Name = "Caña de Palo", Emoji = "🪵", Price = 0, Capacity = 12,
		GreenWidth = 1.0, FillSpeed = 1.0, Luck = 1.0, RedTolerance = 0.5,
		Color = RGB(150, 105, 60), Description = "Un palo con hilo. Para empezar sobra." },
	{ Id = "Fibra", Name = "Caña de Fibra", Emoji = "🎣", Price = 600, Capacity = 50,
		GreenWidth = 1.2, FillSpeed = 1.0, Luck = 1.05, RedTolerance = 0.55,
		Color = RGB(70, 170, 255), Description = "Zona verde más ancha. Pescar es más fácil." },
	{ Id = "Turbo", Name = "Caña Turbo", Emoji = "⚡", Price = 4000, Capacity = 150,
		GreenWidth = 1.2, FillSpeed = 1.3, Luck = 1.1, RedTolerance = 0.6,
		Color = RGB(255, 205, 40), Description = "El progreso sube mucho más rápido." },
	{ Id = "Abisal", Name = "Caña Abisal", Emoji = "🌊", Price = 25000, Capacity = 400,
		GreenWidth = 1.3, FillSpeed = 1.3, Luck = 1.2, RedTolerance = 0.8,
		Color = RGB(120, 60, 200), Description = "Hecha para bestias. Aguanta más en el rojo." },
}

Rods.Items = {
	SedalReforzado = { Id = "SedalReforzado", Name = "Sedal Reforzado", Emoji = "🧵", Price = 120,
		CapacityBonus = 0.25, Description = "+25 % de capacidad durante UN lanzamiento." },
}

local byId: { [string]: any } = {}
for i, rod in ipairs(Rods.List) do
	rod.Order = i
	byId[rod.Id] = rod
end

function Rods.Get(id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function Rods.GetItem(id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	return Rods.Items[id]
end

return Rods

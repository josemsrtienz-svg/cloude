--[[
	V2MMW • Geometry (ModuleScript)
	ReplicatedStorage > V2MMW > Shared > Geometry

	Matemática de modelos en Luau puro (sin Model:PivotTo/ScaleTo), para que el mismo código
	sirva en el juego y en la herramienta que genera el place (build/build_place.luau).
]]

local Geometry = {}

local function parts(model: Instance): { BasePart }
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- Caja (alineada a los ejes del mundo) que envuelve todas las Parts: devuelve centro y tamaño.
function Geometry.bounds(model: Instance): (Vector3, Vector3)
	local minV, maxV = nil, nil
	for _, p in ipairs(parts(model)) do
		local half = p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = p.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					if not minV then
						minV, maxV = corner, corner
					else
						minV = Vector3.new(math.min(minV.X, corner.X), math.min(minV.Y, corner.Y), math.min(minV.Z, corner.Z))
						maxV = Vector3.new(math.max(maxV.X, corner.X), math.max(maxV.Y, corner.Y), math.max(maxV.Z, corner.Z))
					end
				end
			end
		end
	end
	if not minV then
		return Vector3.zero, Vector3.zero
	end
	return (minV + maxV) / 2, maxV - minV
end

-- Escala el modelo alrededor de su centro.
function Geometry.scale(model: Instance, factor: number)
	local center = Geometry.bounds(model)
	for _, p in ipairs(parts(model)) do
		local rot = p.CFrame - p.CFrame.Position
		p.Size = p.Size * factor
		p.CFrame = CFrame.new(center + (p.CFrame.Position - center) * factor) * rot
	end
end

-- Mueve/rota el modelo para que su centro quede en targetCFrame.
function Geometry.place(model: Instance, targetCFrame: CFrame)
	local center = Geometry.bounds(model)
	local origin = CFrame.new(center)
	for _, p in ipairs(parts(model)) do
		p.CFrame = targetCFrame * (origin:Inverse() * p.CFrame)
	end
end

-- Escala y coloca el modelo de pie sobre `floor`, mirando hacia `facing`. Devuelve su altura.
function Geometry.stand(model: Instance, scale: number, floor: Vector3, facing: Vector3): number
	if scale ~= 1 then
		Geometry.scale(model, scale)
	end
	local _, size = Geometry.bounds(model)
	local center = floor + Vector3.new(0, size.Y / 2, 0)
	Geometry.place(model, CFrame.lookAt(center, center + facing))
	return size.Y
end

return Geometry

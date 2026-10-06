--[[
	PescaDeMemes • UIKit (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > UIKit

	Componentes reutilizables: creación de instancias, botones animados, textos con contorno,
	paneles, escalado responsive (PC / tablet / móvil), sonidos y FOTOS 3D (ViewportFrame) de memes y equipo.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Assets = require(Root.Config.Assets)
local Memes = require(Root.Config.Memes)
local MemeModels = require(Root.Shared.MemeModels)

local UIKit = {}
UIKit.SFXEnabled = true
UIKit.SFXGroup = nil :: SoundGroup?

local RGB = Color3.fromRGB
UIKit.Theme = {
	Primary = RGB(255, 205, 40),
	PrimaryDark = RGB(255, 140, 0),
	Secondary = RGB(255, 90, 150),
	Accent = RGB(70, 195, 255),
	Success = RGB(80, 215, 110),
	Danger = RGB(255, 75, 75),
	Panel = RGB(20, 52, 72),
	PanelLight = RGB(36, 82, 108),
	PanelDark = RGB(12, 34, 50),
	Stroke = RGB(12, 8, 28),
	Text = RGB(255, 255, 255),
	TextDim = RGB(170, 210, 225),
	Water = RGB(40, 170, 190),
	Coin = RGB(255, 200, 50),
	FontTitle = Enum.Font.LuckiestGuy,
	Font = Enum.Font.FredokaOne,
	FontBody = Enum.Font.GothamBold,
}
local T = UIKit.Theme

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.merge(a: { [string]: any }, b: { [string]: any }?): { [string]: any }
	local r = table.clone(a)
	for k, v in pairs(b or {}) do
		r[k] = v
	end
	return r
end

function UIKit.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function UIKit.corner(parent: Instance, radius: number?)
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UIKit.stroke(parent: Instance, thickness: number?, color: Color3?, transparency: number?)
	return UIKit.new("UIStroke", {
		Thickness = thickness or 3, Color = color or T.Stroke, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round, Parent = parent,
	})
end

function UIKit.gradient(parent: Instance, colors: { Color3 }, rotation: number?)
	local kps = {}
	for i, c in ipairs(colors) do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
	end
	if #kps == 1 then
		table.insert(kps, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return UIKit.new("UIGradient", { Color = ColorSequence.new(kps), Rotation = rotation or 90, Parent = parent })
end

function UIKit.padding(parent: Instance, px: number)
	local p = UDim.new(0, px)
	return UIKit.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p, Parent = parent })
end

function UIKit.list(parent: Instance, dir: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?)
	return UIKit.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = parent,
	})
end

-- Texto escalado con contorno estilo cartoon.
function UIKit.label(props: { [string]: any }, opts: { [string]: any }?): TextLabel
	local o = opts or {}
	local lbl = UIKit.new("TextLabel", UIKit.merge({
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = T.Font, TextColor3 = T.Text,
		TextScaled = true, TextWrapped = true, Text = "",
	}, props))
	if o.Stroke ~= false then
		UIKit.new("UIStroke", { Name = "TextStroke", Thickness = o.Stroke or 2, Color = o.StrokeColor or T.Stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round, Parent = lbl })
	end
	if o.MaxSize then
		UIKit.new("UITextSizeConstraint", { MaxTextSize = o.MaxSize, MinTextSize = o.MinSize or 8, Parent = lbl })
	end
	return lbl
end

-- Botón con contorno, sombreado, hover y click animados.
-- opts: { Color, Text, TextSize, Radius, StrokeThickness, HoverScale, Font }
function UIKit.button(props: { [string]: any }, opts: { [string]: any }?): (TextButton, TextLabel?)
	local o = opts or {}
	local btn = UIKit.new("TextButton", UIKit.merge({
		AutoButtonColor = false, BackgroundColor3 = o.Color or T.Primary, BorderSizePixel = 0, Text = "",
	}, props))
	UIKit.corner(btn, o.Radius or 12)
	UIKit.stroke(btn, o.StrokeThickness or 3).Name = "Stroke"
	UIKit.gradient(btn, { Color3.new(1, 1, 1), RGB(205, 205, 215) }, 90).Name = "Shade"
	local label = nil
	if o.Text then
		label = UIKit.label({ Name = "Label", Text = o.Text, Font = o.Font or T.Font,
			Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Parent = btn },
			{ Stroke = o.TextStroke or 2, MaxSize = o.TextSize or 28 })
	end
	local scale = UIKit.new("UIScale", { Name = "PopScale", Parent = btn })
	local hoverScale = o.HoverScale or 1.06
	local hovering = false
	btn.MouseEnter:Connect(function()
		hovering = true
		UIKit.tween(scale, 0.12, { Scale = hoverScale })
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		UIKit.tween(scale, 0.12, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.06, { Scale = 0.92 })
	end)
	btn.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.22, { Scale = hovering and hoverScale or 1 }, Enum.EasingStyle.Back)
	end)
	btn.Activated:Connect(function()
		UIKit.playSound("Click")
	end)
	return btn, label
end

function UIKit.pop(inst: Instance, from: number?)
	local scale = inst:FindFirstChild("PopScale") or UIKit.new("UIScale", { Name = "PopScale", Parent = inst })
	scale.Scale = from or 1.2
	UIKit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UIKit.shake(inst: GuiObject)
	local base = inst.Position
	task.spawn(function()
		for i = 1, 6 do
			inst.Position = base + UDim2.fromOffset((i % 2 == 0 and 1 or -1) * (8 - i), 0)
			task.wait(0.03)
		end
		inst.Position = base
	end)
end

-- ===== Escalado responsive =====
-- Cada contenedor de primer nivel lleva un UIScale que se ajusta al tamaño de pantalla.
local scales: { UIScale } = {}
UIKit.CurrentScale = 1
local function computeScale(): number
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(vp.X / 1280, vp.Y / 720) * 1.05, 0.55, 1.3)
end
function UIKit.responsive(inst: GuiObject): UIScale
	local s = UIKit.new("UIScale", { Name = "ResponsiveScale", Scale = UIKit.CurrentScale, Parent = inst })
	table.insert(scales, s)
	return s
end
local function refreshScales()
	UIKit.CurrentScale = computeScale()
	for _, s in ipairs(scales) do
		if s.Parent then
			s.Scale = UIKit.CurrentScale
		end
	end
end
task.spawn(function()
	while not Workspace.CurrentCamera do
		task.wait()
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
	refreshScales()
end)

-- ===== Sonido =====
local soundCache: { [string]: Sound } = {}
function UIKit.playSound(name: string)
	if not UIKit.SFXEnabled then
		return
	end
	local id = Assets.Sounds[name]
	if not id or id == "" then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = UIKit.new("Sound", { Name = "UI_" .. name, SoundId = id, Volume = 0.6, SoundGroup = UIKit.SFXGroup, Parent = SoundService })
		soundCache[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

-- ===== Fotos 3D (ViewportFrame): los memes y el equipo se ven como modelos, no como emojis =====

-- (sin tabla débil: las entradas se borran cuando el ViewportFrame deja de tener padre)
local spinners: { [ViewportFrame]: { Model: Model, Center: CFrame, Speed: number } } = {}

-- Encuadra `model` dentro de un ViewportFrame. opts: { Spin = vel. (rad/s), Angle = grados de giro inicial,
-- Pitch = grados de inclinación de la cámara, Zoom = 1 (más = más cerca), Ambient, ZIndex }
function UIKit.viewport(model: Model, props: { [string]: any }, opts: { [string]: any }?): ViewportFrame
	local o = opts or {}
	local vp = UIKit.new("ViewportFrame", UIKit.merge({ BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = o.Ambient or RGB(170, 170, 180), LightColor = RGB(255, 250, 240), LightDirection = Vector3.new(-0.4, -1, 0.6) }, props))
	local center, size = model:GetBoundingBox()
	-- giramos el modelo (no la cámara) para que la luz le dé siempre de frente
	local spinCenter = CFrame.new(center.Position)
	model:PivotTo(spinCenter * CFrame.Angles(0, math.rad(o.Angle or 25), 0) * spinCenter:Inverse() * model:GetPivot())
	model.Parent = vp
	local fov = 35
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(fov / 2)) / (o.Zoom or 1.15)
	local pitch = math.rad(o.Pitch or 12)
	local camera = UIKit.new("Camera", { FieldOfView = fov, Parent = vp })
	local eye = center.Position + Vector3.new(0, math.sin(pitch), -math.cos(pitch)) * distance
	camera.CFrame = CFrame.lookAt(eye, center.Position)
	vp.CurrentCamera = camera
	if o.Spin then
		spinners[vp] = { Model = model, Center = spinCenter, Speed = o.Spin }
	end
	return vp
end

RunService.RenderStepped:Connect(function(dt)
	for vp, spin in pairs(spinners) do
		if not vp.Parent then
			spinners[vp] = nil
		elseif vp.Visible then
			local m = spin.Model
			m:PivotTo(spin.Center * CFrame.Angles(0, spin.Speed * dt, 0) * spin.Center:Inverse() * m:GetPivot())
		end
	end
end)


-- Icono de un meme: tu imagen (Config/Assets) o su FIGURA 3D sobre el color de su rareza.
-- opts: { Golden = bool, Silhouette = bool (sin descubrir: figura negra), Spin = rad/s }
function UIKit.memeIcon(memeId: string, props: { [string]: any }, opts: { [string]: any }?): Frame
	local o = opts or {}
	local rarity = Memes.GetRarity(memeId)
	local base = if o.Silhouette then RGB(60, 70, 90) elseif o.Golden then T.Coin else rarity.Color
	local frame = UIKit.new("Frame", UIKit.merge({ BackgroundColor3 = base, BorderSizePixel = 0, ClipsDescendants = true }, props))
	UIKit.corner(frame, 10)
	UIKit.gradient(frame, { base:Lerp(Color3.new(1, 1, 1), 0.3), base:Lerp(Color3.new(0, 0, 0), 0.4) }, 90)
	local image = not o.Silhouette and Assets.MemeImage(memeId)
	if image then
		UIKit.new("ImageLabel", { Name = "Image", BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05), Parent = frame })
	elseif MemeModels.Has(memeId) then
		local model = MemeModels.Build(memeId, 1, o.Golden == true, false)
		if o.Silhouette then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Color = RGB(15, 18, 28)
					d.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		UIKit.viewport(model, { Name = "Figure", Size = UDim2.fromScale(1, 1), ZIndex = frame.ZIndex, Parent = frame },
			{ Spin = o.Spin, Ambient = if o.Silhouette then RGB(0, 0, 0) else nil })
		if o.Silhouette then
			UIKit.label({ Name = "Unknown", Text = "?", Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.25, 0.22),
				Font = T.FontTitle, TextColor3 = T.TextDim, ZIndex = frame.ZIndex + 1, Parent = frame }, { Stroke = 3 })
		end
	else
		local meme = Memes.Get(memeId)
		UIKit.label({ Name = "Emoji", Text = meme and meme.Emoji or "❓", Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1), Font = T.Font, Parent = frame }, { Stroke = false })
	end
	return frame
end

-- Icono de un modelo cualquiera (caña, mochila, objeto) sobre un fondo de color.
function UIKit.modelIcon(model: Model, color: Color3, props: { [string]: any }, opts: { [string]: any }?): Frame
	local frame = UIKit.new("Frame", UIKit.merge({ BackgroundColor3 = color, BorderSizePixel = 0, ClipsDescendants = true }, props))
	UIKit.corner(frame, 10)
	UIKit.gradient(frame, { color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.4) }, 90)
	UIKit.viewport(model, { Name = "Figure", Size = UDim2.fromScale(1, 1), ZIndex = frame.ZIndex, Parent = frame }, opts)
	return frame
end

-- ===== Panel modal estándar (título + botón cerrar). Devuelve panel y área de contenido. =====
function UIKit.panel(parent: Instance, name: string, title: string, size: Vector2, color: Color3?): (Frame, Frame, TextButton)
	local panel = UIKit.new("Frame", {
		Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = T.Panel, Visible = false, Parent = parent,
	})
	UIKit.corner(panel, 20)
	UIKit.stroke(panel, 4)
	UIKit.responsive(panel)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(size.X, size.Y), Parent = panel })
	local header = UIKit.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = color or T.Secondary, Parent = panel })
	UIKit.corner(header, 20)
	UIKit.new("Frame", { Name = "HeaderFill", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = color or T.Secondary, BorderSizePixel = 0, Parent = header })
	UIKit.label({ Name = "Title", Text = title, Font = T.FontTitle, Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(20, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = header }, { Stroke = 3 })
	local close = UIKit.button({ Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(40, 40), Parent = header }, { Color = T.Danger, Text = "X", Radius = 10, TextSize = 24 })
	local content = UIKit.new("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 1, -80), Parent = panel })
	return panel, content, close
end

return UIKit

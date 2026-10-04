--[[
	MemeGame • UIKit (ModuleScript, cliente)
	StarterPlayerScripts > MemeGameClient > Controllers > UIKit

	Componentes reutilizables: creación de instancias, botones animados, textos con contorno,
	paneles, escalado responsive (PC / tablet / móvil), sonidos e iconos de memes.
]]

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local Assets = require(Shared.Config.Assets)
local MemeCatalog = require(Shared.Config.MemeCatalog)

local UIKit = {}
UIKit.SFXEnabled = true
UIKit.SFXGroup = nil :: SoundGroup?

local RGB = Color3.fromRGB
UIKit.Theme = {
	Primary = RGB(255, 205, 40),
	PrimaryDark = RGB(255, 140, 0),
	Secondary = RGB(255, 70, 140),
	Accent = RGB(70, 195, 255),
	Success = RGB(80, 215, 110),
	Danger = RGB(255, 75, 75),
	Panel = RGB(34, 28, 64),
	PanelLight = RGB(58, 48, 104),
	PanelDark = RGB(22, 18, 44),
	Stroke = RGB(12, 8, 28),
	Text = RGB(255, 255, 255),
	TextDim = RGB(190, 182, 230),
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

-- ===== Icono de un meme: tu imagen (Assets) o el emoji sobre el color de su rareza =====
function UIKit.memeIcon(memeId: string, props: { [string]: any }): Frame
	local meme = MemeCatalog.Get(memeId)
	local rarity = MemeCatalog.GetRarity(memeId)
	local frame = UIKit.new("Frame", UIKit.merge({ BackgroundColor3 = rarity.Color, BorderSizePixel = 0 }, props))
	UIKit.corner(frame, 10)
	UIKit.gradient(frame, { rarity.Color:Lerp(Color3.new(1, 1, 1), 0.25), rarity.Color:Lerp(Color3.new(0, 0, 0), 0.35) }, 90)
	local image = Assets.MemeImage(memeId)
	if image then
		UIKit.new("ImageLabel", { Name = "Image", BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05), Parent = frame })
	else
		UIKit.label({ Name = "Emoji", Text = meme and meme.Emoji or "❓", Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1), Font = T.Font, Parent = frame }, { Stroke = false })
	end
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

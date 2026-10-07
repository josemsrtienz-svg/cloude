--[[
	PescaDeMemes • UIKit (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > UIKit

	Componentes reutilizables: creación de instancias, botones animados, textos con contorno,
	paneles, escalado responsive (PC / tablet / móvil), sonidos y FOTOS 3D (ViewportFrame) de memes y equipo.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
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
-- Pantalla táctil sin teclado = móvil/tablet (ahí los botones no pueden ser diminutos).
function UIKit.IsTouch(): boolean
	local uis = game:GetService("UserInputService")
	return uis.TouchEnabled and not uis.KeyboardEnabled
end

local function computeScale(): number
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local minScale = if UIKit.IsTouch() then 0.62 else 0.55 -- en móvil, dedos: un poco más grande
	return math.clamp(math.min(vp.X / 1280, vp.Y / 720) * 1.05, minScale, 1.3)
end
local scaleListeners: { () -> () } = {}
-- Llama a `fn` cada vez que cambia la escala (p. ej. al girar el móvil o redimensionar la ventana).
function UIKit.OnScaleChanged(fn: () -> ())
	table.insert(scaleListeners, fn)
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
	for _, fn in ipairs(scaleListeners) do
		task.spawn(fn)
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
-- Cada sonido de Config/Assets tiene candidatos: se precargan y se queda el primero que carga (si ninguno
-- carga, ese sonido simplemente no suena). UIKit.PreloadSounds() lo arranca el controlador Audio.
local resolved: { [string]: Sound | false } = {}
local resolving: { [string]: boolean } = {}
local soundRng = Random.new()

local function resolveSound(name: string)
	if resolving[name] or resolved[name] ~= nil then
		return
	end
	resolving[name] = true
	task.spawn(function()
		local def = Assets.Sounds[name]
		for _, id in ipairs(def and def.Ids or {}) do
			local sound = UIKit.new("Sound", { Name = "SFX_" .. name, SoundId = id, Volume = def.Volume or 0.6,
				SoundGroup = UIKit.SFXGroup, Parent = SoundService })
			local ok = false
			pcall(function()
				ContentProvider:PreloadAsync({ sound }, function(_, status)
					ok = status == Enum.AssetFetchStatus.Success
				end)
			end)
			if ok then
				resolved[name] = sound
				resolving[name] = nil
				return
			end
			sound:Destroy()
		end
		resolved[name] = false
		resolving[name] = nil
	end)
end

function UIKit.PreloadSounds()
	for name in pairs(Assets.Sounds) do
		resolveSound(name)
	end
end

function UIKit.playSound(name: string, pitch: number?)
	if not UIKit.SFXEnabled then
		return
	end
	local sound = resolved[name]
	if sound == nil then
		resolveSound(name) -- aún no estaba precargado: sonará la próxima vez
		return
	end
	if not sound then
		return
	end
	local def = Assets.Sounds[name]
	sound.SoundGroup = UIKit.SFXGroup
	sound.PlaybackSpeed = (def.Speed or 1) * (pitch or 1) * (1 + soundRng:NextNumber(-1, 1) * (def.Vary or 0))
	SoundService:PlayLocalSound(sound)
end

-- ===== "Dopamina": recompensas que se SIENTEN (sonido + confeti + destello) =====
-- Escala mayor: cada meme enganchado en la misma inmersión suena una nota más aguda (como un combo).
local SCALE = { 1, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888, 2 }
function UIKit.combo(step: number)
	local i = math.clamp(step, 1, #SCALE)
	UIKit.playSound("Combo", SCALE[i])
	if step >= 3 then
		task.delay(0.07, function()
			UIKit.playSound("Combo", SCALE[i] * 1.5) -- a partir del 3º, acorde doble
		end)
	end
end

local fxGui: ScreenGui? = nil
local function effectsGui(): ScreenGui?
	if fxGui and fxGui.Parent then
		return fxGui
	end
	local player = game:GetService("Players").LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	fxGui = UIKit.new("ScreenGui", { Name = "PescaFX", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
	return fxGui
end

local CONFETTI = { RGB(255, 205, 40), RGB(255, 90, 150), RGB(70, 195, 255), RGB(80, 215, 110), RGB(185, 90, 255), RGB(255, 255, 255) }
-- Lluvia de confeti desde arriba (count piezas). colors opcional (p. ej. el color de la rareza).
function UIKit.confetti(count: number, colors: { Color3 }?)
	local layer = effectsGui()
	if not layer then
		return
	end
	local palette = colors or CONFETTI
	for _ = 1, count do
		local size = soundRng:NextInteger(8, 16)
		local piece = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, math.floor(size * 0.6)),
			Position = UDim2.new(soundRng:NextNumber(0.1, 0.9), 0, -0.05, 0), Rotation = soundRng:NextNumber(0, 360),
			BackgroundColor3 = palette[soundRng:NextInteger(1, #palette)], BorderSizePixel = 0, Parent = layer })
		local time = soundRng:NextNumber(1.2, 2.2)
		local drift = soundRng:NextNumber(-0.15, 0.15)
		local tween = TweenService:Create(piece, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = piece.Position + UDim2.fromScale(drift, 1.15), Rotation = piece.Rotation + soundRng:NextNumber(-540, 540),
			BackgroundTransparency = 0.3 })
		tween.Completed:Once(function()
			piece:Destroy()
		end)
		task.delay(soundRng:NextNumber(0, 0.35), function()
			tween:Play()
		end)
	end
end

-- Destello de pantalla completa del color dado.
function UIKit.flash(color: Color3, strength: number?)
	local layer = effectsGui()
	if not layer then
		return
	end
	local f = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 1 - (strength or 0.45),
		BorderSizePixel = 0, Parent = layer })
	local tween = TweenService:Create(f, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
	tween.Completed:Once(function()
		f:Destroy()
	end)
	tween:Play()
end

-- Temblor de cámara (se aplica DESPUÉS de cualquier cámara: la normal o la de la inmersión).
-- La cámara normal de Roblox calcula el frame siguiente a partir de camera.CFrame, así que el temblor
-- se DESHACE antes de que corra (si nadie ha movido la cámara entretanto); si no, el giro se acumularía
-- y la cámara acabaría torcida.
local shakeUntil, shakeStrength, shakeBound = 0, 0, false
local shakeOffset: CFrame?, shakeApplied: CFrame? = nil, nil
UIKit.ShakeEnabled = true -- ⚙️ Ajustes → Temblor de cámara
local function undoShake()
	local camera = Workspace.CurrentCamera
	if shakeOffset and shakeApplied and camera and camera.CFrame:FuzzyEq(shakeApplied, 1e-4) then
		camera.CFrame *= shakeOffset:Inverse()
	end
	shakeOffset, shakeApplied = nil, nil
end
function UIKit.shake3D(strength: number, duration: number)
	if not UIKit.ShakeEnabled then
		return
	end
	shakeStrength = math.max(if os.clock() < shakeUntil then shakeStrength else 0, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
	if shakeBound then
		return
	end
	shakeBound = true
	RunService:BindToRenderStep("PescaShakeUndo", Enum.RenderPriority.First.Value, undoShake)
	RunService:BindToRenderStep("PescaShake", Enum.RenderPriority.Last.Value, function()
		local left = shakeUntil - os.clock()
		local camera = Workspace.CurrentCamera
		if left <= 0 or not camera then
			-- terminado: se suelta el render step hasta el próximo temblor
			undoShake()
			RunService:UnbindFromRenderStep("PescaShake")
			RunService:UnbindFromRenderStep("PescaShakeUndo")
			shakeBound = false
			return
		end
		local k = shakeStrength * math.min(1, left * 3) -- se apaga suave al final
		local offset = CFrame.Angles(soundRng:NextNumber(-1, 1) * k * 0.02, soundRng:NextNumber(-1, 1) * k * 0.02, 0)
			+ Vector3.new(soundRng:NextNumber(-1, 1), soundRng:NextNumber(-1, 1), 0) * k * 0.15
		camera.CFrame *= offset
		shakeOffset, shakeApplied = offset, camera.CFrame
	end)
end

-- Celebración según lo bueno que sea (order = orden de rareza 1..8; golden/new añaden brillo):
--   1–2 pop · 3 + chispa · 4 + fanfarria corta · 5–6 fanfarria + golpe + confeti + destello · 7+ todo a lo grande
function UIKit.celebrate(order: number, color: Color3?, golden: boolean?, isNew: boolean?)
	if order >= 7 then
		UIKit.shake3D(1.6, 0.9)
		UIKit.playSound("Boom")
		UIKit.playSound("Fanfare")
		UIKit.flash(color or T.Primary, 0.6)
		UIKit.confetti(120, if color then { color, T.Primary, Color3.new(1, 1, 1) } else nil)
		task.delay(0.5, function()
			UIKit.playSound("Fanfare", 1.25)
			UIKit.confetti(60)
		end)
	elseif order >= 5 then
		UIKit.shake3D(0.9, 0.5)
		UIKit.playSound("Boom")
		UIKit.playSound("Fanfare")
		UIKit.flash(color or T.Primary, 0.4)
		UIKit.confetti(70)
	elseif order == 4 then
		UIKit.playSound("Reward")
		UIKit.confetti(30)
	elseif order == 3 then
		UIKit.playSound("Catch")
		UIKit.playSound("Sparkle")
	else
		UIKit.playSound("Catch")
	end
	if golden or isNew then
		for k = 0, 2 do
			task.delay(0.12 * k, function()
				UIKit.playSound("Sparkle", 1 + k * 0.12)
			end)
		end
		if golden then
			UIKit.flash(T.Coin, 0.3)
		end
	end
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

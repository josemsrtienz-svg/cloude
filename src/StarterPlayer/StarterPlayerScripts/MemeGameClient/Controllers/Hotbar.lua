--[[
	MemeGame • Hotbar (ModuleScript, cliente)
	Barra inferior de 3 slots con los memes equipados.
	  - En el lobby: muestra lo que llevas preparado (clic → abre el inventario).
	  - En partida: teclas 1 / 2 / 3, clic o toque activan la habilidad del meme.
	El servidor valida cooldown y que estés en partida; el cliente solo pinta el efecto.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)

local Hotbar = {}

local player = Players.LocalPlayer
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local GAMEPAD = { Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonR1 }

function Hotbar.Init(app)
	local UI, State = app.UI, app.State
	local T = UI.Theme

	local bar = UI.new("Frame", { Name = "Hotbar", AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(3 * 86 + 2 * 10, 110), Parent = app.Gui })
	UI.responsive(bar)
	local hint = UI.label({ Name = "Hint", Text = "MEMES EQUIPADOS", Size = UDim2.new(1, 0, 0, 20), TextColor3 = T.TextDim,
		Parent = bar }, { MaxSize = 16 })
	local row = UI.new("Frame", { Name = "Slots", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 86), Parent = bar })
	UI.list(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)

	local slots = {}
	local busyUntil = { 0, 0, 0 }

	local function activate(i: number)
		local data = State.Data
		if not data then
			return
		end
		if State.GameState() ~= "Match" then
			app.OpenPanel("Inventory")
			return
		end
		if data.EquippedMemes[i] == "" then
			State.Notify:Fire("Slot " .. i .. " vacío", "Error")
			return
		end
		if os.clock() < busyUntil[i] then
			return
		end
		local ok, _, ability = State.Request("UseAbility", i)
		local s = slots[i]
		if not ok or not ability then
			UI.shake(s.Frame)
			return
		end
		UI.pop(s.Frame, 1.25)
		UI.playSound("Equip")
		-- efecto local
		if ability.Type == "Dash" then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local look = root.CFrame.LookVector
				root.AssemblyLinearVelocity = Vector3.new(look.X * ability.Power, 25, look.Z * ability.Power)
			end
		end
		-- overlay de recarga
		busyUntil[i] = os.clock() + ability.Cooldown
		s.Cooldown.Visible = true
		s.Cooldown.Size = UDim2.fromScale(1, 1)
		UI.tween(s.Cooldown, ability.Cooldown, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Linear)
		task.delay(ability.Cooldown, function()
			s.Cooldown.Visible = false
			UI.pop(s.Frame, 1.15)
		end)
	end

	for i = 1, GameConfig.MaxEquipped do
		local slot = UI.button({ Name = "Slot" .. i, Size = UDim2.fromOffset(86, 86), BackgroundColor3 = T.PanelDark, LayoutOrder = i, Parent = row },
			{ Color = T.PanelDark, Radius = 16, HoverScale = 1.08 })
		slot:FindFirstChild("Shade"):Destroy()
		local holder = UI.new("Frame", { Name = "Holder", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, -12),
			Position = UDim2.fromOffset(6, 6), Parent = slot })
		local empty = UI.label({ Name = "Empty", Text = "+", Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.2, 0.15),
			TextColor3 = T.TextDim, Parent = holder }, { Stroke = false })
		local key = UI.new("Frame", { Name = "Key", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(-6, -6),
			BackgroundColor3 = T.Primary, ZIndex = 5, Parent = slot })
		UI.corner(key, 12)
		UI.stroke(key, 2)
		UI.label({ Text = tostring(i), Size = UDim2.fromScale(1, 1), TextColor3 = T.Stroke, Font = T.FontTitle, ZIndex = 6, Parent = key }, { Stroke = false })
		local cooldown = UI.new("Frame", { Name = "Cooldown", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false,
			ZIndex = 4, Parent = slot })
		UI.corner(cooldown, 16)
		local nameLbl = UI.label({ Name = "MemeName", Text = "", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, 10, 0, 16),
			Position = UDim2.new(0.5, 0, 1, 2), ZIndex = 5, Parent = slot }, { MaxSize = 13 })
		slot.Activated:Connect(function()
			activate(i)
		end)
		slots[i] = { Frame = slot, Holder = holder, Empty = empty, Cooldown = cooldown, Name = nameLbl, Shown = nil }
	end

	local function refresh(data)
		for i, s in ipairs(slots) do
			local id = data.EquippedMemes[i]
			if s.Shown ~= id then
				s.Shown = id
				local old = s.Holder:FindFirstChild("Icon")
				if old then
					old:Destroy()
				end
				local stroke = s.Frame:FindFirstChild("Stroke")
				if id ~= "" and MemeCatalog.Get(id) then
					local icon = UI.memeIcon(id, { Name = "Icon", Size = UDim2.fromScale(1, 1) })
					icon.Parent = s.Holder
					s.Empty.Visible = false
					s.Name.Text = MemeCatalog.Get(id).Name
					if stroke then
						stroke.Color = MemeCatalog.GetRarity(id).Color
					end
					UI.pop(s.Frame, 1.2)
				else
					s.Empty.Visible = true
					s.Name.Text = ""
					if stroke then
						stroke.Color = T.Stroke
					end
				end
			end
		end
	end
	State.DataChanged:Connect(refresh)

	local function onState(state)
		hint.Text = state == "Match" and "HABILIDADES · TECLAS 1 · 2 · 3" or "MEMES EQUIPADOS"
		hint.TextColor3 = state == "Match" and T.Primary or T.TextDim
	end
	State.GameStateChanged:Connect(onState)
	onState(State.GameState())

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		for i = 1, GameConfig.MaxEquipped do
			if input.KeyCode == KEYS[i] or input.KeyCode == GAMEPAD[i] then
				if State.GameState() == "Match" then
					activate(i)
				end
			end
		end
	end)
end

return Hotbar

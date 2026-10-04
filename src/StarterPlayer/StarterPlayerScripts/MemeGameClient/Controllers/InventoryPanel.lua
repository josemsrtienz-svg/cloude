--[[
	MemeGame • InventoryPanel (ModuleScript, cliente)
	Muestra los memes que posees: imagen, nombre, rareza, cantidad, estado y EQUIPAR/DESEQUIPAR.
	Arriba están tus 3 slots. Si intentas equipar un 4º meme, el servidor lo rechaza
	("Máximo de 3 memes equipados.") y aquí también se avisa antes de pedirlo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)

local InventoryPanel = {}

function InventoryPanel.Init(app)
	local UI, State = app.UI, app.State
	local T = UI.Theme

	local panel, content, close = UI.panel(app.Gui, "InventoryPanel", "🎒 INVENTARIO", Vector2.new(780, 520), T.Accent)
	app.RegisterPanel("Inventory", panel, close)

	-- fila de slots
	local slotsRow = UI.new("Frame", { Name = "SlotsRow", BackgroundColor3 = T.PanelDark, Size = UDim2.new(1, 0, 0, 84), Parent = content })
	UI.corner(slotsRow, 14)
	local slotsTitle = UI.label({ Name = "SlotsTitle", Text = "EQUIPADOS 0/3", Size = UDim2.fromOffset(170, 30),
		Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, Font = T.FontTitle, Parent = slotsRow }, { MaxSize = 24 })
	UI.label({ Text = "Máximo " .. GameConfig.MaxEquipped .. " memes. Se usan en partida con las teclas 1·2·3.",
		Size = UDim2.fromOffset(170, 34), Position = UDim2.fromOffset(12, 40), TextColor3 = T.TextDim, Font = T.FontBody,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = slotsRow }, { Stroke = 1, MaxSize = 12 })
	local slotHolder = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(190, 6), Size = UDim2.new(1, -200, 1, -12), Parent = slotsRow })
	UI.list(slotHolder, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local slotFrames = {}
	for i = 1, GameConfig.MaxEquipped do
		local f = UI.new("Frame", { Name = "Slot" .. i, Size = UDim2.fromOffset(170, 70), BackgroundColor3 = T.Panel, LayoutOrder = i, Parent = slotHolder })
		UI.corner(f, 12)
		UI.stroke(f, 2)
		slotFrames[i] = f
	end

	-- cuadrícula
	local scroll = UI.new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 1, -94), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = T.Primary, Parent = content })
	UI.padding(scroll, 6)
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 236), CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = scroll })
	local emptyText = UI.label({ Name = "EmptyText", Text = "No tienes memes todavía. ¡Visita el MemeMarket! 🛒",
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 140), Visible = false, Parent = content }, { MaxSize = 22 })

	local function equipped(data, id): number?
		return table.find(data.EquippedMemes, id)
	end

	local function render()
		local data = State.Data
		if not data or not panel.Visible then
			return
		end
		-- slots
		local count = 0
		for i, f in ipairs(slotFrames) do
			f:ClearAllChildren()
			UI.corner(f, 12)
			local id = data.EquippedMemes[i]
			local meme = MemeCatalog.Get(id)
			local stroke = UI.stroke(f, 2)
			if meme then
				count += 1
				stroke.Color = MemeCatalog.GetRarity(id).Color
				UI.memeIcon(id, { Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(8, 8), Parent = f })
				UI.label({ Text = meme.Name, Size = UDim2.fromOffset(100, 26), Position = UDim2.fromOffset(66, 6),
					TextXAlignment = Enum.TextXAlignment.Left, Parent = f }, { MaxSize = 16 })
				local b = UI.button({ Size = UDim2.fromOffset(96, 28), Position = UDim2.fromOffset(66, 36), Parent = f },
					{ Color = T.Danger, Text = "QUITAR", TextSize = 16, Radius = 8, StrokeThickness = 2 })
				b.Activated:Connect(function()
					State.Request("UnequipSlot", i)
				end)
			else
				UI.label({ Text = ("SLOT %d · VACÍO"):format(i), Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
					TextColor3 = T.TextDim, Parent = f }, { MaxSize = 18 })
			end
		end
		slotsTitle.Text = ("EQUIPADOS %d/%d"):format(count, GameConfig.MaxEquipped)
		slotsTitle.TextColor3 = count >= GameConfig.MaxEquipped and T.Primary or T.Text

		-- tarjetas
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local ids = {}
		for id in pairs(data.OwnedMemes) do
			if MemeCatalog.Get(id) then
				table.insert(ids, id)
			end
		end
		MemeCatalog.Sort(ids)
		emptyText.Visible = #ids == 0
		for order, id in ipairs(ids) do
			local meme = MemeCatalog.Get(id)
			local rarity = MemeCatalog.GetRarity(id)
			local slot = equipped(data, id)
			local card = UI.new("Frame", { Name = id, BackgroundColor3 = T.PanelLight, LayoutOrder = order, Parent = scroll })
			UI.corner(card, 14)
			UI.stroke(card, 3, slot and T.Primary or rarity.Color)
			UI.memeIcon(id, { Size = UDim2.fromOffset(110, 110), Position = UDim2.fromOffset(30, 8), Parent = card })
			local qty = UI.new("Frame", { Size = UDim2.fromOffset(40, 24), Position = UDim2.fromOffset(122, 4), BackgroundColor3 = T.Primary, Parent = card })
			UI.corner(qty, 12)
			UI.stroke(qty, 2)
			UI.label({ Text = "x" .. data.OwnedMemes[id], Size = UDim2.fromScale(1, 1), TextColor3 = T.Stroke, Font = T.FontTitle, Parent = qty }, { Stroke = false })
			UI.label({ Text = meme.Name, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 120), Parent = card }, { MaxSize = 18 })
			UI.label({ Text = rarity.Name, Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 144), TextColor3 = rarity.Color,
				Font = T.FontTitle, Parent = card }, { MaxSize = 16 })
			UI.label({ Text = slot and ("✅ EQUIPADO · SLOT " .. slot) or "EN INVENTARIO", Size = UDim2.new(1, -12, 0, 16),
				Position = UDim2.fromOffset(6, 164), TextColor3 = slot and T.Success or T.TextDim, Font = T.FontBody, Parent = card }, { Stroke = 1, MaxSize = 12 })
			local btn = UI.button({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 186), Parent = card },
				{ Color = slot and T.Danger or T.Success, Text = slot and "DESEQUIPAR" or "EQUIPAR", TextSize = 20, Radius = 10 })
			btn.Activated:Connect(function()
				local current = State.Data
				local s = equipped(current, id)
				if s then
					State.Request("UnequipSlot", s)
				else
					local n = 0
					for _, e in ipairs(current.EquippedMemes) do
						if e ~= "" then
							n += 1
						end
					end
					if n >= GameConfig.MaxEquipped then
						-- aviso inmediato; el servidor lo rechazaría igual
						State.Notify:Fire(("Máximo de %d memes equipados."):format(GameConfig.MaxEquipped), "Error")
						UI.shake(card)
						return
					end
					if State.Request("EquipMeme", id) then
						UI.playSound("Equip")
					end
				end
			end)
			-- descripción al pasar el mouse
			card.MouseEnter:Connect(function()
				app.Tooltip(meme.Description)
			end)
			card.MouseLeave:Connect(function()
				app.Tooltip(nil)
			end)
		end
	end

	State.DataChanged:Connect(render)
	panel:GetPropertyChangedSignal("Visible"):Connect(render)
end

return InventoryPanel

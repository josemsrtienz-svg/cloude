--[[
	PescaDeMemes • Panels (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > Panels

	Paneles modales: 🎒 Mochila · 🏠 Parcela · 🛒 Tienda · 📖 Bestiario.
	Se abren con los botones del HUD o con el ProximityPrompt de la tienda.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local FishMath = require(Root.Shared.FishMath)
local Util = require(Root.Shared.Util)
local Inventory = require(Root.Shared.Inventory)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local HUD = require(Controllers.HUD)

local T = UIKit.Theme
local Panels = {}

local gui: ScreenGui
local panels: { [string]: { Frame: Frame, Content: Frame, Render: () -> (), Signature: string } } = {}
local openName: string? = nil
local busy = false

local function call(remote: string, okText: string?, ...: any): any
	if busy then
		return { ok = false }
	end
	busy = true
	local r = State.Call(remote, ...)
	busy = false
	if r.ok then
		if okText then
			HUD.Toast(okText, "Success")
		end
	else
		HUD.Toast(r.err or "No se pudo", "Error")
	end
	return r
end

local function clear(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function scroller(parent: Instance, cell: Vector2, top: number?): ScrollingFrame
	local sf = UIKit.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -(top or 0)), Position = UDim2.fromOffset(0, top or 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = parent })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = sf })
	UIKit.padding(sf, 6)
	return sf
end

-- Tarjeta pequeña de una captura.
local function catchTile(parent: Instance, catch: any, order: number): TextButton
	local meme = Memes.Get(catch.MemeId)
	local rarity = Memes.GetRarity(catch.MemeId)
	local tile = UIKit.new("TextButton", { LayoutOrder = order, Text = "", AutoButtonColor = false, BackgroundColor3 = T.PanelLight, Parent = parent })
	UIKit.corner(tile, 12)
	UIKit.stroke(tile, 3, if catch.Golden then T.Coin else rarity.Color)
	UIKit.memeIcon(catch.MemeId, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, -35, 0, 8), Parent = tile })
	UIKit.label({ Text = meme and meme.Name or "?", Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 82), Font = T.Font,
		TextColor3 = if catch.Golden then T.Coin else T.Text, Parent = tile }, { MaxSize = 18 })
	UIKit.label({ Text = FishMath.FormatWeight(catch.Weight) .. (if catch.Impossible then " 🏆" else ""), Size = UDim2.new(1, -8, 0, 18),
		Position = UDim2.fromOffset(4, 104), Font = T.FontBody, TextColor3 = T.TextDim, Parent = tile }, { Stroke = false, MaxSize = 15 })
	UIKit.label({ Text = "🪙 " .. Util.formatNumber(catch.Value), Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 124),
		Font = T.Font, TextColor3 = T.Coin, Parent = tile }, { MaxSize = 17 })
	return tile
end

-- Menú de opciones al tocar una captura de la mochila.
local function catchOptions(catch: any)
	local panel = panels.Backpack
	local old = panel.Frame:FindFirstChild("Options")
	if old then
		old:Destroy()
	end
	local meme = Memes.Get(catch.MemeId)
	local box = UIKit.new("Frame", { Name = "Options", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(330, 210), BackgroundColor3 = T.PanelDark, ZIndex = 10, Parent = panel.Frame })
	UIKit.corner(box, 16)
	UIKit.stroke(box, 4, T.Primary)
	UIKit.label({ Text = (meme and meme.Name or "?") .. " · " .. FishMath.FormatWeight(catch.Weight), Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 10), Font = T.FontTitle, ZIndex = 11, Parent = box }, { Stroke = 2, MaxSize = 26 })
	local list = UIKit.new("Frame", { Size = UDim2.new(1, -20, 1, -56), Position = UDim2.fromOffset(10, 50), BackgroundTransparency = 1, ZIndex = 11, Parent = box })
	UIKit.list(list, Enum.FillDirection.Vertical, 6)
	local function opt(text: string, color: Color3, order: number, fn: () -> ())
		local b = UIKit.button({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), ZIndex = 12, Parent = list }, { Color = color, Text = text, TextSize = 22 })
		b.Activated:Connect(fn)
	end
	opt("🏠 Llevar a mi parcela", T.Accent, 1, function()
		if call("CarryCatch", "🏠 ¡Llévalo a un pedestal de tu parcela!", catch.Id).ok then
			Panels.Close()
		end
	end)
	opt(("💰 Vender por %s"):format(Util.formatNumber(catch.Value)), T.Primary, 2, function()
		local r = call("SellCatch", nil, catch.Id)
		if r.ok then
			HUD.Toast(("💰 +%s MemeCoins"):format(Util.formatNumber(r.Earned or 0)), "Success")
			box:Destroy()
		end
	end)
	opt("Cancelar", T.PanelLight, 3, function()
		box:Destroy()
	end)
end

-- ===== Mochila =====
local function renderBackpack()
	local p = panels.Backpack
	local grid = p.Content:FindFirstChild("Grid") :: ScrollingFrame
	clear(grid)
	local list = State.Backpack()
	p.Content.Count.Text = ("%d / %d capturas"):format(#list, GameConfig.MaxBackpack)
	if #list == 0 then
		UIKit.label({ Text = "Tu mochila está vacía. ¡Ve a pescar! 🎣", Size = UDim2.fromOffset(400, 40), Font = T.Font, Parent = grid }, { MaxSize = 24 })
	end
	for i, catch in ipairs(list) do
		catchTile(grid, catch, i).Activated:Connect(function()
			catchOptions(catch)
		end)
	end
end

-- ===== Parcela =====
local function renderPlot()
	local p = panels.Plot
	local data = State.Data
	local grid = p.Content:FindFirstChild("Grid") :: ScrollingFrame
	clear(grid)
	if not data then
		return
	end
	for slot = 1, GameConfig.PlotSlots do
		local id = data.Plot[slot]
		local catch = id ~= "" and data.Catches[id]
		if catch then
			local tile = catchTile(grid, catch, slot)
			UIKit.label({ Text = "Pedestal " .. slot, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, -8, 0, 14),
				Font = T.FontBody, TextColor3 = T.TextDim, Parent = tile }, { Stroke = false, MaxSize = 12 })
			tile.Activated:Connect(function()
				HUD.Toast("Para moverlo, ve a tu parcela y pulsa \"Recoger\" en su pedestal", "Info")
			end)
		else
			local empty = UIKit.new("Frame", { LayoutOrder = slot, BackgroundColor3 = T.PanelDark, Parent = grid })
			UIKit.corner(empty, 12)
			UIKit.stroke(empty, 3, T.PanelLight)
			UIKit.label({ Text = ("Pedestal %d\nlibre"):format(slot), Size = UDim2.fromScale(1, 1), Font = T.Font, TextColor3 = T.TextDim, Parent = empty }, { MaxSize = 20 })
		end
	end
	local bank = Players.LocalPlayer:GetAttribute("PlotBank")
	p.Content.Count.Text = ("🪙 %s · Cobrador: 🪙 %s"):format(Inventory.FormatIncome(Inventory.PlotIncomePerMinute(data, GameConfig.PlotIncomeRate)),
		Util.formatNumber(if type(bank) == "number" then bank else data.PlotBank or 0))
end

-- ===== Tienda =====
local function renderShop()
	local p = panels.Shop
	local data = State.Data
	local grid = p.Content:FindFirstChild("Grid") :: ScrollingFrame
	clear(grid)
	if not data then
		return
	end
	p.Content.Count.Text = ("Tienes 🪙 %s"):format(Util.formatNumber(data.MemeCoin))
	for i, rod in ipairs(Rods.List) do
		local owned = data.Rods[rod.Id] == true
		local equipped = data.EquippedRod == rod.Id
		local card = UIKit.new("Frame", { LayoutOrder = i, BackgroundColor3 = T.PanelLight, Parent = grid })
		UIKit.corner(card, 14)
		UIKit.stroke(card, 3, if equipped then T.Success else rod.Color)
		UIKit.label({ Text = rod.Emoji .. " " .. rod.Name, Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 6), Font = T.FontTitle,
			Parent = card }, { Stroke = 2, MaxSize = 22 })
		UIKit.label({ Text = ("🎣 Capacidad: %s"):format(FishMath.FormatWeight(rod.Capacity)), Size = UDim2.new(1, -12, 0, 22),
			Position = UDim2.fromOffset(6, 38), Font = T.Font, TextColor3 = T.Coin, Parent = card }, { MaxSize = 18 })
		UIKit.label({ Text = rod.Description, Size = UDim2.new(1, -12, 0, 40), Position = UDim2.fromOffset(6, 62), Font = T.FontBody,
			TextColor3 = T.TextDim, Parent = card }, { Stroke = false, MaxSize = 15 })
		local text, color = "", T.Primary
		if equipped then
			text, color = "✅ Equipada", T.PanelDark
		elseif owned then
			text, color = "Equipar", T.Accent
		else
			text = "🪙 " .. Util.formatNumber(rod.Price)
			color = if data.MemeCoin >= rod.Price then T.Primary else T.PanelDark
		end
		local btn = UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 42), Parent = card },
			{ Color = color, Text = text, TextSize = 22 })
		btn.Activated:Connect(function()
			if equipped then
				return
			elseif owned then
				call("EquipRod", "🎣 " .. rod.Name .. " equipada", rod.Id)
			else
				call("BuyRod", "🎉 ¡Has comprado la " .. rod.Name .. "!", rod.Id)
			end
		end)
	end
	local item = Rods.Items.SedalReforzado
	local card = UIKit.new("Frame", { LayoutOrder = 100, BackgroundColor3 = T.PanelLight, Parent = grid })
	UIKit.corner(card, 14)
	UIKit.stroke(card, 3, T.Secondary)
	UIKit.label({ Text = item.Emoji .. " " .. item.Name, Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 6), Font = T.FontTitle,
		Parent = card }, { Stroke = 2, MaxSize = 22 })
	UIKit.label({ Text = ("Tienes: %d"):format(data.Items.SedalReforzado or 0), Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 38),
		Font = T.Font, TextColor3 = T.Coin, Parent = card }, { MaxSize = 18 })
	UIKit.label({ Text = item.Description, Size = UDim2.new(1, -12, 0, 40), Position = UDim2.fromOffset(6, 62), Font = T.FontBody,
		TextColor3 = T.TextDim, Parent = card }, { Stroke = false, MaxSize = 15 })
	local buy = UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 42), Parent = card },
		{ Color = if data.MemeCoin >= item.Price then T.Primary else T.PanelDark, Text = "🪙 " .. Util.formatNumber(item.Price), TextSize = 22 })
	buy.Activated:Connect(function()
		call("BuyItem", "🧵 +1 Sedal Reforzado (actívalo junto al botón LANZAR)", item.Id)
	end)
end

-- ===== Bestiario =====
local function renderBestiary()
	local p = panels.Bestiary
	local data = State.Data
	local grid = p.Content:FindFirstChild("Grid") :: ScrollingFrame
	clear(grid)
	if not data then
		return
	end
	local found = 0
	for i, meme in ipairs(Memes.List) do
		local entry = data.Discovered[meme.Id]
		local rarity = Memes.Rarities[meme.Rarity]
		local card = UIKit.new("Frame", { LayoutOrder = i, BackgroundColor3 = T.PanelLight, Parent = grid })
		UIKit.corner(card, 14)
		UIKit.stroke(card, 3, rarity.Color)
		if entry then
			found += 1
			UIKit.memeIcon(meme.Id, { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(8, 8), Parent = card })
			UIKit.label({ Text = meme.Name, Size = UDim2.new(1, -84, 0, 26), Position = UDim2.fromOffset(78, 8), Font = T.FontTitle,
				TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { Stroke = 2, MaxSize = 20 })
			UIKit.label({ Text = rarity.Name .. " · " .. (Memes.PersonalityNames[meme.Personality] or ""), Size = UDim2.new(1, -84, 0, 20),
				Position = UDim2.fromOffset(78, 36), Font = T.Font, TextColor3 = rarity.Color, TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card }, { MaxSize = 15 })
			UIKit.label({ Text = ("Pescados: %d · Récord: %s"):format(entry.Count, FishMath.FormatWeight(entry.Heaviest)),
				Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 78), Font = T.FontBody, TextColor3 = T.TextDim,
				TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { Stroke = false, MaxSize = 15 })
			UIKit.label({ Text = meme.Description, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 100), Font = T.FontBody,
				TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { Stroke = false, MaxSize = 14 })
		else
			UIKit.label({ Text = "❓", Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(8, 8), Parent = card }, { Stroke = false })
			UIKit.label({ Text = "???", Size = UDim2.new(1, -84, 0, 26), Position = UDim2.fromOffset(78, 8), Font = T.FontTitle,
				TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { Stroke = 2, MaxSize = 20 })
			UIKit.label({ Text = rarity.Name, Size = UDim2.new(1, -84, 0, 20), Position = UDim2.fromOffset(78, 36), Font = T.Font,
				TextColor3 = rarity.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { MaxSize = 15 })
			UIKit.label({ Text = ("Peso: %s – %s"):format(FishMath.FormatWeight(meme.WeightMin), FishMath.FormatWeight(meme.WeightMax)),
				Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 78), Font = T.FontBody, TextColor3 = T.TextDim,
				TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { Stroke = false, MaxSize = 15 })
		end
	end
	p.Content.Count.Text = ("Descubiertos: %d / %d · Charca del Noob"):format(found, #Memes.List)
end

-- ===== Infraestructura de paneles =====

local function makePanel(name: string, title: string, color: Color3, cell: Vector2, render: () -> (), extra: ((Frame) -> ())?)
	local frame, content, close = UIKit.panel(gui, name, title, Vector2.new(760, 520), color)
	UIKit.label({ Name = "Count", Text = "", Size = UDim2.new(1, -200, 0, 30), Position = UDim2.fromOffset(0, 0), Font = T.Font,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = content }, { MaxSize = 22 })
	local grid = scroller(content, cell, 40)
	grid.Name = "Grid"
	if extra then
		extra(content)
	end
	close.Activated:Connect(function()
		Panels.Close()
	end)
	panels[name] = { Frame = frame, Content = content, Render = render, Signature = "" }
end

-- Resumen de lo que muestra cada panel; si no cambia, no hace falta redibujarlo.
function Panels.Signature(name: string): string
	local data = State.Data
	if not data then
		return ""
	end
	local ids = {}
	for id in pairs(data.Catches) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local catches = table.concat(ids, ",")
	local plot = table.concat(data.Plot, ",")
	if name == "Backpack" then
		return catches .. "|" .. plot
	elseif name == "Plot" then
		return plot .. "|" .. tostring(Players.LocalPlayer:GetAttribute("PlotBank"))
	elseif name == "Shop" then
		local rods = {}
		for id in pairs(data.Rods) do
			table.insert(rods, id)
		end
		table.sort(rods)
		-- las monedas solo importan para saber si puedes pagar cada cosa
		local affordable = {}
		for _, rod in ipairs(Rods.List) do
			table.insert(affordable, if data.MemeCoin >= rod.Price then "1" else "0")
		end
		table.insert(affordable, if data.MemeCoin >= Rods.Items.SedalReforzado.Price then "1" else "0")
		return table.concat(rods, ",") .. "|" .. data.EquippedRod .. "|" .. tostring(data.Items.SedalReforzado) .. "|" .. table.concat(affordable)
	elseif name == "Bestiary" then
		local parts = {}
		for id, entry in pairs(data.Discovered) do
			table.insert(parts, id .. ":" .. entry.Count)
		end
		table.sort(parts)
		return table.concat(parts, ",")
	end
	return ""
end

function Panels.Open(name: string)
	if State.Busy and name ~= "Bestiary" then
		HUD.Toast("🎣 Termina de pescar primero", "Warning")
		return
	end
	if openName == name then
		Panels.Close()
		return
	end
	Panels.Close()
	local p = panels[name]
	if not p then
		return
	end
	openName = name
	p.Signature = Panels.Signature(name)
	p.Render()
	p.Frame.Visible = true
	UIKit.pop(p.Frame, 0.85)
end

function Panels.Close()
	if openName and panels[openName] then
		local frame = panels[openName].Frame
		frame.Visible = false
		local options = frame:FindFirstChild("Options")
		if options then
			options:Destroy()
		end
	end
	openName = nil
end

function Panels.Init()
	gui = UIKit.new("ScreenGui", { Name = "PescaPanels", ResetOnSpawn = false, DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })

	makePanel("Backpack", "🎒 MOCHILA", T.Primary, Vector2.new(140, 150), renderBackpack, function(content)
		local sellAll = UIKit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(190, 36),
			Parent = content }, { Color = T.Success, Text = "💰 Vender comunes–raros", TextSize = 18 })
		sellAll.Activated:Connect(function()
			local r = call("SellAll", nil)
			if r.ok then
				HUD.Toast(("💰 Vendidos %d memes: +%s MemeCoins"):format(r.Count or 0, Util.formatNumber(r.Earned or 0)), "Success")
			end
		end)
	end)
	makePanel("Plot", "🏠 TU PARCELA", T.Accent, Vector2.new(140, 150), renderPlot, function(content)
		local home = UIKit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(190, 36),
			Parent = content }, { Color = T.Success, Text = "🏠 Ir a mi parcela", TextSize = 18 })
		home.Activated:Connect(function()
			if call("GoHome", nil).ok then
				Panels.Close()
			end
		end)
	end)
	makePanel("Shop", "🛒 CAÑAS & CEBOS", T.Secondary, Vector2.new(220, 170), renderShop)
	makePanel("Bestiary", "📖 BESTIARIO", T.Success, Vector2.new(330, 140), renderBestiary)

	HUD.ButtonPressed:Connect(Panels.Open)
	Players.LocalPlayer:GetAttributeChangedSignal("PlotBank"):Connect(function()
		if openName == "Plot" then
			panels.Plot.Render()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			Panels.Open("Shop")
		end
	end)

	State.Changed:Connect(function()
		-- solo se redibuja si cambió algo que el panel muestra (no cada tick de ingresos)
		local p = openName and panels[openName]
		if p then
			local signature = Panels.Signature(openName :: string)
			if signature ~= p.Signature then
				p.Signature = signature
				p.Render()
			elseif openName == "Shop" and State.Data then
				p.Content.Count.Text = ("Tienes 🪙 %s"):format(Util.formatNumber(State.Data.MemeCoin))
			end
		end
	end)
end

return Panels

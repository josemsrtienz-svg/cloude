--[[
	PescaDeMemes • Panels (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > Panels

	Paneles modales: 🐠 Acuario (mochila) · 🏠 Parcela · 🛒 Tienda · 📖 Índice.
	Los memes y el equipo se ven como FIGURAS 3D (UIKit.memeIcon / UIKit.modelIcon), no como emojis.
	Se abren con los botones del HUD o con el ProximityPrompt de la tienda.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local FishMath = require(Root.Shared.FishMath)
local Util = require(Root.Shared.Util)
local Inventory = require(Root.Shared.Inventory)
local Boosts = require(Root.Config.Boosts)
local Monetization = require(Root.Config.Monetization)
local GearModels = require(Root.Shared.GearModels)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local HUD = require(Controllers.HUD)

local T = UIKit.Theme
local RGB = Color3.fromRGB
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
	UIKit.memeIcon(catch.MemeId, { Size = UDim2.fromOffset(78, 74), Position = UDim2.new(0.5, -39, 0, 6), Parent = tile }, { Golden = catch.Golden })
	UIKit.label({ Text = meme and meme.Name or "?", Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 82), Font = T.Font,
		TextColor3 = if catch.Golden then T.Coin else T.Text, Parent = tile }, { MaxSize = 18 })
	UIKit.label({ Text = FishMath.FormatWeight(catch.Weight) .. (if catch.Impossible then " 🏆" else ""), Size = UDim2.new(1, -8, 0, 18),
		Position = UDim2.fromOffset(4, 104), Font = T.FontBody, TextColor3 = T.TextDim, Parent = tile }, { Stroke = false, MaxSize = 15 })
	UIKit.label({ Text = "🪙 " .. Util.formatShort(catch.Value), Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 124),
		Font = T.Font, TextColor3 = T.Coin, Parent = tile }, { MaxSize = 17 })
	return tile
end

-- Menú de opciones al tocar una captura de la mochila.
local function catchOptions(catch: any)
	local panel = panels.Aquarium
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
	opt(("💰 Vender por %s"):format(Util.formatShort(catch.Value)), T.Primary, 1, function()
		local r = call("SellCatch", nil, catch.Id)
		if r.ok then
			HUD.Toast(("💰 +%s MemeCoins"):format(Util.formatShort(r.Earned or 0)), "Success")
			box:Destroy()
		end
	end)
	opt("🏠 Al entrar en tu parcela se coloca solo", T.PanelLight, 2, function()
		box:Destroy()
	end)
	opt("Cancelar", T.PanelLight, 3, function()
		box:Destroy()
	end)
end

-- ===== Filtros (rarezas) =====
-- 🎣 El anzuelo IGNORA: esas rarezas no se enganchan (pasas a través).
-- 💰 Se VENDEN SOLAS al subir: no ocupan sitio en la mochila (los dorados nunca se venden solos).
function Panels.OpenFilters()
	local data = State.Data
	if not data then
		return
	end
	if openName ~= "Aquarium" then
		Panels.Open("Aquarium")
	end
	if openName ~= "Aquarium" then
		return -- no se pudo abrir (estás pescando)
	end
	local panel = panels.Aquarium
	local old = panel.Frame:FindFirstChild("Options")
	if old then
		old:Destroy()
	end
	local current = { CatchSkip = table.clone(data.Settings and data.Settings.CatchSkip or {}), AutoSell = table.clone(data.Settings and data.Settings.AutoSell or {}) }
	local box = UIKit.new("Frame", { Name = "Options", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(700, 380), BackgroundColor3 = T.PanelDark, ZIndex = 10, Parent = panel.Frame })
	UIKit.corner(box, 16)
	UIKit.stroke(box, 4, T.Primary)
	UIKit.label({ Text = "⚙️ FILTROS DE PESCA", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 8), Font = T.FontTitle,
		TextColor3 = T.Primary, ZIndex = 11, Parent = box }, { Stroke = 3, MaxSize = 30 })
	local function section(key: string, title: string, y: number, onColor: Color3)
		UIKit.label({ Text = title, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, y), Font = T.Font, ZIndex = 11,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = box }, { MaxSize = 20 })
		local row = UIKit.new("Frame", { Size = UDim2.new(1, -20, 0, 84), Position = UDim2.fromOffset(10, y + 30), BackgroundTransparency = 1, ZIndex = 11, Parent = box })
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 38), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i, id in ipairs(Memes.RarityOrder) do
			local rarity = Memes.Rarities[id]
			if rarity.Odds > 0 then
				local chip = UIKit.button({ LayoutOrder = i, ZIndex = 12, Parent = row }, { Text = rarity.Name, TextSize = 16, Radius = 10 })
				local function paint()
					local on = current[key][id] == true
					chip.BackgroundColor3 = if on then onColor else T.PanelLight
					local label = chip:FindFirstChild("Label") :: TextLabel?
					if label then
						label.Text = (if on then "✔ " else "") .. rarity.Name
						label.TextColor3 = if on then T.Text else rarity.Color
					end
				end
				paint()
				chip.Activated:Connect(function()
					current[key][id] = if current[key][id] then nil else true
					paint()
				end)
			end
		end
	end
	section("CatchSkip", "🎣 Mi anzuelo IGNORA estas rarezas (no se enganchan):", 50, T.Danger)
	section("AutoSell", "💰 Se VENDEN SOLAS al pescarlas (los dorados nunca):", 170, T.Success)
	local save = UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 90, 1, -12), Size = UDim2.fromOffset(170, 50), ZIndex = 12,
		Parent = box }, { Color = T.Success, Text = "💾 Guardar", TextSize = 24 })
	local cancel = UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -90, 1, -12), Size = UDim2.fromOffset(170, 50), ZIndex = 12,
		Parent = box }, { Color = T.PanelLight, Text = "Cancelar", TextSize = 24 })
	save.Activated:Connect(function()
		if call("SetFilters", "⚙️ Filtros guardados", current.CatchSkip, current.AutoSell).ok then
			box:Destroy()
		end
	end)
	cancel.Activated:Connect(function()
		box:Destroy()
	end)
end

-- ===== Mochila-acuario =====
local function renderAquarium()
	local p = panels.Aquarium
	local grid = p.Content:FindFirstChild("Grid") :: ScrollingFrame
	clear(grid)
	local data = State.Data
	if not data then
		return
	end
	local list = Inventory.Aquarium(data)
	p.Content.Count.Text = ("%d memes · %d / %d kg"):format(#list, Inventory.Used(data), Inventory.Capacity(data))
	if #list == 0 then
		UIKit.label({ Text = "Tu acuario está vacío. ¡Ve a pescar a tu muelle! 🎣", Size = UDim2.fromOffset(460, 40), Font = T.Font, Parent = grid }, { MaxSize = 24 })
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
			UIKit.label({ Text = "Hueco " .. slot, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, -8, 0, 14),
				Font = T.FontBody, TextColor3 = T.TextDim, Parent = tile }, { Stroke = false, MaxSize = 12 })
			tile.Activated:Connect(function()
				HUD.Toast("Para quitarlo, ve a tu parcela y pulsa \"Recoger\" junto a él", "Info")
			end)
		else
			local empty = UIKit.new("Frame", { LayoutOrder = slot, BackgroundColor3 = T.PanelDark, Parent = grid })
			UIKit.corner(empty, 12)
			UIKit.stroke(empty, 3, T.PanelLight)
			UIKit.label({ Text = ("Hueco %d\nlibre"):format(slot), Size = UDim2.fromScale(1, 1), Font = T.Font, TextColor3 = T.TextDim, Parent = empty }, { MaxSize = 20 })
		end
	end
	local bank = Players.LocalPlayer:GetAttribute("PlotBank")
	p.Content.Count.Text = ("🪙 %s · Cobrador: 🪙 %s"):format(Inventory.FormatIncome(Inventory.PlotIncomePerMinute(data, GameConfig.PlotIncomeRate)),
		Util.formatShort(if type(bank) == "number" then bank else data.PlotBank or 0))
end

-- ===== Tienda =====
-- Diseño: pestañas a la izquierda · cartas con FOTO 3D en el centro · vista previa grande que gira a la
-- derecha con barras de estadísticas y el botón de acción (comprar / equipar / reparar).

-- Dos modos: la tienda del HUD (botón Tienda) solo vende lo básico; la GRAN TIENDA física (ir hasta ella)
-- tiene además boosts, pases de Robux y muelles. Full = solo en la tienda física.
local SHOP_TABS = {
	{ Id = "Rods", Text = "🎣 Cañas", Color = RGB(255, 170, 40) },
	{ Id = "Packs", Text = "🐠 Mochilas", Color = RGB(70, 170, 255) },
	{ Id = "Items", Text = "🧵 Objetos", Color = RGB(255, 90, 150) },
	{ Id = "Boosts", Text = "⚡ Boosts", Color = RGB(90, 220, 90), Full = true },
	{ Id = "Robux", Text = "💎 Robux", Color = RGB(120, 60, 200), Full = true },
	{ Id = "Skins", Text = "✨ Muelles", Color = RGB(185, 90, 255), Full = true },
}
local shopFull = false
local SHOP_TABS_BY_ID: { [string]: any } = {}
for _, tab in ipairs(SHOP_TABS) do
	SHOP_TABS_BY_ID[tab.Id] = tab
end
-- Teaser de la próxima actualización: skins de parcela/muelle con suerte y multiplicador
local SKIN_PREVIEWS = {
	{ Name = "Muelle Pirata", Desc = "Barco hundido, cofres y banderas. +10 % suerte.", Color = RGB(150, 104, 66) },
	{ Name = "Muelle Neón", Desc = "Luces de colores de noche. ×1.25 dinero de la parcela.", Color = RGB(70, 230, 255) },
	{ Name = "Muelle Dorado", Desc = "Todo de oro. +25 % suerte y ×1.5 dinero. Evento.", Color = RGB(255, 200, 50) },
}
local shopTab = "Rods"
local shopSelected: { [string]: number } = { Rods = 1, Packs = 1, Items = 1, Boosts = 1, Robux = 1, Skins = 1 }

local function passModel(key: string): Model
	if key == "VIP" then
		return GearModels.Crown()
	elseif key == "ExtraHook" then
		return GearModels.Rod(Rods.List[4])
	end
	return GearModels.Potion(RGB(80, 200, 255))
end

type ShopEntry = {
	Name: string,
	Model: () -> Model,
	Color: Color3,
	Desc: string,
	Price: string,
	Tag: string?, -- "EQUIPADA", "ROTA", "TUYA"…
	Angle: number?, -- giro de la foto 3D (por defecto según la pestaña)
	Extra: { Text: string, Run: () -> () }?, -- segundo botón (p. ej. Equipar un consumible)
	TagColor: Color3?,
	Stats: { { Name: string, Value: number, Text: string } }?,
	Action: { Text: string, Color: Color3, Run: (() -> ())? }?,
}

local function shopEntries(data: any): { ShopEntry }
	local function can(price: number): Color3
		return if data.MemeCoin >= price then T.Success else T.PanelDark
	end
	local list: { ShopEntry } = {}
	if shopTab == "Rods" then
		local maxRod = Rods.List[#Rods.List]
		for _, rod in ipairs(Rods.List) do
			local owned = data.Rods[rod.Id] == true
			local equipped = data.EquippedRod == rod.Id
			local broken = data.BrokenRods and data.BrokenRods[rod.Id] == true
			local action, tag, tagColor
			if broken then
				tag, tagColor = "💥 ROTA", T.Danger
				action = { Text = "🔧 Reparar 🪙 " .. Util.formatShort(rod.RepairCost), Color = can(rod.RepairCost), Run = function()
					call("RepairRod", "🔧 " .. rod.Name .. " reparada y equipada", rod.Id)
				end }
			elseif equipped then
				tag, tagColor = "✅ EQUIPADA", T.Success
				action = { Text = "✅ Equipada", Color = T.PanelDark }
			elseif owned then
				tag, tagColor = "TUYA", T.Accent
				action = { Text = "Equipar", Color = T.Accent, Run = function()
					call("EquipRod", "🎣 " .. rod.Name .. " equipada", rod.Id)
				end }
			else
				action = { Text = "Comprar 🪙 " .. Util.formatShort(rod.Price), Color = can(rod.Price), Run = function()
					call("BuyRod", "🎉 ¡Has comprado la " .. rod.Name .. "!", rod.Id)
				end }
			end
			table.insert(list, {
				Name = rod.Name, Color = rod.Color, Desc = rod.Description .. (if rod.RepairCost == 0 then " Irrompible." else ""),
				Model = function()
					return GearModels.Rod(rod, broken)
				end,
				Price = if owned then "" else "🪙 " .. Util.formatShort(rod.Price), Tag = tag, TagColor = tagColor,
				Stats = {
					{ Name = "Capacidad", Value = math.sqrt(rod.Capacity / maxRod.Capacity), Text = FishMath.FormatWeight(rod.Capacity) },
					{ Name = "Profundidad", Value = rod.MaxDepth / maxRod.MaxDepth, Text = rod.MaxDepth .. " m" },
					{ Name = "Anzuelos", Value = rod.Hooks / maxRod.Hooks, Text = tostring(rod.Hooks) },
					{ Name = "Suerte", Value = (rod.Luck - 0.9) / (maxRod.Luck - 0.9), Text = "×" .. rod.Luck },
				},
				Action = action,
			})
		end
	elseif shopTab == "Packs" then
		local maxCap = Rods.Aquariums[#Rods.Aquariums].Capacity
		for _, aq in ipairs(Rods.Aquariums) do
			local action, tag, tagColor
			if aq.Tier == data.AquariumTier then
				tag, tagColor = "✅ LA LLEVAS", T.Success
				action = { Text = "✅ La llevas", Color = T.PanelDark }
			elseif aq.Tier < data.AquariumTier then
				tag, tagColor = "SUPERADA", T.PanelDark
				action = { Text = "Superada", Color = T.PanelDark }
			elseif aq.Tier == data.AquariumTier + 1 then
				action = { Text = "Comprar 🪙 " .. Util.formatShort(aq.Price), Color = can(aq.Price), Run = function()
					call("BuyAquarium", "🐠 ¡Nueva mochila: " .. aq.Name .. "!", aq.Tier)
				end }
			else
				tag, tagColor = "🔒", T.PanelDark
				action = { Text = "🔒 Compra la anterior", Color = T.PanelDark }
			end
			table.insert(list, {
				Name = aq.Name, Color = aq.Color, Desc = "Mochila-acuario a la espalda: más kg = más memes por ronda de pesca.",
				Model = function()
					return GearModels.Tank(aq, { "NoobFeliz", "PerroBonk", "Stonks" })
				end,
				Price = if aq.Tier > data.AquariumTier then "🪙 " .. Util.formatShort(aq.Price) else "", Tag = tag, TagColor = tagColor,
				Stats = { { Name = "Capacidad", Value = math.sqrt(aq.Capacity / maxCap), Text = aq.Capacity .. " kg" } },
				Action = action,
			})
		end
	elseif shopTab == "Items" then
		-- objetos: comprar y EQUIPAR (huecos limitados: elige qué te llevas)
		local itemModels = { SedalReforzado = GearModels.Spool, Linterna = GearModels.Flashlight, Iman = GearModels.Magnet, RedDorada = GearModels.Net }
		local slotsAttr = Players.LocalPlayer:GetAttribute("ItemSlots") -- lo publica el servidor (BoostService)
		local slots = if type(slotsAttr) == "number" then slotsAttr else Rods.BaseItemSlots
		for _, id in ipairs(Rods.ItemOrder) do
			local item = Rods.Items[id]
			local count = data.Items[id] or 0
			local equipped = table.find(data.EquippedItems or {}, id) ~= nil
			local owned = count > 0
			local gear = item.Kind == "Gear"
			local action
			if gear and owned then
				action = if equipped
					then { Text = "Quitar", Color = T.PanelLight, Run = function()
						call("EquipItem", item.Emoji .. " " .. item.Name .. " guardado", id, false)
					end }
					else { Text = "Equipar", Color = T.Accent, Run = function()
						call("EquipItem", item.Emoji .. " " .. item.Name .. " equipado", id, true)
					end }
			else
				action = { Text = "Comprar 🪙 " .. Util.formatShort(item.Price), Color = can(item.Price), Run = function()
					call("BuyItem", item.Emoji .. " +1 " .. item.Name, id)
				end }
			end
			local tag = if equipped then "✅ EQUIPADO" elseif gear and owned then "TUYO" elseif count > 0 then ("x%d"):format(count) else nil
			table.insert(list, {
				Name = item.Name, Color = item.Color, Model = itemModels[id] or GearModels.Spool,
				Desc = item.Description .. ("  ·  Huecos de objetos: %d/%d"):format(#(data.EquippedItems or {}), slots),
				Price = if gear and owned then "" else "🪙 " .. Util.formatShort(item.Price), Tag = tag, TagColor = if equipped then T.Success else T.Secondary,
				Stats = if gear then nil else { { Name = "Tienes", Value = math.min(1, count / 10), Text = tostring(count) } },
				Action = action,
				-- los consumibles también se equipan/quitan (además de comprar más)
				Extra = if not gear and (owned or equipped) then (if equipped
					then { Text = "Quitar", Run = function()
						call("EquipItem", item.Emoji .. " " .. item.Name .. " guardado", id, false)
					end }
					else { Text = "Equipar", Run = function()
						call("EquipItem", item.Emoji .. " " .. item.Name .. " equipado", id, true)
					end }) else nil,
			})
		end
	elseif shopTab == "Boosts" then
		local available, free = Boosts.FreeAvailable(data)
		if available == true then
			table.insert(list, {
				Name = "🎁 " .. free.Name .. " GRATIS", Color = free.Color, Desc = "¡Tu regalo! También lo recoges en el pedestal del regalo. " .. free.Description,
				Model = function()
					return GearModels.Potion(free.Color)
				end,
				Price = "GRATIS", Tag = "🎁", TagColor = T.Success,
				Stats = { { Name = "Duración", Value = free.Duration / 600, Text = ("%d min"):format(free.Duration // 60) } },
				Action = { Text = "🎁 Recoger GRATIS", Color = T.Success, Run = function()
					local r = call("ClaimFreeBoost", nil)
					if r.ok then
						HUD.Toast(("🎁 ¡%s activado!"):format(r.Name or "Boost"), "Success")
						UIKit.playSound("Coins")
					end
				end },
			})
		end
		local now = workspace:GetServerTimeNow()
		for _, id in ipairs(Boosts.Order) do
			local boost = Boosts.List[id]
			local untilTime = data.Boosts and data.Boosts[id]
			local isActive = type(untilTime) == "number" and untilTime > now
			table.insert(list, {
				Name = boost.Name, Color = boost.Color, Desc = boost.Description .. " Si ya lo tienes, suma tiempo.",
				Model = function()
					return GearModels.Potion(boost.Color)
				end,
				Price = "🪙 " .. Util.formatShort(boost.Price), Tag = if isActive then "ACTIVO" else nil, TagColor = T.Success,
				Stats = { { Name = "Duración", Value = boost.Duration / 600, Text = ("%d min"):format(boost.Duration // 60) },
					{ Name = "Efecto", Value = (boost.Multiplier - 1), Text = "×" .. boost.Multiplier } },
				Action = { Text = "Comprar 🪙 " .. Util.formatShort(boost.Price), Color = can(boost.Price), Run = function()
					call("BuyBoost", "⚡ ¡" .. boost.Name .. " activado!", boost.Id)
				end },
			})
		end
	elseif shopTab == "Robux" then
		local player = Players.LocalPlayer
		for _, pass in ipairs(Monetization.GamePasses) do
			local owned = player:GetAttribute("Pass_" .. pass.Key) == true
			local action
			if owned then
				action = { Text = "✅ Ya es tuyo", Color = T.PanelDark }
			elseif pass.Id > 0 then
				action = { Text = "💎 R$ " .. pass.Robux, Color = RGB(120, 60, 200), Run = function()
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				end }
			else
				action = { Text = "🔒 Próximamente", Color = T.PanelDark }
			end
			table.insert(list, {
				Name = pass.Name, Color = pass.Color, Desc = pass.Description .. " Pase para siempre (Game Pass).",
				Model = function()
					return passModel(pass.Key)
				end,
				Angle = if pass.Key == "ExtraHook" then 80 else 25,
				Price = if owned then "" else "R$ " .. pass.Robux, Tag = if owned then "✅ TUYO" else nil, TagColor = T.Success,
				Action = action,
			})
		end
	else
		for _, skin in ipairs(SKIN_PREVIEWS) do
			table.insert(list, {
				Name = skin.Name, Color = skin.Color, Desc = skin.Desc, Model = GearModels.House, Price = "",
				Tag = "PRONTO", TagColor = T.Secondary, Action = { Text = "🔒 Próximamente", Color = T.PanelDark },
			})
		end
	end
	return list
end

local function statBar(parent: Instance, order: number, stat: { Name: string, Value: number, Text: string }, color: Color3)
	local row = UIKit.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = parent })
	UIKit.label({ Text = stat.Name, Size = UDim2.new(0.38, 0, 1, 0), Font = T.Font, TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row }, { MaxSize = 16 })
	local bar = UIKit.new("Frame", { Position = UDim2.new(0.38, 0, 0.5, -7), Size = UDim2.new(0.62, 0, 0, 14), BackgroundColor3 = T.PanelDark, Parent = row })
	UIKit.corner(bar, 7)
	UIKit.stroke(bar, 2)
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = bar })
	UIKit.corner(fill, 7)
	UIKit.tween(fill, 0.4, { Size = UDim2.fromScale(math.clamp(stat.Value, 0.05, 1), 1) })
	UIKit.label({ Text = stat.Text, Size = UDim2.fromScale(1, 1), Font = T.FontTitle, ZIndex = 3, Parent = bar }, { Stroke = 2, MaxSize = 13 })
end

local function renderShop()
	local p = panels.Shop
	local data = State.Data
	local body = p.Content:FindFirstChild("Body") :: Frame
	clear(body)
	if not data then
		return
	end
	p.Content.Count.Text = ("Tienes 🪙 %s"):format(Util.formatShort(data.MemeCoin))

	-- pestañas
	local tabs = UIKit.new("Frame", { Name = "Tabs", Size = UDim2.new(0, 150, 1, 0), BackgroundTransparency = 1, Parent = body })
	UIKit.list(tabs, Enum.FillDirection.Vertical, 8)
	if not shopFull and SHOP_TABS_BY_ID[shopTab] and SHOP_TABS_BY_ID[shopTab].Full then
		shopTab = "Rods"
	end
	local title = p.Frame:FindFirstChild("Title", true) :: TextLabel?
	if title then
		title.Text = if shopFull then "🛒 GRAN TIENDA" else "🛒 TIENDA"
	end
	for i, tab in ipairs(SHOP_TABS) do
		if tab.Full and not shopFull then
			continue
		end
		local active = tab.Id == shopTab
		local b = UIKit.button({ LayoutOrder = i, Size = UDim2.new(1, -6, 0, 52), Parent = tabs },
			{ Color = if active then tab.Color else T.PanelLight, Text = tab.Text, TextSize = 22, StrokeThickness = if active then 4 else 3 })
		b.Activated:Connect(function()
			shopTab = tab.Id
			renderShop()
		end)
	end

	if not shopFull then
		-- la tienda del HUD invita a ir a la física, que es donde está todo
		UIKit.label({ LayoutOrder = 99, Text = "⚡ Boosts, 💎 Robux y ✨ muelles: ve a la GRAN TIENDA (entrada del mapa)",
			Size = UDim2.new(1, -6, 0, 70), Font = T.Font, TextColor3 = T.Coin, Parent = tabs }, { MaxSize = 15 })
	end

	local entries = shopEntries(data)
	local selected = math.clamp(shopSelected[shopTab] or 1, 1, math.max(1, #entries))

	-- cartas
	local grid = UIKit.new("ScrollingFrame", { Name = "Cards", Position = UDim2.fromOffset(160, 0), Size = UDim2.new(1, -460, 1, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = body })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(130, 168), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid })
	UIKit.padding(grid, 4)
	for i, e in ipairs(entries) do
		local isSel = i == selected
		local card = UIKit.new("TextButton", { LayoutOrder = i, Text = "", AutoButtonColor = false,
			BackgroundColor3 = if isSel then T.Panel else T.PanelLight, Parent = grid })
		UIKit.corner(card, 12)
		UIKit.stroke(card, if isSel then 4 else 3, if isSel then T.Primary else e.Color)
		UIKit.modelIcon(e.Model(), e.Color, { Size = UDim2.new(1, -12, 0, 96), Position = UDim2.fromOffset(6, 6), Parent = card },
			{ Angle = e.Angle or (if shopTab == "Rods" then 80 elseif shopTab == "Packs" then 160 else 25), Zoom = 1.25 })
		UIKit.label({ Text = e.Name, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 106), Font = T.FontTitle,
			Parent = card }, { Stroke = 2, MaxSize = 16 })
		UIKit.label({ Text = if e.Price ~= "" then e.Price else (e.Tag or ""), Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 132),
			Font = T.FontTitle, TextColor3 = if e.Price ~= "" then T.Coin else (e.TagColor or T.Text), Parent = card }, { Stroke = 2, MaxSize = 17 })
		if e.Tag and e.Price ~= "" then
			local ribbon = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(70, 20),
				BackgroundColor3 = e.TagColor or T.Secondary, ZIndex = 4, Parent = card })
			UIKit.corner(ribbon, 6)
			UIKit.label({ Text = e.Tag, Size = UDim2.fromScale(1, 1), Font = T.FontTitle, ZIndex = 5, Parent = ribbon }, { Stroke = 2, MaxSize = 12 })
		end
		card.Activated:Connect(function()
			shopSelected[shopTab] = i
			UIKit.playSound("Click")
			renderShop()
		end)
	end

	-- vista previa
	local e = entries[selected]
	if not e then
		return
	end
	local preview = UIKit.new("Frame", { Name = "Preview", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 290, 1, 0), BackgroundColor3 = T.PanelDark, Parent = body })
	UIKit.corner(preview, 16)
	UIKit.stroke(preview, 4, e.Color)
	UIKit.modelIcon(e.Model(), e.Color, { Size = UDim2.new(1, -20, 0, 170), Position = UDim2.fromOffset(10, 10), Parent = preview },
		{ Spin = 0.9, Angle = if shopTab == "Packs" then 160 else 60, Zoom = 1.2 })
	UIKit.label({ Text = e.Name, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 186), Font = T.FontTitle,
		TextColor3 = T.Primary, Parent = preview }, { Stroke = 3, MaxSize = 28 })
	UIKit.label({ Text = e.Desc, Size = UDim2.new(1, -20, 0, 42), Position = UDim2.fromOffset(10, 220), Font = T.FontBody,
		TextColor3 = T.TextDim, Parent = preview }, { Stroke = false, MaxSize = 14 })
	local stats = UIKit.new("Frame", { Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 268), BackgroundTransparency = 1, Parent = preview })
	UIKit.list(stats, Enum.FillDirection.Vertical, 4)
	for i, stat in ipairs(e.Stats or {}) do
		statBar(stats, i, stat, e.Color)
	end
	local action = e.Action
	local extra = e.Extra
	if extra then
		local btn2 = UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -68), Size = UDim2.new(1, -20, 0, 44),
			Parent = preview }, { Color = T.Accent, Text = extra.Text, TextSize = 20 })
		btn2.Activated:Connect(extra.Run)
	end
	if action then
		local btn = UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 52),
			Parent = preview }, { Color = action.Color, Text = action.Text, TextSize = 22 })
		local run = action.Run
		if run then
			btn.Activated:Connect(run)
		end
	end
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
			UIKit.memeIcon(meme.Id, { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(8, 8), Parent = card }, { Silhouette = true })
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

local function makePanel(name: string, title: string, color: Color3, cell: Vector2?, render: () -> (), extra: ((Frame) -> ())?, size: Vector2?)
	local frame, content, close = UIKit.panel(gui, name, title, size or Vector2.new(760, 520), color)
	UIKit.label({ Name = "Count", Text = "", Size = UDim2.new(1, -200, 0, 30), Position = UDim2.fromOffset(0, 0), Font = T.Font,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = content }, { MaxSize = 22 })
	if cell then
		local grid = scroller(content, cell, 40)
		grid.Name = "Grid"
	else
		UIKit.new("Frame", { Name = "Body", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, Parent = content })
	end
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
	if name == "Aquarium" then
		return catches .. "|" .. plot .. "|" .. tostring(data.AquariumTier)
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
		for _, rod in ipairs(Rods.List) do
			table.insert(affordable, if data.MemeCoin >= rod.RepairCost then "1" else "0")
		end
		for _, aq in ipairs(Rods.Aquariums) do
			table.insert(affordable, if data.MemeCoin >= aq.Price then "1" else "0")
		end
		for _, id in ipairs(Rods.ItemOrder) do
			table.insert(affordable, (if data.MemeCoin >= Rods.Items[id].Price then "1" else "0") .. tostring(data.Items[id]))
		end
		table.insert(affordable, table.concat(data.EquippedItems or {}, "+"))
		local broken = {}
		for id in pairs(data.BrokenRods or {}) do
			table.insert(broken, id)
		end
		table.sort(broken)
		for _, id in ipairs(Boosts.Order) do
			table.insert(affordable, if data.MemeCoin >= Boosts.List[id].Price then "1" else "0")
			local untilTime = data.Boosts and data.Boosts[id]
			table.insert(affordable, if type(untilTime) == "number" and untilTime > workspace:GetServerTimeNow() then "A" else "-")
		end
		return table.concat(rods, ",") .. "|" .. data.EquippedRod .. "|" .. tostring(data.Items.SedalReforzado) .. "|" .. table.concat(affordable)
			.. "|" .. table.concat(broken, ",") .. "|" .. tostring(data.AquariumTier) .. "|" .. tostring(data.FreeRound) .. "|" .. tostring(workspace:GetAttribute("FreeRound"))
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

-- full = GRAN TIENDA física (todas las pestañas); tab = pestaña inicial opcional.
function Panels.OpenShop(full: boolean, tab: string?)
	shopFull = full
	if tab then
		shopTab = tab
	end
	if openName == "Shop" then
		panels.Shop.Render() -- ya abierta: cambia de modo sin cerrarse
		return
	end
	Panels.Open("Shop")
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

	makePanel("Aquarium", "🐠 TU ACUARIO", RGB(255, 140, 40), Vector2.new(140, 150), renderAquarium, function(content)
		local sellAll = UIKit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(190, 36),
			Parent = content }, { Color = T.Success, Text = "💰 Vender comunes–raros", TextSize = 18 })
		local filters = UIKit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -200, 0, -2), Size = UDim2.fromOffset(130, 36),
			Parent = content }, { Color = T.Primary, Text = "⚙️ Filtros", TextSize = 18 })
		filters.Activated:Connect(Panels.OpenFilters)
		sellAll.Activated:Connect(function()
			local r = call("SellAll", nil)
			if r.ok then
				HUD.Toast(("💰 Vendidos %d memes: +%s MemeCoins"):format(r.Count or 0, Util.formatShort(r.Earned or 0)), "Success")
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
	makePanel("Shop", "🛒 TIENDA", RGB(60, 200, 80), nil, renderShop, nil, Vector2.new(900, 560))
	makePanel("Bestiary", "📖 ÍNDICE", RGB(40, 170, 255), Vector2.new(330, 140), renderBestiary)

	require(Controllers.FishingController).FiltersRequested:Connect(Panels.OpenFilters)
	HUD.ButtonPressed:Connect(function(name)
		if name == "Shop" then
			Panels.OpenShop(false)
		else
			Panels.Open(name)
		end
	end)
	Players.LocalPlayer.AttributeChanged:Connect(function(attr)
		if openName == "Shop" and string.sub(attr, 1, 5) == "Pass_" then
			panels.Shop.Render()
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("PlotBank"):Connect(function()
		if openName == "Plot" then
			panels.Plot.Render()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			Panels.OpenShop(true)
		elseif prompt.Name == "VipPrompt" then
			Panels.OpenShop(true, "Robux")
		elseif prompt.Name == "GiftPrompt" then
			local r = call("ClaimFreeBoost", nil)
			if r.ok then
				HUD.Toast(("🎁 ¡%s activado!"):format(r.Name or "Boost"), "Success")
				UIKit.playSound("Coins")
			end
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
				p.Content.Count.Text = ("Tienes 🪙 %s"):format(Util.formatShort(State.Data.MemeCoin))
			end
		end
	end)
end

return Panels

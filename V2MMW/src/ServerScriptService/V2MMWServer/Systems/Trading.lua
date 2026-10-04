--[[
	V2MMW • Trading (ModuleScript)
	ServerScriptService > V2MMWServer > Systems > Trading

	Intercambio de memes entre dos jugadores del mismo servidor.
	Flujo: A envía solicitud → B acepta → ambos ponen su oferta → ambos ACEPTAN → el servidor
	revalida que los dos siguen teniendo lo que ofrecen y hace el cambio de una sola vez (atómico).
	  - Cualquier cambio de oferta quita la aceptación de los dos.
	  - Si alguien cancela, sale del juego o entra a una partida, el trade se cancela.
	  - Al completarse se guardan los dos perfiles enseguida.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("V2MMW")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)
local Remotes = require(Shared.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Inventory = require(script.Parent.Inventory)

local Trading = {}

type Session = {
	Id: number,
	A: Player,
	B: Player,
	Offers: { [Player]: { [string]: number } },
	Accepted: { [Player]: boolean },
	Busy: boolean,
}

local sessions: { [Player]: Session } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invites[target][from] = expira (os.clock)
local nextId = 0
local lastCall: { [Player]: number } = {}

local function throttled(player: Player, cd: number): boolean
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < cd then
		return true
	end
	lastCall[player] = now
	return false
end

local function other(session: Session, player: Player): Player
	return if session.A == player then session.B else session.A
end

local function canTrade(player: Player): (boolean, string?)
	if not PlayerData.IsLoaded(player) then
		return false, "Cargando datos..."
	end
	local state = player:GetAttribute("GameState")
	if state == "Match" or state == "Station" then
		return false, "No se puede tradear dentro de una cabina o partida"
	end
	return true
end

local function pushState(session: Session)
	for _, plr in ipairs({ session.A, session.B }) do
		local them = other(session, plr)
		Remotes.Get("TradeState"):FireClient(plr, {
			Id = session.Id,
			Partner = them.DisplayName,
			PartnerUserId = them.UserId,
			MyOffer = session.Offers[plr],
			TheirOffer = session.Offers[them],
			MyAccepted = session.Accepted[plr] == true,
			TheirAccepted = session.Accepted[them] == true,
		})
	end
end

local function close(session: Session, reason: string?)
	for _, plr in ipairs({ session.A, session.B }) do
		if sessions[plr] == session then
			sessions[plr] = nil
		end
		if plr.Parent == Players then
			Remotes.Get("TradeState"):FireClient(plr, nil)
			if reason then
				PlayerData.Notify(plr, reason, "Info")
			end
		end
	end
end

function Trading.CancelFor(player: Player, reason: string?)
	local session = sessions[player]
	if session then
		close(session, reason)
	end
end

local function validOffer(player: Player, offer: { [string]: number }): boolean
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	for id, qty in pairs(offer) do
		if (data.OwnedMemes[id] or 0) < qty then
			return false
		end
	end
	return true
end

local function execute(session: Session)
	session.Busy = true
	local A, B = session.A, session.B
	local offerA, offerB = session.Offers[A], session.Offers[B]
	-- Revalidación final con los datos actuales del servidor
	if not (validOffer(A, offerA) and validOffer(B, offerB)) then
		session.Busy = false
		session.Accepted = {}
		pushState(session)
		for _, plr in ipairs({ A, B }) do
			PlayerData.Notify(plr, "El trade cambió: alguien ya no tiene lo que ofrecía. Revisa las ofertas.", "Error")
		end
		return
	end
	for id, qty in pairs(offerA) do
		Inventory.Remove(A, id, qty)
	end
	for id, qty in pairs(offerB) do
		Inventory.Remove(B, id, qty)
	end
	for id, qty in pairs(offerA) do
		Inventory.Add(B, id, qty)
	end
	for id, qty in pairs(offerB) do
		Inventory.Add(A, id, qty)
	end
	for _, plr in ipairs({ A, B }) do
		local data = PlayerData.Get(plr)
		if data then
			data.Stats.TradesCompleted += 1
		end
		PlayerData.Push(plr)
		task.spawn(PlayerData.SaveNow, plr)
	end
	close(session, "✅ ¡Intercambio completado!")
end

function Trading.Init()
	Remotes.Get("TradeRequest").OnServerInvoke = function(player: Player, targetUserId)
		if throttled(player, 1) then
			return false, "¡Más despacio! 😅"
		end
		if type(targetUserId) ~= "number" then
			return false, "Petición inválida"
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target or target == player then
			return false, "Ese jugador no está disponible"
		end
		local ok, why = canTrade(player)
		if not ok then
			return false, why
		end
		local okT = canTrade(target)
		if not okT then
			return false, target.DisplayName .. " está ocupado en una cabina o partida"
		end
		if sessions[player] or sessions[target] then
			return false, "Ya hay un intercambio en curso"
		end
		invites[target] = invites[target] or {}
		invites[target][player] = os.clock() + GameConfig.Trade.InviteTimeout
		Remotes.Get("TradeInvite"):FireClient(target, { FromUserId = player.UserId, FromName = player.DisplayName,
			Timeout = GameConfig.Trade.InviteTimeout })
		return true, "Solicitud enviada a " .. target.DisplayName
	end

	Remotes.Get("TradeRespond").OnServerInvoke = function(player: Player, fromUserId, accept)
		if type(fromUserId) ~= "number" then
			return false, "Petición inválida"
		end
		local from = Players:GetPlayerByUserId(fromUserId)
		local expires = from and invites[player] and invites[player][from]
		if invites[player] and from then
			invites[player][from] = nil
		end
		if not from or not expires or os.clock() > expires then
			return false, "La solicitud ya expiró"
		end
		if accept ~= true then
			PlayerData.Notify(from, player.DisplayName .. " rechazó el intercambio", "Info")
			return true, "Solicitud rechazada"
		end
		if sessions[player] or sessions[from] then
			return false, "Uno de los dos ya está en otro intercambio"
		end
		local ok1, why1 = canTrade(player)
		local ok2 = canTrade(from)
		if not ok1 then
			return false, why1
		end
		if not ok2 then
			return false, from.DisplayName .. " ya no está disponible"
		end
		nextId += 1
		local session: Session = {
			Id = nextId, A = from, B = player,
			Offers = { [from] = {}, [player] = {} },
			Accepted = {}, Busy = false,
		}
		sessions[from] = session
		sessions[player] = session
		pushState(session)
		return true, "Intercambio iniciado"
	end

	-- offer = { [MemeId] = cantidad }
	Remotes.Get("TradeSetOffer").OnServerInvoke = function(player: Player, offer)
		local session = sessions[player]
		if not session or session.Busy then
			return false, "No hay intercambio activo"
		end
		if throttled(player, 0.15) then
			return false, "¡Más despacio! 😅"
		end
		if type(offer) ~= "table" then
			return false, "Oferta inválida"
		end
		local data = PlayerData.Get(player)
		local clean, distinct = {}, 0
		for id, qty in pairs(offer) do
			if type(id) ~= "string" or not MemeCatalog.Get(id) or type(qty) ~= "number" then
				return false, "Oferta inválida"
			end
			qty = math.floor(qty)
			if qty > 0 then
				if not data or (data.OwnedMemes[id] or 0) < qty then
					return false, "No tienes suficientes de ese meme"
				end
				clean[id] = qty
				distinct += 1
			end
		end
		if distinct > GameConfig.Trade.MaxItemsPerSide then
			return false, ("Máximo %d memes distintos por oferta"):format(GameConfig.Trade.MaxItemsPerSide)
		end
		session.Offers[player] = clean
		session.Accepted = {} -- cualquier cambio quita las aceptaciones
		pushState(session)
		return true
	end

	Remotes.Get("TradeAccept").OnServerInvoke = function(player: Player)
		local session = sessions[player]
		if not session or session.Busy then
			return false, "No hay intercambio activo"
		end
		if next(session.Offers[session.A]) == nil and next(session.Offers[session.B]) == nil then
			return false, "Las dos ofertas están vacías"
		end
		session.Accepted[player] = true
		if session.Accepted[session.A] and session.Accepted[session.B] then
			execute(session)
		else
			pushState(session)
		end
		return true
	end

	Remotes.Get("TradeCancel").OnServerInvoke = function(player: Player)
		local session = sessions[player]
		if session and not session.Busy then
			close(session, "❌ Intercambio cancelado")
		end
		return true
	end

	Players.PlayerRemoving:Connect(function(player)
		Trading.CancelFor(player, "❌ El otro jugador salió. Intercambio cancelado.")
		invites[player] = nil
		lastCall[player] = nil
	end)
end

return Trading

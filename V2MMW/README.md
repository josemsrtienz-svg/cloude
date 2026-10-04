# V2MMW · Meme Warriors V2

Juego de Roblox nuevo, hecho desde cero. Apareces en un lobby 3D, caminas y exploras con el HUD encima. Desde ahí entras a cabinas, eliges dificultad y mapa, y una cuenta regresiva te lleva a la partida. Al terminar vuelves al lobby.

## Cómo abrirlo

1. Abre **`V2MMW.rbxlx`** con Roblox Studio (doble clic, o Archivo → Abrir).
2. Dale a **Play**.
3. Si quieres guardar los datos (MemeCoin, inventario): **Archivo → Publicar en Roblox** y luego **Game Settings → Security → Enable Studio Access to API Services**. Sin esto todo funciona, pero no se guarda nada.

## Qué hay en esta carpeta

| Carpeta / archivo | Contenido |
|---|---|
| `V2MMW.rbxlx` | El place completo: mundo, modelos, mapas y todos los scripts |
| `src/` | El código fuente (UI, UX, sistemas), igual al que está dentro del place |
| `Models/World/` | `Lobby`, `MatchStations` (cabinas) y `Maps` como `.rbxmx` sueltos |
| `Models/Memes/` | Los 16 memes en 3D (`.rbxmx`). Arrástralos a Studio para usarlos |
| `build/build_place.luau` | Herramienta que regenera el place desde `src/` con [Lune](https://lune-org.github.io/docs) |
| `default.project.json` | Para usar [Rojo](https://rojo.space) si prefieres editar en VS Code |

## Estructura dentro de Studio

```
ReplicatedStorage
└── V2MMW
    ├── Config   GameConfig · MemeCatalog · Assets
    ├── Shared   Remotes · Util · MemeModels · Geometry
    └── Remotes  (los crea el servidor al arrancar)
ServerScriptService
└── V2MMWServer
    ├── Main
    └── Systems  PlayerData · MemeCoin · Inventory · Shop · Trading · Matchmaking
                 MatchService · Teleport · Abilities · WorldBuilder
StarterPlayer > StarterPlayerScripts
└── V2MMWClient  (LocalScript)
    └── Controllers  UIKit · State · HUD · Hotbar · Navigation · InventoryPanel · ShopPanel
                     TradePanel · SettingsPanel · StationUI · MatchUI
Workspace
├── Lobby          isla flotante: spawn, dojo, monumento, estatuas, MemeMarket, zona de tradeo
├── MatchStations  Cabina1..Cabina4 (capacidad 1, 2, 3 y 4)
└── Maps           Map1..Map3 (PLACEHOLDERS marcados)
```

La interfaz (MainHUD) la crean los scripts del cliente al entrar al juego. Por eso no aparece en StarterGui en modo edición; su código está en `V2MMWClient > Controllers`.

## Cómo se juega

- **Moverte:** WASD o el joystick. El HUD nunca bloquea el movimiento.
- **Perfil y saldo:** arriba a la izquierda están ⚙, tu avatar, tu nombre, tu nivel y tu XP. Arriba en el centro, tu saldo en 🪙 **MemeCoin** y el botón **▶ JUGAR**, que te lleva caminando a la Zona de Partidas.
- **Menú lateral:** a la izquierda, 🛒 TIENDA (MemeMarket), 🎒 INVENTARIO y 🤝 TRADE. También puedes abrirlos hablando con el dependiente o usando el kiosco de tradeo, con la tecla **E**.
- **Barra inferior:** tus 3 memes equipados. En partida se usan con las teclas **1 · 2 · 3**.
- **Cabinas:**
  1. Entras caminando o con **E**.
  2. El anfitrión elige DIFICULTAD y MAPA.
  3. Pulsa **LISTO** y empieza la cuenta: 10 … 1 · GO!
  4. Te transporta al mapa.
- **Mapas placeholder:** gana el primero que llegue a la **META 🏁**. Si se acaba el tiempo (2 min), todos vuelven al lobby con su recompensa.

## Reglas que valida el servidor

- MemeCoin, compras y precios. El cliente nunca decide.
- Como máximo **3 memes equipados**. Si intentas un 4º: "Máximo de 3 memes equipados."
- Capacidad de cada cabina. Si está llena, te saca fuera.
- Solo el anfitrión elige dificultad y mapa, y solo se aceptan valores válidos.
- Trades: los dos jugadores deben aceptar, y el servidor vuelve a comprobar las ofertas antes de hacer el cambio.
- Habilidades: solo funcionan en partida y tienen cooldown.
- Datos: session locking + autosave. No se duplican objetos aunque entres y salgas rápido.

## Personalizar

- **Imágenes de memes:** en `Config > Assets > MemeImages`, pon `"rbxassetid://ID"`. Tus imágenes siempre tienen prioridad.
- **Sonidos y música:** en `Config > Assets > Sounds`.
- **Nuevo meme:** añádelo en `Config > MemeCatalog`. Si quieres un modelo 3D propio, crea `ReplicatedStorage > MemeModels > <Id>`.
- **Mapa real:** sustituye `Workspace > Maps > Map1`. Usa el mismo nombre y pon una carpeta `Spawns` con Parts. La Part `Goal` (meta) es opcional.
  - Para que el mapa sea otro place de la misma experiencia, pon su `PlaceId` en `GameConfig.Maps`. Solo funciona en el juego publicado.
- **Dificultades, recompensas, duración, cabinas:** todo está en `Config > GameConfig`.
- **Dar premios desde otro script:**
  `game.ServerStorage.V2MMWGrant:Fire(player, { MemeCoin = 50, XP = 20 })`

## Probar

- **Solo:** Play → JUGAR → entra a la CABINA 1 → elige → LISTO.
- **Varios jugadores (cabinas 2-4 y trade):** Prueba → Clientes y servidores → 2-4 jugadores.
- **Móvil:** Prueba → Emulador de dispositivos.

## Pendiente (siguientes pasos)

- Los mapas 1-3 son **placeholders** con un objetivo de prueba (llegar a la meta). El gameplay real se conecta llamando a `MatchService.Finish(matchId, ganador)`.
- La música está vacía hasta que pongas IDs en `Assets.Sounds`.

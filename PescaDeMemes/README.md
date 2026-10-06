# Pesca de Memes — Prototipo P0

Prototipo jugable para responder una sola pregunta: **¿pescar es divertido 20 veces seguidas?**
Diseño completo: [`docs/GDD_PESCA_DE_MEMES.md`](../docs/GDD_PESCA_DE_MEMES.md).

## Cómo abrirlo en Roblox Studio

**Opción A — archivo listo:** abre `PescaDeMemes.rbxlx` (se genera con `rojo build`, ver abajo) y pulsa **Play**.

**Opción B — Rojo en vivo (para editar el código):**
```powershell
cd PescaDeMemes
rojo serve
```
En Studio: plugin **Rojo → Connect**, y luego **Play**.

Para generar el archivo:
```powershell
rojo build default.project.json -o PescaDeMemes.rbxlx
```

> El mapa (río, 8 parcelas con muelle, tienda) se construye **por script** al darle a Play.
> Para verlo sin Play: Command Bar → `require(game.ServerScriptService.PescaServer.Systems.WorldBuilder).Build()`
> Pon el máximo de jugadores del servidor en **8** (una parcela por jugador).
> Para que se guarde el progreso en Studio: publica el place y activa
> *Game Settings → Security → Enable Studio Access to API Services*. Si no, se juega con datos temporales.

## Cómo se juega
1. Apareces en **tu parcela** (cartel con tu nombre). Delante tienes **tu muelle privado** sobre el río.
2. Saca la **caña** de la barra de abajo (tecla **1**) y ve al **final de tu muelle** (solo puedes pescar en el tuyo).
3. **Mantén** 🎣 LANZAR (o **F**) y suelta. Mientras esperas, una **ruleta** enseña los memes que pueden picar.
4. No toques hasta **"❗ ¡TOCA YA!"**. Si pesa más que tu caña verás el **% de aguante** → PELEAR o SOLTAR.
5. Pelea con la barra de tensión. Si pierdes, el sedal **sube rapidísimo** y se escapa.
   Si fallas un **⚡ TIRÓN** con sobrecarga, **la caña se ROMPE** (repárala en la tienda; la de palo es irrompible).
6. Lo que pescas entra en tu **mochila-acuario** (a la espalda). Cada meme ocupa su peso en kg.
   Pesca varios en la misma "ronda" hasta llenarla; si algo no cabe: **vender ya** o **soltar**.
7. Vuelve a tu parcela: **al entrar se colocan solos** en el césped (los más valiosos primero) y generan
   MemeCoins en el **círculo verde** (písalo para cobrar). "Recoger" junto a un meme lo devuelve al acuario.
8. Tienda (entrada del mapa): cañas, **reparar**, mochilas-acuario más grandes y Sedal Reforzado.

## Estructura
```
src/ReplicatedStorage/PescaDeMemes/
  Config/   GameConfig (reglas, mapa del río y parcelas) · Memes (8 memes) · Rods (cañas, mochilas-acuario, Sedal) · Assets
  Shared/   Remotes · Inventory (acuario/parcela) · MemeModels (figuras de bloques) · FishMath (peso/capacidad/aguante/valor) · FishBehaviors (cómo pelea cada meme) · Util
src/ServerScriptService/PescaServer/
  Main.server.lua
  Systems/  PlayerData (guardado con session lock) · FishingService (autoridad de la pesca)
            GearService (caña-herramienta, mochila visible) · PlotService (parcelas, descarga, cobrador)
            EconomyService (ventas, tienda, reparar) · WorldBuilder (río + 8 parcelas con muelle propio)
src/StarterPlayer/StarterPlayerScripts/PescaClient/
  init.client.lua
  Controllers/  State · UIKit · HUD · FishingController (minijuego) · CatchCard · Panels · PlotController
```

## Seguridad
El servidor decide qué meme pica, su peso, si es dorado y su valor; valida distancia al agua,
cooldowns, ventana de la picada, tiempo mínimo de pelea, número y ritmo de tirones, y crea cada captura
con un id único. **Riesgo conocido del prototipo:** el resultado de la pelea (y si estabas en verde en un tirón)
lo informa el cliente, así que un exploit podría automatizar peleas respetando los tiempos mínimos.
Para la beta: registrar tasas de éxito por jugador y marcar valores anómalos.

## Balance
Todos los números están en `Config/` y son **valores iniciales**: se ajustan tras probar con 3–5 personas.

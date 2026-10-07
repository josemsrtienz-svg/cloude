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
3. **Mantén CLICK** (o el dedo, o **F**) y suelta: la barra de fuerza en la **zona dorada** = PERFECTO (+suerte).
4. **Inmersión:** la cámara baja al agua. El anzuelo baja solo; **guíalo** con **A/D**, el **ratón** o el **dedo**
   hacia los memes. Encima de cada uno ves su rareza y sus kg: **verde** se engancha solo, **naranja ⚔️** pesa más
   que tu caña (PELEAR o SOLTAR) y **rojo ⛔** es demasiado pesado. Tu caña tiene X **anzuelos** y baja X **metros**.
   **Frena** manteniendo **S / ↓** (o el click/dedo) para no pasarte de un meme. En las capas oscuras lleva la 🔦 **Linterna**.
5. Pelea con la barra de tensión. Si pierdes, el sedal **sube de golpe**; si fallas un **⚡ TIRÓN**,
   **la caña se ROMPE** (repárala en la tienda; la de palo es irrompible).
6. Se sube al llenar los anzuelos, al tocar el fondo o con **SUBIR (E)**. Los memes saltan a tu **mochila-acuario**.
7. Vuelve a tu parcela: **al entrar se colocan solos** en el césped y generan MemeCoins en el **círculo verde**
   (písalo para cobrar). "Recoger" junto a un meme lo devuelve al acuario.
8. **Tienda:** el botón del HUD vende cañas, mochilas y objetos. La **GRAN TIENDA** (entrada del mapa) tiene además
   **⚡ boosts** (Dinero ×2, Suerte ×2, Anzuelo ×1.5, +1 Anzuelo), **💎 pases de Robux** y el **🎁 boost gratis** del tablón (cambia cada 15 min).
9. **Objetos:** en la pestaña Objetos eliges qué llevas en tus **huecos** (1 al empezar): Sedal, Linterna, Imán, Red Dorada.
10. **Misiones (📜):** 3 misiones al día y un regalo diario con racha de 7 días.
11. **Mercader (🧳):** cada hora amarra su barca junto al puente 10 min con un meme raro, un objeto al 50 % y un boost rebajado.
12. **Clima (arriba a la izquierda):** con 🌧️ lluvia, ⛈️ tormenta o 🌕 luna llena los memes pueden salir 💧×2, ⚡×5 o 🌙×10. Los **cebos** (pestaña Objetos) ayudan.
13. **Jefe del río (🐋):** cada 30 min emerge la Ballena Sigma. Ve al río con la caña y pulsa **🎣 ¡TIRA!** (R) con todo el servidor: premio para todos y sorteo de un meme **DIOS**.
14. **♻️ Renacer** (botón en 🏠 Parcela): con la Abisal y 2M MemeCoins, reinicias dinero y cañas a cambio de **dinero ×1,5**, la **terraza** de tu parcela (+2 huecos) y huecos de objeto.

> 🎵 **Música:** pon IDs de música con licencia (Creator Store, autor Roblox/APM) en `Config/Assets.lua` → `Assets.Music`.
> Los efectos ya suenan con sonidos que vienen con Roblox. Música y efectos se apagan en ⚙️ Ajustes.

> 🎓 **Tutorial:** los jugadores nuevos lo ven al entrar (6 pasos con flecha). En Studio sale en cada Play
> mientras `GameConfig.DevMode.Tutorial = true`; ponlo en false para empezar con él hecho.

> 🧪 **Modo prueba:** en Studio empiezas con dinero infinito y la sesión NO se guarda (`GameConfig.DevMode`).
> Apágalo (`Enabled = false`) para probar el guardado y siempre antes de publicar.

Estado y fases del proyecto: [`docs/GAME_STATE.md`](../docs/GAME_STATE.md).

## Estructura
```
src/ReplicatedStorage/PescaDeMemes/
  Config/   GameConfig (reglas, mapa del río y parcelas) · Memes (8 memes) · Rods (cañas, mochilas-acuario, Sedal) · Assets
  Shared/   Remotes · Inventory (acuario/parcela) · MemeModels (figuras de bloques) · GearModels (caña, mochila, iconos 3D)
            FishMath (peso/capacidad/aguante/valor) · FishBehaviors (cómo pelea cada meme) · Util
src/ServerScriptService/PescaServer/
  Main.server.lua
  Systems/  PlayerData (guardado con session lock) · FishingService (autoridad de la pesca)
            GearService (caña-herramienta, mochila visible) · PlotService (parcelas, descarga, cobrador)
            EconomyService (ventas, tienda, reparar) · WorldBuilder (río + 8 parcelas con muelle propio)
src/StarterPlayer/StarterPlayerScripts/PescaClient/
  init.client.lua
  Controllers/  State · UIKit (fotos 3D) · HUD · FishingController (lanzar + inmersión) · DiveScene (escena submarina)
                FightUI (pelea) · CatchCard (resultados) · Panels (tienda, acuario, parcela, índice) · PlotController · Ambience
```

## Seguridad
El servidor genera cada inmersión (qué memes hay, profundidad, peso, si son dorados y su valor) y valida cada
enganche: que el anzuelo PUEDE estar a esa profundidad en ese momento (baja a velocidad fija) y en esa x (se mueve
de lado a velocidad limitada y el meme tiene que estar cerca), que quedan anzuelos,
que cabe en el acuario y que no es demasiado pesado. También valida tiempo mínimo de pelea y ritmo de tirones, y crea
cada captura con un id único. **Riesgo conocido del prototipo:** el resultado de la pelea (y si estabas en verde en un
tirón) lo informa el cliente, así que un exploit podría automatizar peleas respetando los tiempos mínimos.

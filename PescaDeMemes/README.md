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

> El mapa (agua, muelle, tienda, acuario) se construye **por script** al darle a Play.
> Para que se guarde el progreso en Studio: publica el place y activa
> *Game Settings → Security → Enable Studio Access to API Services*. Si no, se juega con datos temporales.

## Cómo se juega
1. Camina por el camino de piedras hasta el muelle.
2. **Mantén** el botón 🎣 LANZAR (o la tecla **F**) y suelta: cuanto más lleno, más lejos (zona dorada = PERFECTO).
3. Espera. **No toques** hasta que salga **"❗ ¡TOCA YA!"**, y entonces toca rápido.
4. Si el meme pesa más que tu caña, verás el **% de aguante** → **PELEAR** o **SOLTAR**.
5. Pelea: **mantén pulsado** (clic/toque en cualquier sitio o F) para subir la tensión, suelta para bajarla.
   Mantén el indicador blanco en la **zona verde**. Si te quedas en el **rojo 💥**, se rompe.
   Con sobrecarga llegan 3 **⚡ TIRONES**: si en ese momento estás en verde, tienes más probabilidad de aguantar.
6. Tarjeta de captura → 🐠 Acuario (genera monedas) / 💰 Vender / 🎒 Guardar.
7. Compra cañas con más capacidad en la **Tienda** (caseta de la derecha) y mira tu colección en el **Bestiario**.

## Estructura
```
src/ReplicatedStorage/PescaDeMemes/
  Config/   GameConfig (reglas y balance) · Memes (8 memes) · Rods (cañas + Sedal Reforzado) · Assets
  Shared/   Remotes · FishMath (peso/capacidad/aguante/valor) · FishBehaviors (cómo pelea cada meme) · Util
src/ServerScriptService/PescaServer/
  Main.server.lua
  Systems/  PlayerData (guardado con session lock) · FishingService (autoridad de la pesca)
            EconomyService (mochila, acuario, tienda) · WorldBuilder (mapa Charca del Noob)
src/StarterPlayer/StarterPlayerScripts/PescaClient/
  init.client.lua
  Controllers/  State · UIKit · HUD · FishingController (minijuego) · CatchCard · Panels
```

## Seguridad
El servidor decide qué meme pica, su peso, si es dorado y su valor; valida distancia al agua,
cooldowns, ventana de la picada, tiempo mínimo de pelea, número y ritmo de tirones, y crea cada captura
con un id único. **Riesgo conocido del prototipo:** el resultado de la pelea (y si estabas en verde en un tirón)
lo informa el cliente, así que un exploit podría automatizar peleas respetando los tiempos mínimos.
Para la beta: registrar tasas de éxito por jugador y marcar valores anómalos.

## Balance
Todos los números están en `Config/` y son **valores iniciales**: se ajustan tras probar con 3–5 personas.

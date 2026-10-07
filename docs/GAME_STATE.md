# PESCA DE MEMES — Estado del juego y hoja de ruta por fases

> Fuente principal del progreso (skill **roblox-game-creator**). Se actualiza en cada versión.
> Diseño completo: [`GDD_PESCA_DE_MEMES.md`](GDD_PESCA_DE_MEMES.md) · Código: [`../PescaDeMemes`](../PescaDeMemes)

```text
PROJECT:          Pesca de Memes (nombre provisional)
STATUS:           Alpha en producción
CURRENT_PHASE:    FASE 4 — ALPHA   ← ESTAMOS AQUÍ (Fase 3 cerrada en la VS 0.2; su playtest lo hace el equipo)
GAME_VERSION:     A 0.3
CORE_LOOP_STATUS: Lanzar con click → INMERSIÓN (guiar el anzuelo) → enganchar / pelear → subir → mochila → parcela → dinero
META_LOOP:        clima con mutaciones (💧×2 ⚡×5 🌙×10) · 4 cebos · 16 cañas con perks · 12 mochilas · niveles que abren capas · misiones diarias + racha · mercader cada hora
MAP_STATUS:       Río ancho (80 studs) y largo (360), 8 parcelas con muelle propio, arco, Gran Tienda, barca del mercader
SYSTEMS_STATUS:   PlayerData v5 · GearService · FishingService (inmersión) · PlotService · EconomyService · BoostService · MissionService · MerchantService · WeatherService · BossService · RebirthService · WorldBuilder
UI_STATUS:        HUD con iconos 3D · inmersión · pelea · resultados · tienda · índice · misiones · mercader · ⚙️ ajustes · tutorial
AUDIO_STATUS:     VS 0.1: efectos con respaldo automático, combo de notas, fanfarrias por rareza, monedas que tintinean · música: faltan IDs
DATA_STATUS:      Schema v5 con session lock y migraciones (v4 recalcula valores; v5 marca el tutorial como hecho a los antiguos)
SECURITY_STATUS:  El servidor genera la inmersión y valida enganches, compras, misiones, mercader y ajustes
QA_STATUS:        luau-lsp + rojo build OK en cada versión · v0.4 probada en Studio sin errores · v0.5–VS 0.1 pendientes de probar
KNOWN_BUGS:       — (por descubrir en la prueba)
NEXT_STEP:        Fase 4 · tarea 5: MASCOTAS brainrot propias · pendiente del equipo: playtest de la Fase 3
```

## Fases

| # | Fase | Objetivo | Estado |
|---|---|---|---|
| 0 | Validación | Idea, nicho, referencias | ✅ Hecho (concepto A "Pesca de Memes") |
| 1 | Preproducción | GDD, core loop, sistemas, arquitectura | ✅ Hecho (GDD v0.1 + mecánica peso/capacidad) |
| 2 | Prototipo (P0) | Meter y probar TODAS las ideas para ver cómo queda el juego | ✅ **Cerrada en la v0.9** (decisión del equipo) |
| 3 | Vertical slice | Zona 1 con calidad casi final: sonido, pulido, móvil, balance, playtest | ✅ Cerrada en la VS 0.2 (playtest pendiente del equipo) |
| 4 | **Alpha** | Todos los sistemas principales: clima, cebos, jefe, renacer, mascotas, intercambio | 🟡 **En curso (A 0.1)** |
| 5 | Beta | Balance, móvil, multijugador, QA, rendimiento | ⬜ |
| 6 | Release | Icono, thumbnail, descripción, monetización ética, analítica | ⬜ |
| 7 | Live ops | Eventos, skins de muelle, zonas nuevas, temporadas | ⬜ |

### FASE 2 — Prototipo: qué se hizo (CERRADA en la v0.9)

| Hecho | Versión |
|---|---|
| Pesca con minijuego de tensión + peso del meme vs. capacidad de la caña + tirones | v0.1 |
| Parcelas estilo "steal" con muelle propio, cobrador e ingresos | v0.2 |
| Mapa con casillas, caña-herramienta, mochila-acuario con kg, caña que se rompe, figuras 3D de bloques | v0.3 |
| **Inmersión** (cámara bajo el agua, guiar el anzuelo, varios memes por lanzamiento), lanzar con **click**, río más ancho, **fotos 3D** en toda la GUI, **tienda nueva**, más animaciones | v0.4 |
| **Gran Tienda** al fondo del río (VIP dentro, sin puesto aparte) + **tablón del boost gratis** que cambia cada 15 min (5 min de uso) · **profundidad ×10** (hasta 600 m) con **capas** que oscurecen · **filtros** (el anzuelo ignora rarezas / venta automática) · **cañas con diseño propio y efectos** · **arco nuevo** legible por los dos lados | **v0.6** |
| **16 cañas** (12 nuevas con diseño 3D, partículas y PERKS: dorados, gigantes, ver en lo oscuro, enganche) · **misiones diarias + racha de 7 días** · **mercader ambulante** en su barca junto al puente | **v0.9** |
| **Tutorial jugando** (6 pasos con flecha y rastro, primer meme asegurado, premio 250 🪙, botón Saltar) | **v0.8** |
| **Freno** del anzuelo · **economía nueva** (peso y rareza, ×10 más dinero) · **gigantes y colosales** · **12 mochilas** con diseño propio · **objetos con huecos** (Linterna para capas oscuras, Imán, Red Dorada, Sedal) | **v0.7** |
| Rarezas **Mítico → Legendario → Secreto → Dios** (eventos), **6 memes nuevos con efectos**, capas de profundidad, **Gran Tienda** física (boosts, Robux, regalo gratis aleatorio), fauna del río, árboles y flores, **cara del jugador** en su parcela, **modo prueba** con dinero infinito | **v0.5** |

Lo que quedaba pendiente (balance, sonidos, IDs de pases) pasa a la Fase 3.

### El NIVEL (decidido: opciones 1 y 4)
- **Desbloquea capas de profundidad:** Charca (Nv 1) · Arrecife Meme (Nv 5) · Abismo Brainrot (Nv 15) · Fosa Abisal (Nv 30).
  Aunque tu caña baje más, la inmersión se para en la primera capa bloqueada (barrera roja con el nivel que falta).
- **Cofre al subir de nivel:** 100 + 50×nivel MemeCoins; cada 5 niveles un boost seguro de 5 min y en el resto
  un 25 % de un boost de 3 min. Si el nivel abre una capa, el cofre lo anuncia.
- En modo prueba empiezas en el nivel 30 para probar todas las capas.

### FASE 3 — Vertical slice (CERRADA en la VS 0.2 · el playtest lo hace el equipo)
**Objetivo:** la zona 1 (río, parcelas, tienda y las capas de profundidad) con calidad casi final. Que un jugador
nuevo diga "esto parece un juego de verdad" y quiera seguir.

| # | Tarea | Prioridad | Estado |
|---|---|---|---|
| 1 | **Audio y "dopamina"**: efectos, combo de notas, fanfarrias por rareza, confeti, monedas que tintinean, música por ambiente, ⚙️ Ajustes | P0 | ✅ VS 0.1 (faltan los IDs de música: los pone el equipo) |
| 2 | **Pulido visual**: doble onda y espuma al lanzar, burbujas del anzuelo y al enganchar, destello al entrar/salir del agua, temblor de cámara (capturas grandes, caña rota) | P0 | ✅ VS 0.2 |
| 3 | **Móvil**: escala mínima mayor, cifras y botones arriba a la derecha (lejos del joystick y del salto), sin controles táctiles durante la inmersión, textos para dedo | P0 | ✅ VS 0.2 (falta probar en un teléfono real) |
| 4 | **Balance con números**: simulador y nuevos precios, parcela 8 %/min, XP cuadrática → [`BALANCE.md`](BALANCE.md) | P0 | ✅ VS 0.2 |
| 5 | **Rendimiento**: sin sombras en piezas pequeñas (mapa y memes), StreamingEnabled desactivado a propósito, contador de piezas en Studio | P1 | ✅ VS 0.2 (medir FPS en móvil en el playtest) |
| 6 | **Playtest** con 3–5 jugadores nuevos + lista de bugs y arreglos | P0 | ⏳ Pendiente del equipo (se arregla lo que salga en cualquier fase) |
| 7 | IDs reales de Game Passes y de música (equipo) | P1 | ⬜ |

**Terminado cuando:** un jugador nuevo juega 15 min en PC **y** en móvil sin ayuda, con sonido, sin errores en la
consola, entiende qué hacer después y quiere seguir; FPS ≥ 50 en un móvil medio.

**Riesgos:** los sonidos clásicos de Roblox cambian de formato (por eso cada uno tiene respaldo) · que se cuelen ideas
nuevas (van a la lista de la Fase 4, no aquí) · el móvil, que aún no se ha probado.

### FASE 4 — Alpha (EN CURSO)
**Objetivo:** que estén **todos los sistemas principales** del juego, funcionando juntos y guardándose bien. Después
de la Alpha ya no entran sistemas nuevos: solo contenido, balance y pulido (Beta).

| # | Sistema | Prioridad | Estado |
|---|---|---|---|
| 1 | **Clima y mutaciones**: el clima cambia cada 8 min, igual en todos los servidores (☀️/🌧️/⛈️/🌕). Las mutaciones son 💧 Mojado ×2, ⚡ Eléctrico ×5 y 🌙 Lunar ×10, y se ven en el meme. Hay lluvia, rayos y noche | P1 | ✅ A 0.1 |
| 2 | **Cebos**: 🌶️ Picante (+50 % raros), 🪙 Dorado (×3 dorados), ⚓ Pesado (×2,5 gigantes), 🌙 Lunar (×2 mutaciones). Ocupan huecos de objeto | P1 | ✅ A 0.1 |
| 3 | **Jefe del río**: cada 30 min (min. 15) emerge la **Ballena Sigma** (DIOS) en el río; todo el servidor pulsa 🎣 ¡TIRA! durante 3 min; monedas para quien ayuda y sorteo del meme DIOS | P1 | ✅ A 0.2 |
| 4 | **Renacer**: pierdes dinero y cañas; ganas dinero ×1,5 por renacer, la **terraza** de la parcela (+2 huecos por renacer, hasta 12) y huecos de objeto (renacer 1 y 3). Coste 2M ×4 cada vez, con la Abisal | P1 | ✅ A 0.3 |
| 5 | **Mascotas**: brainrots propios (modelos originales) que acompañan y dan bonus | P1 | ⬜ Siguiente |
| 6 | **Intercambio** seguro: doble confirmación, el servidor bloquea los objetos, sin duplicados | P1 | ⬜ |
| 7 | **Más memes** por capa (2–3 nuevos en cada una) | P2 | ⬜ |
| 8 | **Clasificación**: el meme más pesado y el dinero por minuto (base del torneo de la Fase 5) | P2 | ⬜ |

**Terminado cuando:** los 6 primeros sistemas están en el juego, sus datos migran sin errores, cada uno pasa una revisión
de seguridad, y una partida de 30 min los toca todos sin errores en la consola.

**Riesgos:**
- **Intercambio:** duplicados y estafas. Hay que hacer bloqueo en el servidor y la doble confirmación desde el principio.
- **Balance:** un 🌙 dorado vale ×30. Hay que vigilarlo con el simulador.
- **Alcance:** las mascotas pueden crecer sin fin. Primero 6 mascotas con un solo bonus cada una.

## Decisiones del equipo sobre las ideas (después de probar la v0.4)

**Nada de esto es para ahora**: se hará cuando el juego esté más terminado (no son prioridades del prototipo).

| Idea | Decisión | Notas | Fase |
|---|---|---|---|
| 🌦️ Clima y noche con **mutaciones** | ✅ **Hecho (A 0.1)** | Mojado ×2, Eléctrico ×5, Lunar ×10 | 4 |
| 🦈 Jefe del río | ✅ **Hecho (A 0.2)** | Ballena Sigma (DIOS), evento global cada 30 min | 4 |
| 🏴‍☠️ Robar memes de otras parcelas | 🤔 Más adelante | Solo si llega con defensa: **trampas** y **bate** en la mano (como Steal a Brainrot). Hace al jugador estar más activo | 5+ |
| 🪝 Cebos (picante, dorado, pesado) | ✅ **Hecho (A 0.1)** | + Cebo Lunar (×2 mutaciones). En la pestaña Objetos | 4 |
| 🗺️ Zonas nuevas | 🔁 Cambiado a **capas de profundidad** | Hecho en v0.5: los memes tienen `MinDepth` (míticos desde 12 m, secretos desde 30–40 m). Más capas con su fondo y sus memes más adelante | 3–4 |
| 🐾 Mascotas | ✅ Sí, junto con **intercambio (trading)** | Mascotas = **brainrots propios** hechos con nuestros modelos de bloques (diseños originales inspirados en la cultura meme, no copias) | 4–5 |
| 🧪 Caldero de fusión | — | Sin decidir | — |
| 📜 Misiones diarias + racha | ✅ **Hecho (v0.9)** | 3 misiones al día según tu nivel + regalo de racha (7 días) | 3 |
| 🏆 Torneo semanal | ✅ Sí | | 5 |
| ♻️ Renacer | ✅ **Hecho (A 0.3)** | Terraza de la parcela, dinero ×1,5 por renacer, huecos de objeto | 4 |

### Tienda
| Idea | Decisión | Diseño |
|---|---|---|
| **Stock rotativo** | ✅ Para **monetizar**: un stock con MemeCoins y otro con Robux | Rotan cada X min, cantidades limitadas | 
| **Mercader ambulante** cada hora | ✅ **Hecho (v0.9)** | Barca-tienda junto al puente, 10 min cada hora: 1 meme raro (nunca secretos), 1 objeto al 50 %, 1 boost rebajado |
| **Mejorar la caña por niveles** | ✅ Con tope | Cada caña sube de nivel (+kg, +suerte…), pero **una caña al máximo nunca iguala a la siguiente** (tope ≈ 85–90 % del salto hasta la siguiente; la última caña, +25 % como máximo). Así comprar la siguiente siempre merece la pena |
| **Tendero animado** | ✅ Hecho (v0.5) | El tendero de la Gran Tienda saluda |
| **Boost gratis** | ✅ Hecho (v0.5) | Reloj aleatorio por jugador (9–20 min), se recoge en la Gran Tienda en 5 min |
| **Tienda física completa** | ✅ Hecho (v0.5) | HUD = Cañas/Mochilas/Objetos · Gran Tienda = todo + ⚡ Boosts + 💎 Robux + ✨ Muelles |

### Rarezas (decidido)
Común → Poco común → Raro → Épico → **Mítico** → **Legendario** → **Secreto** → **DIOS** (solo eventos, `Odds = 0`).
Míticos: Gato Pop, Plátano Bailarín, Hámster Dramático. Secretos: Tiburón Zapatillero, Capibara Zen, Cocodrilo Aviador.

## Skins de parcela y muelle (futuro — FASE 7, teaser ya visible en la tienda)

| Skin | Cómo se consigue | Bonus |
|---|---|---|
| Muelle Pirata | Comprar con MemeCoins | +10 % suerte |
| Muelle Neón | Evento nocturno | ×1.25 dinero de la parcela |
| Muelle Dorado | Evento limitado / torneo | +25 % suerte y ×1.5 dinero |

Diseño técnico previsto: `PlotSkins` y `EquippedPlotSkin` en los datos (migración v4); `Config/PlotSkins` con
paleta, accesorios y bonus; WorldBuilder pinta la parcela y el muelle con el tema; FishingService suma la suerte
y PlotService el multiplicador. Los bonus son pequeños para no romper el balance (regla de monetización ética).

## Antes de publicar (Fase 6) — no olvidar
- [ ] `GameConfig.DevMode.Enabled = false` (el dinero infinito solo funciona en Studio, pero se apaga igual).
  Con eso también se apagan `DevMode.Tutorial`, `DevMode.MerchantAlways` (mercader siempre presente),
  `DevMode.BossTest` (jefe cada 4 min) y `DevMode.Weather` (clima forzado).
- [ ] **Sonidos y música propios** (decisión del equipo: los clásicos de Roblox no dan suficiente "dopamina"):
  pegar los IDs en `Config/Assets.lua` (primer candidato de cada sonido + `Assets.Music`).
- [ ] IDs reales de los Game Passes en `Config/Monetization` y precios iguales que en el Dashboard.
- [ ] Máximo de jugadores del servidor = 8 (una parcela cada uno).

## Historial
- **A 0.3** — Renacer: terraza nueva en todas las parcelas (4 huecos con candado), dinero ×1,5 por renacer, huecos de objeto, ♻️ en el cartel, panel con doble confirmación.
- **A 0.2** — Jefe del río: la Ballena Sigma (primer meme DIOS, modelo nuevo) emerge cada 30 min; todo el servidor tira con 🎣 ¡TIRA!; premio repartido y sorteo del DIOS.
- **A 0.1** — Empieza la Fase 4 (Alpha): clima global con lluvia, tormenta y luna llena; mutaciones 💧⚡🌙 en valor, modelos y UI; 4 cebos con modelo 3D.
- **VS 0.2** — Pulido visual (ondas, burbujas, transiciones, temblor), móvil, balance con simulador (BALANCE.md) y rendimiento. Ajuste "Temblor de cámara".
- **VS 0.1** — Se cierra la Fase 2. Fase 3 empieza por el audio: sonidos con respaldo, "dopamina" (combo de notas, fanfarrias, confeti, monedas), música por ambiente y ⚙️ Ajustes.
- **v0.9** — 12 cañas nuevas (16 en total) con perks, misiones diarias y racha, mercader ambulante.
- **v0.8** — Tutorial jugando: muelle → caña → lanzar → meme asegurado → parcela → cobrar. Datos v5.
- **v0.7** — Freno del anzuelo, economía por peso y rareza (migración v4), gigantes/colosales, 12 mochilas, objetos con huecos (Linterna, Imán, Red Dorada) y debate de comprar memes.
- **v0.6.1** — El nivel desbloquea capas (5/15/30) y da un cofre con MemeCoins y boosts al subir.
- **v0.6** — Gran Tienda rediseñada con VIP dentro y tablón de boost gratis (15 min), profundidad hasta 600 m con 4 capas, filtros de pesca y de venta automática, cañas con diseño y efectos, arco nuevo.
- **v0.5** — Míticos y secretos con efectos, rareza Dios (eventos), capas de profundidad, Gran Tienda (boosts, Robux, regalo), fauna del río, árboles, cara del jugador en su parcela, modo prueba.
- **v0.4** — Inmersión estilo Fish an Egg, click para lanzar, río ×2 de ancho, fotos 3D, tienda nueva, animaciones.
- **v0.3** — Mapa estilo steal, caña-herramienta, mochila-acuario, ruleta, rotura de caña, figuras de bloques.
- **v0.2** — Parcelas con muelle propio y cobrador.
- **v0.1** — Prototipo: pesca, peso vs. capacidad, acuario, tienda.

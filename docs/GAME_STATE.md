# PESCA DE MEMES — Estado del juego y hoja de ruta por fases

> Fuente principal del progreso (skill **roblox-game-creator**). Se actualiza en cada versión.
> Diseño completo: [`GDD_PESCA_DE_MEMES.md`](GDD_PESCA_DE_MEMES.md) · Código: [`../PescaDeMemes`](../PescaDeMemes)

```text
PROJECT:          Pesca de Memes (nombre provisional)
STATUS:           Prototipo jugable
CURRENT_PHASE:    FASE 2 — PROTOTIPO (P0)   ← ESTAMOS AQUÍ
GAME_VERSION:     P0 0.8
CORE_LOOP_STATUS: Lanzar con click → INMERSIÓN (guiar el anzuelo) → enganchar / pelear → subir → mochila → parcela → dinero
MAP_STATUS:       Río ancho (80 studs) y largo (360), 8 parcelas con muelle propio, estilo casillas con studs
SYSTEMS_STATUS:   PlayerData v5 · GearService · FishingService (inmersión) · PlotService · EconomyService · WorldBuilder
UI_STATUS:        HUD con iconos 3D · escena submarina + medidor de profundidad · pelea · resultados · tienda nueva · índice
DATA_STATUS:      Schema v5 con session lock y migraciones (v4 recalcula valores; v5 marca el tutorial como hecho a los jugadores antiguos)
SECURITY_STATUS:  El servidor genera la inmersión y valida cada enganche por tiempo/profundidad, anzuelos y espacio
QA_STATUS:        v0.4 probada en Studio por el equipo: SIN ERRORES · v0.5: luau-lsp + rojo build OK, pendiente de probar
KNOWN_BUGS:       — (por descubrir en la prueba)
NEXT_STEP:        Probar la v0.8 (tutorial) y luego meter más ideas y seguir metiendo ideas en el prototipo (la Fase 2 sigue abierta: aquí se prueba TODO)
```

## Fases

| # | Fase | Objetivo | Estado |
|---|---|---|---|
| 0 | Validación | Idea, nicho, referencias | ✅ Hecho (concepto A "Pesca de Memes") |
| 1 | Preproducción | GDD, core loop, sistemas, arquitectura | ✅ Hecho (GDD v0.1 + mecánica peso/capacidad) |
| 2 | **Prototipo (P0)** | Meter y probar TODAS las ideas para ver cómo queda el juego | 🟡 **En curso, abierta a propósito** (decisión del equipo: es la fase más importante) |
| 3 | Vertical slice | Zona 1 con calidad casi final: arte, sonido, onboarding | ⬜ Siguiente |
| 4 | Alpha | Todos los sistemas principales (zonas, eventos, misiones, trading…) | ⬜ |
| 5 | Beta | Balance, móvil, multijugador, QA, rendimiento | ⬜ |
| 6 | Release | Icono, thumbnail, descripción, monetización ética, analítica | ⬜ |
| 7 | Live ops | Eventos, skins de muelle, zonas nuevas, temporadas | ⬜ |

### FASE 2 — Prototipo: qué hay y qué falta

| Hecho | Versión |
|---|---|
| Pesca con minijuego de tensión + peso del meme vs. capacidad de la caña + tirones | v0.1 |
| Parcelas estilo "steal" con muelle propio, cobrador e ingresos | v0.2 |
| Mapa con casillas, caña-herramienta, mochila-acuario con kg, caña que se rompe, figuras 3D de bloques | v0.3 |
| **Inmersión** (cámara bajo el agua, guiar el anzuelo, varios memes por lanzamiento), lanzar con **click**, río más ancho, **fotos 3D** en toda la GUI, **tienda nueva**, más animaciones | v0.4 |
| **Gran Tienda** al fondo del río (VIP dentro, sin puesto aparte) + **tablón del boost gratis** que cambia cada 15 min (5 min de uso) · **profundidad ×10** (hasta 600 m) con **capas** que oscurecen · **filtros** (el anzuelo ignora rarezas / venta automática) · **cañas con diseño propio y efectos** · **arco nuevo** legible por los dos lados | **v0.6** |
| **Tutorial jugando** (6 pasos con flecha y rastro, primer meme asegurado, premio 250 🪙, botón Saltar) | **v0.8** |
| **Freno** del anzuelo · **economía nueva** (peso y rareza, ×10 más dinero) · **gigantes y colosales** · **12 mochilas** con diseño propio · **objetos con huecos** (Linterna para capas oscuras, Imán, Red Dorada, Sedal) | **v0.7** |
| Rarezas **Mítico → Legendario → Secreto → Dios** (eventos), **6 memes nuevos con efectos**, capas de profundidad, **Gran Tienda** física (boosts, Robux, regalo gratis aleatorio), fauna del río, árboles y flores, **cara del jugador** en su parcela, **modo prueba** con dinero infinito | **v0.5** |

| Falta para cerrar la fase (P0) | Prioridad |
|---|---|
| ~~Probar en Studio la inmersión~~ ✅ (v0.4 sin errores) | P0 |
| ~~Tutorial corto de 30–60 s jugando~~ ✅ (v0.8) | P0 |
| Ajustar balance: velocidad de bajada, nº de memes, precios, kg | P0 |
| Sonidos reales (Config/Assets) | P1 |
| Configurar los IDs de los Game Passes (Config/Monetization) | P1 |

**La fase se cierra cuando el equipo lo decida**, no antes: aquí entran todas las ideas para verlas funcionando.

### El NIVEL (decidido: opciones 1 y 4)
- **Desbloquea capas de profundidad:** Charca (Nv 1) · Arrecife Meme (Nv 5) · Abismo Brainrot (Nv 15) · Fosa Abisal (Nv 30).
  Aunque tu caña baje más, la inmersión se para en la primera capa bloqueada (barrera roja con el nivel que falta).
- **Cofre al subir de nivel:** 100 + 50×nivel MemeCoins; cada 5 niveles un boost seguro de 5 min y en el resto
  un 25 % de un boost de 3 min. Si el nivel abre una capa, el cofre lo anuncia.
- En modo prueba empiezas en el nivel 30 para probar todas las capas.

### FASE 3 — Vertical slice (siguiente)
- Onboarding guiado, sonido y música, efectos de partículas finales.
- 1–2 ideas de la lista de abajo (las que elijas) bien hechas.
- Modelos de memes revisados en Blender (skill detailed-3d-modeling) si hace falta más detalle.

## Decisiones del equipo sobre las ideas (después de probar la v0.4)

**Nada de esto es para ahora**: se hará cuando el juego esté más terminado (no son prioridades del prototipo).

| Idea | Decisión | Notas | Fase |
|---|---|---|---|
| 🌦️ Clima y noche con **mutaciones** | ✅ Sí | Mojado ×2, Eléctrico ×5, Lunar ×10 | 3–4 |
| 🦈 Jefe del río | ✅ Sí | Evento global; buen sitio para memes **DIOS** | 4 |
| 🏴‍☠️ Robar memes de otras parcelas | 🤔 Más adelante | Solo si llega con defensa: **trampas** y **bate** en la mano (como Steal a Brainrot). Hace al jugador estar más activo | 5+ |
| 🪝 Cebos (picante, dorado, pesado) | ✅ Sí, más adelante | Llenan la pestaña Objetos | 4 |
| 🗺️ Zonas nuevas | 🔁 Cambiado a **capas de profundidad** | Hecho en v0.5: los memes tienen `MinDepth` (míticos desde 12 m, secretos desde 30–40 m). Más capas con su fondo y sus memes más adelante | 3–4 |
| 🐾 Mascotas | ✅ Sí, junto con **intercambio (trading)** | Mascotas = **brainrots propios** hechos con nuestros modelos de bloques (diseños originales inspirados en la cultura meme, no copias) | 4–5 |
| 🧪 Caldero de fusión | — | Sin decidir | — |
| 📜 Misiones diarias + racha | ✅ Sí | Obligatorio | 3 |
| 🏆 Torneo semanal | ✅ Sí | | 5 |
| ♻️ Renacer | ✅ Sí | Agranda la parcela y da 2–3 huecos de objetos | 5 |

### Tienda
| Idea | Decisión | Diseño |
|---|---|---|
| **Stock rotativo** | ✅ Para **monetizar**: un stock con MemeCoins y otro con Robux | Rotan cada X min, cantidades limitadas | 
| **Mercader ambulante** cada hora | ✅ Sí | Aparece en el puente con objetos raros |
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
- [ ] IDs reales de los Game Passes en `Config/Monetization` y precios iguales que en el Dashboard.
- [ ] Máximo de jugadores del servidor = 8 (una parcela cada uno).

## Historial
- **v0.8** — Tutorial jugando: muelle → caña → lanzar → meme asegurado → parcela → cobrar. Datos v5.
- **v0.7** — Freno del anzuelo, economía por peso y rareza (migración v4), gigantes/colosales, 12 mochilas, objetos con huecos (Linterna, Imán, Red Dorada) y debate de comprar memes.
- **v0.6.1** — El nivel desbloquea capas (5/15/30) y da un cofre con MemeCoins y boosts al subir.
- **v0.6** — Gran Tienda rediseñada con VIP dentro y tablón de boost gratis (15 min), profundidad hasta 600 m con 4 capas, filtros de pesca y de venta automática, cañas con diseño y efectos, arco nuevo.
- **v0.5** — Míticos y secretos con efectos, rareza Dios (eventos), capas de profundidad, Gran Tienda (boosts, Robux, regalo), fauna del río, árboles, cara del jugador en su parcela, modo prueba.
- **v0.4** — Inmersión estilo Fish an Egg, click para lanzar, río ×2 de ancho, fotos 3D, tienda nueva, animaciones.
- **v0.3** — Mapa estilo steal, caña-herramienta, mochila-acuario, ruleta, rotura de caña, figuras de bloques.
- **v0.2** — Parcelas con muelle propio y cobrador.
- **v0.1** — Prototipo: pesca, peso vs. capacidad, acuario, tienda.

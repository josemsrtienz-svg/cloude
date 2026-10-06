# PESCA DE MEMES — Estado del juego y hoja de ruta por fases

> Fuente principal del progreso (skill **roblox-game-creator**). Se actualiza en cada versión.
> Diseño completo: [`GDD_PESCA_DE_MEMES.md`](GDD_PESCA_DE_MEMES.md) · Código: [`../PescaDeMemes`](../PescaDeMemes)

```text
PROJECT:          Pesca de Memes (nombre provisional)
STATUS:           Prototipo jugable
CURRENT_PHASE:    FASE 2 — PROTOTIPO (P0)   ← ESTAMOS AQUÍ
GAME_VERSION:     P0 0.4
CORE_LOOP_STATUS: Lanzar con click → INMERSIÓN (guiar el anzuelo) → enganchar / pelear → subir → mochila → parcela → dinero
MAP_STATUS:       Río ancho (80 studs) y largo (360), 8 parcelas con muelle propio, estilo casillas con studs
SYSTEMS_STATUS:   PlayerData v3 · GearService · FishingService (inmersión) · PlotService · EconomyService · WorldBuilder
UI_STATUS:        HUD con iconos 3D · escena submarina + medidor de profundidad · pelea · resultados · tienda nueva · índice
DATA_STATUS:      Schema v3 con session lock y migraciones (v0.4 no cambia los datos)
SECURITY_STATUS:  El servidor genera la inmersión y valida cada enganche por tiempo/profundidad, anzuelos y espacio
QA_STATUS:        luau-lsp sin errores + rojo build OK · SIN PROBAR EN STUDIO (pendiente)
KNOWN_BUGS:       — (por descubrir en la prueba)
NEXT_STEP:        Probar la v0.4 en Studio (2–4 jugadores) y elegir las ideas de la sección "Ideas por decidir"
```

## Fases

| # | Fase | Objetivo | Estado |
|---|---|---|---|
| 0 | Validación | Idea, nicho, referencias | ✅ Hecho (concepto A "Pesca de Memes") |
| 1 | Preproducción | GDD, core loop, sistemas, arquitectura | ✅ Hecho (GDD v0.1 + mecánica peso/capacidad) |
| 2 | **Prototipo (P0)** | ¿Pescar es divertido 20 veces seguidas? | 🟡 **En curso** — v0.4 lista para probar |
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
| **Inmersión** (cámara bajo el agua, guiar el anzuelo, varios memes por lanzamiento), lanzar con **click**, río más ancho, **fotos 3D** en toda la GUI, **tienda nueva**, más animaciones | **v0.4** |

| Falta para cerrar la fase (P0) | Prioridad |
|---|---|
| Probar en Studio: ¿se entiende la inmersión sin explicarla? ¿apetece repetir? | P0 |
| Ajustar balance: velocidad de bajada, nº de memes, precios, kg | P0 |
| Sonidos reales (Config/Assets) | P1 |
| Tutorial de 30 s (flecha al muelle → primer lanzamiento guiado) | P1 |

**Hecho cuando:** 3–5 personas juegan 10 minutos y quieren seguir sin que nadie se lo pida.

### FASE 3 — Vertical slice (siguiente)
- Onboarding guiado, sonido y música, efectos de partículas finales.
- 1–2 ideas de la lista de abajo (las que elijas) bien hechas.
- Modelos de memes revisados en Blender (skill detailed-3d-modeling) si hace falta más detalle.

## Ideas por decidir (elige cuáles entran y en qué fase)

| # | Idea | Qué aporta | Fase propuesta |
|---|---|---|---|
| 1 | 🌦️ **Clima y noche** (lluvia, tormenta, luna llena) | Cada clima cambia qué memes salen y da **mutaciones** (Mojado ×2, Eléctrico ×5, Lunar ×10) | 3 |
| 2 | 🦈 **Jefe del río** cada 30 min | Un meme GIGANTE aparece en todas las inmersiones; todos tiran a la vez y se reparte el premio | 4 |
| 3 | 🏴‍☠️ **Robar memes** (como Steal a Brainrot) | Entrar en otra parcela y llevarte un meme; candado y alarma para defenderte | 4 |
| 4 | 🪝 **Cebos** | Picante = más épicos · Dorado = más dorados · Pesado = memes más grandes | 3 |
| 5 | 🗺️ **Zonas nuevas** | Charca del Noob → Lago Glitch → Mar Brainrot → Fosa Abisal (fondo y memes propios) | 4 |
| 6 | 🧪 **Caldero de fusión** | 3 memes iguales → versión mutada (Arcoíris, Fantasma, Gigante) | 4 |
| 7 | 🐾 **Mascota acompañante** | Imán de memes, +velocidad del anzuelo o +1 anzuelo | 4 |
| 8 | 📜 **Misiones diarias + racha** | "Pesca 3 raros", "algo de 100 kg"; regalo que crece cada día | 3 |
| 9 | 🏆 **Torneo semanal** | Ranking del meme más pesado y del dinero/min; trofeo en tu parcela | 5 |
| 10 | ♻️ **Renacer (rebirth)** | Reinicias dinero y cañas → multiplicador permanente + muelle exclusivo | 5 |

## Ideas para la tienda (v0.4 ya tiene pestañas, fotos 3D y vista previa)

1. **Stock rotativo cada 5 min** (cebos y cañas especiales en cantidad limitada): una razón para volver.
2. **Mercader ambulante** que aparece cada hora en el puente con objetos raros.
3. **Mejorar tu caña por niveles** (+kg, +anzuelo, +profundidad) además de comprar otra.
4. **Pestaña Boosts:** ×2 suerte 15 min, ×2 dinero de parcela (también se ganan jugando).
5. **Tendero NPC** animado detrás del mostrador y cañas expuestas en 3D que puedes probar.
6. **Regalo gratis cada 15 min** en la tienda (como el regalo "25m" de Fish an Egg).

## Skins de parcela y muelle (futuro — FASE 7, teaser ya visible en la tienda)

| Skin | Cómo se consigue | Bonus |
|---|---|---|
| Muelle Pirata | Comprar con MemeCoins | +10 % suerte |
| Muelle Neón | Evento nocturno | ×1.25 dinero de la parcela |
| Muelle Dorado | Evento limitado / torneo | +25 % suerte y ×1.5 dinero |

Diseño técnico previsto: `PlotSkins` y `EquippedPlotSkin` en los datos (migración v4); `Config/PlotSkins` con
paleta, accesorios y bonus; WorldBuilder pinta la parcela y el muelle con el tema; FishingService suma la suerte
y PlotService el multiplicador. Los bonus son pequeños para no romper el balance (regla de monetización ética).

## Historial
- **v0.4** — Inmersión estilo Fish an Egg, click para lanzar, río ×2 de ancho, fotos 3D, tienda nueva, animaciones.
- **v0.3** — Mapa estilo steal, caña-herramienta, mochila-acuario, ruleta, rotura de caña, figuras de bloques.
- **v0.2** — Parcelas con muelle propio y cobrador.
- **v0.1** — Prototipo: pesca, peso vs. capacidad, acuario, tienda.

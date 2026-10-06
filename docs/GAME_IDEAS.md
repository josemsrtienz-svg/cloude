# Game Idea Lab — Fase 0 (Validación)

```text
PROJECT: Nuevo juego (nombre por decidir)
STATUS: Ideación
CURRENT_PHASE: FASE 0 — VALIDACIÓN
DECISIONS: Plataforma Roblox (Rojo + Luau), mobile-first, reutilizar lo que ya existe en el repo cuando aporte
OPEN_QUESTIONS: ¿Qué concepto elegimos? ¿Partimos de MEME WARRIORS o empezamos uno nuevo?
NEXT_STEP: Elegir 1 concepto → core loop detallado → GDD corto
```

## 1. Investigación (octubre 2026)

### Datos observados
- **Steal An Egg** (salió 25 jul 2026) lidera con ~1,9 M jugadores simultáneos (27 sep), 4× el segundo puesto.
- Top 10 del 27 sep: Steal An Egg, Brookhaven RP, Ride A Pet, Murder Mystery 2, Blox Fruits, RIVALS, Steal a Brainrot, Slayers 2, Jujutsu Shenanigans, 99 Nights in the Forest.
- Los juegos "brainrot" (memes absurdos) suman ~1,4 M CCU en 29 títulos; los de escape ~763K; simuladores ~336K.
- Los simuladores idle/cozy con sesiones diarias cortas (Grow a Garden) son el género que más crece.
- La pesca (Fish It!, Hooked!) crece ~+55 % interanual.

### Interpretación
- La fórmula "**tener algo valioso + que otros te lo puedan quitar**" (Steal a Brainrot → Steal An Egg) es lo que más tracción tiene ahora mismo, pero está **muy saturada**: competir de frente es mala idea.
- Lo cozy/idle y la pesca crecen con menos competencia en lo más alto.
- El humor meme sigue funcionando como envoltorio viral.

### Hipótesis
Un híbrido que tome el **principio** del conflicto social por posesión, pero con una mecánica central distinta (pesca, defensa, cooperación), puede destacar sin parecer un clon.

### Ya tenemos en el repo
`MEME WARRIORS` (MVP 0.1): catálogo de memes con rarezas, MemeCoin, inventario, trading, tienda, habilidades, matchmaking y figuras 3D (GigaChad, etc.). Reutilizable en varias de las ideas de abajo.

## 2. Conceptos

### A. Pesca de Memes (*Meme Fishing*)
- **One-liner:** Pesca memes vivos en el "Océano de Internet" y exhíbelos en tu acuario, que genera MemeCoins.
- **Fantasía:** ser el coleccionista con el acuario más raro del servidor.
- **Mecánica central:** minijuego de pesca con timing (tensión del sedal), cebos que cambian lo que pica.
- **Core loop:** lanzar → minijuego → captura (rareza + mutación) → acuario → ingresos → mejor caña/cebo → nueva zona del océano.
- **Corto plazo:** completar la página del bestiario de la zona. **Largo plazo:** variantes míticas y mutaciones de eventos.
- **Social:** visitar acuarios, trading, eventos globales ("¡Ha aparecido un meme legendario en el Lago Cringe!").
- **Viral:** momento de "pesqué el MÍTICO" con animación grande, fácil de grabar.
- **Monetización:** caña/acuario cosmético, cebo x2 (conveniencia), servidores privados.
- **Complejidad:** media. **Riesgo:** pesca es género en crecimiento, pero hay que hacer que el minijuego sea divertido de verdad.
- **Diferenciador:** criaturas-meme con personalidad y mutaciones de clima/evento; reutiliza el catálogo existente.

### B. Museo Asaltado (*Meme Museum Heist*)
- **One-liner:** Monta tu museo de memes de día; de noche, los demás intentan robarlo y tú lo defiendes con trampas.
- **Mecánica central:** colocar trampas/guardias (tower-defense ligero) + asaltar museos ajenos en una ventana corta.
- **Core loop:** comprar/abrir cajas de memes → exponer → visitantes dan monedas → noche: defender/asaltar → mejorar trampas.
- **Social:** robar/defender, ayudar a un amigo a defender.
- **Viral:** clips de robos fallidos en trampas absurdas.
- **Complejidad:** media-alta (pathing, trampas, sincronización).
- **Riesgo:** **demasiado cercano a Steal a Brainrot/Steal An Egg**; hay que apoyarse mucho en las trampas para diferenciarse.

### C. Inundación Cringe (*Cringe Flood*)
- **One-liner:** Ronda de 3 minutos: una ola de "cringe" sube y hay que escapar trepando un mapa que cambia cada partida.
- **Mecánica central:** parkour + habilidades de meme (las que ya existen: Speed/Jump/Shield/Dash).
- **Core loop:** entrar a ronda → escapar → monedas por altura/supervivencia → nuevos memes con habilidades → rondas más difíciles.
- **Social:** cooperar (empujar/ayudar) o sabotear; espectar a los eliminados.
- **Complejidad:** media (generación modular de mapas). **Riesgo:** retención a largo plazo más floja que un simulador.
- **Diferenciador:** reutiliza casi todo MEME WARRIORS (matchmaking, habilidades, hotbar).

### D. Nubes de Bolsillo (*Pocket Clouds*) — cozy idle
- **One-liner:** Cultiva nubes en tu isla flotante y vende lluvia, nieve y tormentas a otras islas.
- **Core loop:** plantar semillas de nube → esperar/cuidar → cosechar clima → vender/combinar → nuevas nubes raras.
- **Social:** pedidos entre jugadores ("necesito nieve"), visitar islas, eventos de clima global.
- **Complejidad:** baja-media. **Riesgo:** el idle cozy depende mucho de arte bonito y de un buen ritmo de espera.
- **Diferenciador:** tema muy original; no compite con memes.

### E. Repartidores del Caos (*Chaos Couriers*) — co-op físico
- **One-liner:** Equipos de 2–4 entregan paquetes frágiles y absurdos por una ciudad con física loca antes de que acabe el tiempo.
- **Social:** cooperación pura, mucho humor emergente.
- **Complejidad:** alta (física en red en Roblox es delicada). **Riesgo:** latencia y física rota en móvil.

## 3. Puntuación (1–10)

| Criterio | A. Pesca | B. Museo | C. Flood | D. Nubes | E. Couriers |
|---|---|---|---|---|---|
| Demanda potencial | 8 | 9 | 7 | 7 | 6 |
| Originalidad | 7 | 4 | 6 | 9 | 7 |
| Claridad | 9 | 8 | 9 | 7 | 8 |
| Retención | 8 | 8 | 6 | 8 | 5 |
| Socialidad | 6 | 9 | 7 | 6 | 9 |
| Potencial de contenido | 9 | 7 | 7 | 8 | 6 |
| Monetización ética | 8 | 6 | 7 | 8 | 7 |
| Viabilidad técnica | 8 | 6 | 8 | 9 | 4 |
| Saturación (10 = poco saturado) | 7 | 2 | 6 | 8 | 7 |
| Potencial de actualización | 9 | 7 | 7 | 8 | 6 |
| **Total** | **79** | **66** | **70** | **78** | **65** |

## 4. Recomendación

**A. Pesca de Memes**, con un toque social ligero de B: tu acuario puede recibir "pescadores furtivos" en eventos puntuales (no constantes), así aprovechamos la tensión social que funciona ahora sin ser un clon.

**Trade-offs**
- **A frente a D:** casi empatan. A reutiliza el catálogo de memes, MemeCoin, inventario y trading que ya tenemos y se apoya en dos tendencias (brainrot + pesca). D es más original pero empieza de cero en arte y sistemas.
- **B** tiene la mayor demanda, pero es el nicho más saturado y el más fácil de ver como copia.
- **C** es el más rápido de construir sobre MEME WARRIORS, pero retiene peor.

**Prototipo mínimo si elegimos A:** una zona de agua, un minijuego de pesca, 8 memes en 4 rarezas, un acuario con 6 huecos que genera monedas y una mejora de caña. La única pregunta que tiene que responder: *¿pescar es divertido 20 veces seguidas?*

## Fuentes
- [Steal a Brainrot — Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)
- [Top Roblox Games September 2026 — StudioKrew](https://studiokrew.com/blog/top-roblox-games-september-2026/)
- [Best Roblox Games Sept–Oct 2026 — Playnews](https://www.playnews.gg/en/guides/roblox-10-third-party-games-highlighted-for-fall-2026-from-september-to-october)
- [Roblox Game Genres and Popularity 2026 — ExitLag](https://www.exitlag.com/blog/roblox-game-genres-and-popularity/)
- [Q1 2026 market trends — rolearn.dev](https://rolearn.dev/trend-reports/q1-2026-market-trends)
- [Roblox hit 12M concurrent players — RoWatcher](https://rowatcher.com/news/roblox-hit-12-million-concurrent-players-where-are-they-all-playing)

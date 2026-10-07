# PESCA DE MEMES — GDD v0.1

```text
PROJECT: Pesca de Memes (nombre provisional)
STATUS: Prototipo
CURRENT_PHASE: FASE 2 — PROTOTIPO (P0)
GAME_VERSION: P0 0.6 (carpeta PescaDeMemes/) — estado detallado y fases en GAME_STATE.md
CORE_LOOP_STATUS: Implementado (click → inmersión guiando el anzuelo → peso/capacidad + tirones → mochila → parcela); falta probar con jugadores
MAP_STATUS: Mapa "en fila" estilo steal: río central ancho (80 studs), 4 parcelas por lado con muelle propio, casillas con studs
SYSTEMS_STATUS: PlayerData (schema v3), GearService, FishingService, PlotService, EconomyService
UI_STATUS: HUD con iconos 3D, escena submarina + medidor, pelea, resultados, mochila, tienda con pestañas y vista previa, índice
DATA_STATUS: Schema v1 con session lock y migraciones
SECURITY_STATUS: Servidor genera la inmersión y valida cada enganche (tiempo/profundidad, anzuelos, espacio); riesgo conocido: resultado de la pelea lo informa el cliente
QA_STATUS: Análisis estático (luau-lsp) y rojo build OK; sin probar en Studio
DECISIONS: Concepto A elegido (ver GAME_IDEAS.md); mobile-first; servidor con autoridad total sobre capturas y monedas
OPEN_QUESTIONS: ver sección 15
NEXT_STEP: Probar la v0.4 en Roblox Studio con 3–5 personas, ajustar balance y elegir ideas (GAME_STATE.md)
```

## 1. High concept
**Pesca memes vivos en el Océano de Internet, colecciónalos en tu acuario y hazlo el más raro del servidor.**

- **Fantasía:** ser el pescador legendario que sacó al Dios de los Memes del fondo del océano.
- **Género:** simulador de pesca + colección + idle ligero.
- **Público:** 9–16 años, mobile-first (también PC/consola).
- **Referencias (solo principios):** juegos de pesca (tensión del timing, emoción de "¿qué ha picado?"), juegos de colección (bestiario, rarezas), juegos de "steal" (el valor social de poseer algo raro).

## 2. Loops

**Micro loop (5–15 s):** lanzar → esperar picada → minijuego de tensión → captura o se escapa.

**Core loop (sesión):**
```
PESCAR → CAPTURA (rareza + mutación) → ACUARIO o VENDER → MemeCoins
   ↑                                                         ↓
NUEVA ZONA / CEBO ← MEJOR CAÑA ←───────────────────── COMPRAR MEJORAS
```

**Meta loop (días/semanas):** completar el bestiario de cada zona, conseguir mutaciones de evento, subir la "Fama" del acuario, desbloquear zonas profundas.

**Social loop:** visitar acuarios ajenos y dar "like" (Fama), intercambiar capturas, eventos globales del servidor ("¡Tormenta de Glitch! +rarezas 5 min"), y eventos puntuales de **Pescadores Furtivos** (sección 6).

## 3. Mecánica principal — el minijuego
Tiene que ser divertido sin mejoras y fácil de jugar en móvil con un solo dedo.

1. **Lanzar:** mantener pulsado = distancia (más lejos = algo más de rareza).
2. **Picada:** el corcho se hunde → hay 0,6 s para tocar (si fallas, se escapa).
3. **Tensión:** barra horizontal con una **zona verde** que se mueve. Mantener pulsado sube la tensión y soltar la baja. Mientras el indicador esté en verde, se llena el **progreso**; fuera, se vacía. Si llega al rojo, se rompe el sedal.
4. Cada meme tiene **"personalidad"** que cambia cómo se mueve la zona verde:
   - *Perro Bonk:* tirones bruscos.
   - *Gato Pianista:* movimiento rítmico (siguiendo una melodía).
   - *El Sospechoso:* se queda quieto… y luego da un salto.
   - *GigaChad:* zona verde enorme pero tira con muchísima fuerza.

   Esto convierte cada captura nueva en algo que **aprender** y no solo en un número más alto.

### 3b. Peso del meme vs. capacidad de la caña (idea del equipo)
Cada captura tiene un **peso en kg** y cada caña una **capacidad máxima**.

**Sobrecarga** `r = peso / capacidad`

**Probabilidad de que el sedal aguante** (valores iniciales):

| r | Situación | Aguante |
|---|---|---|
| ≤ 1,0 | Dentro de capacidad | 100 % (solo depende de tu habilidad) |
| 1,25 | Algo pesado | ~41 % |
| 1,5 | Pesado | ~20 % |
| 2 | Muy pesado | ~6 % |
| 3 | Bestia | ~1 % |
| 5 | Imposible… casi | ~0,1 % (mínimo) |
| > 5 | Demasiado pesado | El sedal se rompe en la picada |

Fórmula: `aguante = max(0,001, (1/r)^4)` si `r > 1`.

**Cómo se juega:**
1. Al picar se muestra `⚖️ ~87 kg / 🎣 40 kg` y la barra de **Aguante del sedal** con su %. El peso exacto se ve al pescarlo; antes es una estimación de ±10 %.
2. Decisión: **PELEAR** o **SOLTAR** (cortas el sedal y no pierdes el cebo).
3. Si hay sobrecarga, el meme da **3 tirones fuertes** durante la pelea. En cada uno el servidor tira dados con `aguante^(1/3)`. Si en ese momento tu indicador está en la zona verde, ese tirón tiene ×1,5 de probabilidad (máximo 95 %). Así la suerte importa, pero jugar bien también.
4. Con sobrecarga la zona verde se hace más estrecha y el meme empuja más fuerte (escala con `r`).
5. Si sale bien: aviso a todo el servidor (*"¡Pescó 260 kg con una Caña de Palo!"*) + insignia **"Imposible"** en la captura.

**Rangos de peso (iniciales):** Común 1–8 kg · Poco común 5–25 · Raro 20–80 · Épico 60–250 · Legendario 200–900 · Mítico 800–3.000. El tamaño (S…Gigante) sale del peso dentro de su rango.

**Consumible "Sedal Reforzado":** +25 % de capacidad durante un lanzamiento. Se gana jugando y en la tienda con MemeCoins.

## 4. Coleccionables
Reutilizamos los 16 memes de `MemeCatalog` como la primera tanda de "peces", repartidos por zona.

**Rarezas:** COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC (las mismas que ya existen).

**Peso / tamaño:** cada captura sale con un tamaño aleatorio (S, M, L, XL, **Gigante**) que multiplica el valor y queda bien en el acuario.

**Mutaciones** (pocas y legibles):

| Mutación | Cómo sale | Efecto visual | Valor |
|---|---|---|---|
| Dorado | 1 % siempre | Brillo dorado | ×3 |
| Glitch | Evento "Tormenta de Glitch" | Parpadeo RGB | ×5 |
| Pixelado | Cebo "8-bit" | Low-poly | ×2 |
| Fantasma | De noche en zona 3+ | Transparente | ×4 |

**Bestiario:** cuadrícula por zona; descubrir un meme da XP y completar una zona da un premio único (cosmético de caña).

## 5. Progresión
- **Cañas** (vertical, cada una cambia algo): **capacidad de peso** + un efecto propio.

| Caña | Capacidad | Efecto |
|---|---|---|
| Caña de Palo | 10 kg | — |
| Caña de Fibra | 40 kg | Zona verde más ancha |
| Caña Turbo | 120 kg | Progreso más rápido |
| Caña Abisal | 400 kg | Pesca en aguas profundas |
| Caña Legendaria | 1.500 kg | +suerte, aguanta más el rojo |
- **Cebos** (horizontal): cambian *qué* pica, no solo cuánto (cebo "Wifi" → memes de internet; cebo "8-bit" → Pixelado).
- **Zonas** (desbloqueo por nivel + MemeCoins):

| # | Zona | Identidad | Memes destacados | Desbloqueo (valor inicial) |
|---|---|---|---|---|
| 1 | Charca del Noob | Muelle soleado, tutorial | Noob Feliz, Perro Bonk, Stonks | — |
| 2 | Lago Cringe | Neón rosa, carteles | Cara Troll, Pato Infinito, Gato Pianista | Nv 5 · 2.500 |
| 3 | Pantano del Ogro | Niebla, noche | Ogro del Pantano, Rana Triste, Moai | Nv 12 · 15.000 |
| 4 | Fosa del Algoritmo | Fondo oscuro, cables | GigaChad, Héroe Calvo, Gato Arcoíris | Nv 20 · 80.000 |
| 5 | Abismo 404 | Glitch, sin gravedad | Inodoro Cantante, Dios de los Memes | Nv 30 · 400.000 |

- **Fama del acuario:** sube con likes de visitantes y con la colección expuesta → desbloquea decoración y un puesto en el ranking del servidor.
- **Rebirth (post-MVP):** "Nueva Temporada de Pesca", que reinicia monedas y zonas a cambio de un multiplicador permanente y una caña exclusiva.

## 5b. Parcelas (cambio v0.2, idea del equipo)
Inspirado en el principio de Steal a Egg ("tu base es tuya y se ve"), con aplicación propia:
- 8 parcelas alrededor de la charca, mirando al agua, cada una con **su propio muelle** para pescar.
- Al entrar se te asigna una; apareces en ella y el cartel dice "Parcela de TuNombre".
- Pescas → **🏠 Llevar** → el meme flota sobre tu cabeza (no puedes pescar mientras) → lo colocas en uno de los **8 pedestales**.
- Los memes expuestos se ven para todos y generan MemeCoins que se acumulan en el **cobrador** (se cobra pisándolo).
- Sustituye al acuario (migración de datos v1 → v2 automática).
- Preparado para el futuro "robo": los pedestales ya tienen prompt; hoy el cliente oculta los de otras parcelas y el servidor rechaza usarlos.

## 5c. Cambios v0.3 (referencia: captura estilo Steal a Brainrot + Fish an Egg)
- Mapa en fila con río; estilo casillas con studs, paredes de tierra, valla en X; GUI como la referencia.
- Memes expuestos como **figuras de bloques** sobre el césped (sin estantes), con "+🪙X/min".
- Caña = **herramienta** (slot 1). Solo se pesca desde **tu muelle**.
- **Mochila-acuario** con capacidad en kg (tamaño = peso). Se descarga sola al entrar en tu parcela. Tiers 25 → 2.500 kg.
- **Ruleta** de posibles memes al lanzar.
- Perder: el sedal sube rápido. Fallar un TIRÓN con sobrecarga **rompe la caña** (reparación en tienda; Palo irrompible).

## 5d. Cambios v0.4 (referencia: captura de Fish an Egg — "la animación es esto")
- **Inmersión:** al lanzar, la cámara se mete bajo el agua (escena privada de cada jugador). El anzuelo baja solo
  y lo **guías** con A/D, ratón o dedo hacia los memes, que flotan con su **rareza y kg** encima
  (verde = se engancha · naranja ⚔️ = pelea · rojo ⛔ = demasiado pesado). Medidor de profundidad a la derecha.
- **Cañas = anzuelos + profundidad:** Palo 1 anzuelo/15 m · Fibra 2/25 m · Turbo 3/40 m · Abisal 4/60 m.
  Más hondo = más suerte (las rarezas altas viven abajo).
- **Peso vs. capacidad se mantiene:** si pesa más que tu caña → PELEAR o SOLTAR (y seguir bajando).
  Perder la pelea = el sedal **sube de golpe** (fin de la inmersión, te quedas lo que ya tenías); fallar un tirón
  **rompe la caña** (salvo la de palo).
- **Lanzar con click** (mantener = fuerza; zona dorada = PERFECTO, más suerte). Sin botón LANZAR.
- **Río el doble de ancho** (80 studs) y más largo (360): muelles largos que no chocan entre sí.
- **GUI sin emojis en los objetos:** figuras 3D (ViewportFrame) de memes y equipo en acuario, parcela, tienda,
  índice (silueta si no lo has descubierto), resultados y HUD. Mochila con **mini memes de verdad** dentro.
- **Tienda nueva:** pestañas (Cañas, Mochilas, Objetos, Muelles), cartas con foto 3D y vista previa grande que gira
  con barras de Capacidad / Profundidad / Anzuelos / Suerte. Pestaña Muelles = teaser de las skins de parcela.
- **Animaciones:** latigazo del brazo al lanzar, chapuzón con gotas, memes nadando y balanceándose, sedal que sube,
  memes que saltan del agua a tu mochila, memes de la parcela botando, lluvia de monedas al cobrar, dinero que cuenta.

## 5e. Cambios v0.5 (tras probar la v0.4: sin errores)
- **Rarezas:** Común → Poco común → Raro → Épico → Mítico → Legendario → Secreto → **Dios** (solo eventos).
- **6 memes nuevos con efectos** (partículas, luz, aura arcoíris en los secretos): Gato Pop, Plátano Bailarín,
  Hámster Dramático (míticos) · Tiburón Zapatillero, Capibara Zen, Cocodrilo Aviador (secretos).
- **Capas de profundidad** en vez de zonas separadas: cada meme tiene `MinDepth`; lo difícil vive en el fondo.
- **Gran Tienda física** = destino del mapa: tendero animado, puesto VIP (Robux), pedestal del **boost gratis**
  (reloj aleatorio por jugador, 9–20 min). La tienda del HUD solo vende Cañas/Mochilas/Objetos.
- **Boosts** (Dinero ×2, Suerte ×1.5, 5 min) y **Game Passes** configurables (VIP, Suerte Eterna, +1 Anzuelo).
- **Mapa con vida:** peces que saltan, delfines, patos, gaviotas, árboles de bloques, flores, bancos.
- **Cara del jugador** (avatar) sobre el cartel de su parcela.
- **Modo prueba** (solo Studio): dinero infinito y no se guarda. Se apaga antes de publicar.

## 5f. Cambios v0.6
- **Fase 2 abierta:** el prototipo es donde se meten y prueban TODAS las ideas.
- **Gran Tienda** al fondo del eje del río (el arco la enmarca): mercado grande con columnas, tejado a rayas,
  bombillas, tendero, estanterías y **rincón VIP (Robux) dentro**. Fuera, el **tablón del boost gratis**:
  cambia cada 15 min (igual para todo el servidor), se recoge una vez por ronda y dura 5 min.
- **Boosts:** Dinero ×2, Suerte ×2, Anzuelo ×1.5 (baja más rápido), +1 Anzuelo.
- **Profundidad ×10:** Palo 50 m · Fibra 150 m · Turbo 300 m · Abisal 600 m. **Capas** (Charca, Arrecife Meme,
  Abismo Brainrot, Fosa Abisal) con su color, más oscuras al bajar; la Fosa brilla. Para eventos (p. ej. tóxico)
  basta con cambiar los colores de una capa en `GameConfig.DepthLayers`.
- **Filtros** (en el acuario o con ⚙️ junto a la caña): el anzuelo **ignora** rarezas y/o se **venden solas** al subir
  (no ocupan sitio; los dorados nunca se venden solos).
- **Cañas con identidad:** Palo (rama con nudos y hoja), Fibra (carbono azul), Turbo (rayos y chispas),
  Abisal (runas y esfera que brilla con niebla morada).
- **Arco "PESCA DE MEMES"** de piedra, cartel por las dos caras, bombillas y un pez gigante encima.

## 5g. Cambios v0.7
- **Freno del anzuelo:** mantén **S / ↓ / click o dedo** y baja a 3 m/s para enganchar el meme que ves.
- **Economía nueva:** valor = `ValorBase(rareza) × (peso / peso medio)^0.85` (× 3 si es dorado). Bases:
  40 / 150 / 600 / 2.500 / 9.000 / 25.000 / 200.000 (secreto) / 2.000.000 (dios). La parcela paga el **25 %** del valor
  por minuto (un Noob Feliz normal ≈ 10/min, antes 0,9). Los memes guardados se recalculan (migración v4).
- **Ejemplares gigantes:** 4 % de **GIGANTE** (×1,3–×5 de peso) y **COLOSAL** a partir de ×2,5 (anuncio a todo el servidor).
  Se ven más grandes (escala ∛peso, con tope 0,75–2,1 para no romper la parcela).
- **12 mochilas** con diseño propio a la espalda (frasco, pecera, tanque, barril, globo, submarino, cofre, cohete,
  neón, real, cósmica y agujero negro): de 25 kg a 350.000 kg. Un secreto ocupa media mochila de las intermedias.
- **Objetos con huecos:** 1 hueco al empezar (+1 con el pase *Hueco Extra*; el **renacer** dará más). Se elige qué se
  lleva desde la pestaña Objetos:
  - 🧵 **Sedal Reforzado** (consumible): +25 % de capacidad de la caña en un lanzamiento.
  - 🔦 **Linterna** (equipo): en las capas oscuras (Abismo, Fosa) sin linterna los memes son siluetas "???".
  - 🧲 **Imán** (equipo): radio de enganche ×1,2.
  - 🥅 **Red Dorada** (consumible): atrapa sin pelear (no sirve con secretos).
- **Futuro (decidido):** el **renacer** agranda la parcela y da huecos de objetos (2–3); quizá **cañas nuevas**.

### Debate: ¿comprar un meme para pelear o saltarse la pelea con Robux?
- **A favor de comprarlo con MemeCoins y pelear:** da un sumidero de dinero para el late game y mantiene la habilidad.
- **En contra:** si puedes comprar un secreto, pescarlo deja de ser especial (mata el "¡me tocó!") y la tienda se
  vuelve un catálogo. Mejor como **evento**: un *Mercader ambulante* con 1 meme raro, precio alto y stock 1 por servidor.
- **Saltarse la pelea con Robux / pase:** riesgo de *pay-to-win*. Decisión propuesta: la **Red Dorada** (MemeCoins)
  es el "salto", **nunca para secretos ni dioses**; con Robux solo packs de Red Dorada (producto de desarrollador),
  nunca un pase permanente.

## 6. Pescadores Furtivos (el toque social)
Para tener tensión social **sin** convertirlo en un clon de "steal":

- Solo durante un **evento de 3 minutos** cada ~20 minutos (no en todo momento).
- Durante el evento, los jugadores pueden entrar en acuarios ajenos e intentar llevarse **una** captura que **no esté protegida**.
- Cada acuario tiene **3 huecos protegidos** gratis: tus favoritos nunca se pierden.
- El dueño puede defender con un minijuego rápido (atrapar con red) y gana MemeCoins si echa al furtivo.
- Se puede desactivar con un ajuste "Modo Tranquilo": no te roban, pero tampoco puedes robar.

Riesgo vigilado: frustración de jugadores nuevos → los acuarios de nivel < 10 son inmunes.

## 7. Economía (valores iniciales de balance, no definitivos)

| Sistema | Entra | Sale | Riesgo |
|---|---|---|---|
| Vender capturas | Capturas | MemeCoins | Farm con macros → minijuego y cooldown en servidor |
| Acuario idle | Capturas expuestas | MemeCoins/min (límite 8 h offline) | Inflación → tope offline |
| Cañas / cebos | MemeCoins | Poder / acceso | Power creep → cada caña cambia mecánica, no solo stats |
| Zonas | MemeCoins + nivel | Acceso | Muro de progresión → ajustar con telemetría |
| Decoración | MemeCoins | Fama/cosmético | Sumidero sano |
| Trading | Captura ↔ captura | — | Estafas/dupes → reutilizar Trading.lua con confirmación doble |

**Valor de venta** (v0.7) = `ValorBase(rareza) × (peso / peso medio)^0.85 × Dorado × Mutación`. Bases: 40 / 150 / 600 / 2.500 / 9.000 / 25.000 / 200.000 / 2.000.000.

**Ingreso de la parcela** = 25 % del valor de venta por minuto de cada meme expuesto (8 pedestales).

## 8. Player journey
- **0–10 s:** apareces en el muelle con la caña en la mano y un corcho brillante delante. Texto: "Mantén para lanzar".
- **Primer minuto:** primera captura garantizada (Noob Feliz) + animación grande + "¡Ponlo en tu acuario!" con una flecha.
- **5 minutos:** has vendido algo, comprado el primer cebo, tienes 3 capturas en el acuario generando monedas y ves en el bestiario que te faltan 4 en la Charca.
- **Primera sesión (~20 min):** llegas al nivel 5 → desbloqueas el Lago Cringe. Has vivido un evento global.
- **Volver mañana:** el acuario ha generado dinero offline, hay una "pesca del día" (meme con bonus) y un evento de mutación con horario.

## 9. Mapa (MVP + ampliación)
Hub central (muelle + tienda + tablero de eventos + portal de acuarios) → zonas alrededor como islas conectadas por un barco/teleport. Cada isla tiene un muelle principal y 2–3 puntos de pesca "secretos" con mejor suerte. Los acuarios son parcelas privadas (como los "plots"), una por jugador, a las que se accede desde el portal.

Usaremos la skill **crear-estructuras-para-roblox** al diseñar el mapa y **detailed-3d-modeling** para los modelos de los memes (siguiendo lo hecho con GigaChad en `V2MMW/Blender`).

## 10. UI (mobile-first)
- **HUD:** MemeCoins (arriba), nivel/XP, botón grande "Lanzar" (abajo a la derecha), mochila de capturas (abajo a la izquierda).
- **Minijuego:** barra de tensión grande centrada abajo; todo con un solo dedo.
- **Captura:** tarjeta con rareza, tamaño y mutación + botones **Acuario / Vender / Guardar**.
- **Paneles:** Bestiario, Tienda (cañas, cebos), Acuario (huecos + decoración), Ajustes.
- Se reutilizan `UIKit`, `HUD`, `ShopPanel`, `InventoryPanel`, `TradePanel`, `SettingsPanel`.

## 11. Arquitectura y reutilización

| Sistema | Estado |
|---|---|
| PlayerData (guardado, versionado) | **Reutilizar** + migración de schema v2 |
| MemeCoin | **Reutilizar** |
| Inventory | **Adaptar**: capturas únicas (id, memeId, tamaño, mutación) en vez de contadores |
| Trading | **Adaptar** a capturas únicas |
| Shop | **Adaptar**: cañas y cebos |
| MemeCatalog | **Ampliar**: Zone, FishBehavior, Weight |
| FishingService | **Nuevo** (servidor) |
| AquariumService | **Nuevo** (servidor) |
| EventService | **Nuevo** (eventos globales + furtivos) |
| FishingController | **Nuevo** (cliente: animación, minijuego, cámara) |
| Matchmaking / MatchService / Abilities | **No se usan** en este juego |

**Seguridad (regla de oro):** el servidor decide qué pica (tirada de rareza en servidor), el cliente solo envía "lancé" / "toqué" / "terminé el minijuego". El servidor comprueba los tiempos (no se puede terminar un minijuego en menos de X s), los cooldowns, la distancia al agua y la zona desbloqueada. Las capturas se crean solo en el servidor con un id único → no hay duplicados.

```
Cliente: CastRequest(power)          → Servidor: valida zona/cooldown, elige meme, guarda "pesca pendiente"
Servidor: BiteNotify(fishBehavior)    → Cliente: corre el minijuego
Cliente: ReelResult(success, tiempo)  → Servidor: valida tiempo mínimo/máximo, crea captura, da XP
```

## 12. Monetización (ética)
- **Game pass "Caja de Aparejos":** +3 huecos de mochila y skin de caña (comodidad, no poder).
- **Cebo de la Suerte ×2 (15 min):** conveniencia; también se puede ganar jugando.
- **Skins de caña/acuario y emotes de captura.**
- **Servidores privados** para pescar con amigos.
- Nada de "comprar el mítico". Las capturas no se venden por Robux.

## 13. MVP / Prototipo (P0)
La pregunta que tiene que responder: **¿pescar es divertido 20 veces seguidas?**

| Incluye | No incluye (todavía) |
|---|---|
| 1 zona (Charca del Noob) | Otras zonas |
| Minijuego completo con 3 personalidades | Mutaciones de evento |
| 8 memes en 4 rarezas + tamaños | Trading, furtivos |
| Acuario con 6 huecos + ingreso | Decoración, fama |
| Vender + 2 cañas + 1 cebo | Monetización |
| Guardado básico | Rebirth |

**Hecho cuando:** 3–5 personas prueban 10 minutos y quieren seguir pescando sin que nadie se lo pida.

## 14. Roadmap

| Fase | Objetivo | Hecho cuando |
|---|---|---|
| P0 Prototipo | Minijuego divertido | Prueba con jugadores reales positiva |
| P1 Vertical slice | Zona 1–2 con arte final, acuario, bestiario | Una sesión de 20 min se siente "juego" |
| P1 Alpha | 5 zonas, tienda, eventos, trading | Todos los sistemas funcionan |
| P2 Beta | Furtivos, balance, móvil, QA | Sin bugs críticos; D1 objetivo ≥ 25 % |
| P2 Release | Onboarding, icono/thumbnail, monetización | Publicado |
| P3 Live ops | Zona nueva cada ~3 semanas, eventos de mutación | — |

> **v0.4:** la hoja de ruta detallada, en qué fase estamos, las 10 ideas por decidir, las ideas de la tienda
> y el plan de skins de muelle están en [`GAME_STATE.md`](GAME_STATE.md).

## 15. Preguntas abiertas
1. **Nombre final** (ideas: *Meme Fishing*, *Pesca de Memes*, *Fish a Meme*, *Brainrot Bay*).
2. ¿Proyecto nuevo en el repo o reconvertir MEME WARRIORS? Recomendación: **carpeta nueva** que copie los sistemas reutilizables, para no romper lo que ya funciona.
3. ¿Idioma del juego: español, inglés o ambos? (El público grande de Roblox está en inglés.)
4. ¿Modelos 3D propios (Blender) para cada meme o tarjetas/imágenes en el MVP? Recomendación: **formas simples** en el prototipo y modelos de verdad en el vertical slice.

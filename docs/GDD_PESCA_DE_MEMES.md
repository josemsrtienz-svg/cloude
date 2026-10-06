# PESCA DE MEMES — GDD v0.1

```text
PROJECT: Pesca de Memes (nombre provisional)
STATUS: Preproducción
CURRENT_PHASE: FASE 1 — PREPRODUCCIÓN
GAME_VERSION: —
CORE_LOOP_STATUS: Diseñado (sin probar)
MAP_STATUS: Esquema de zonas
SYSTEMS_STATUS: Lista de sistemas + qué se reutiliza de MEME WARRIORS
UI_STATUS: Pendiente
DATA_STATUS: Esquema propuesto
SECURITY_STATUS: Reglas definidas
QA_STATUS: —
DECISIONS: Concepto A elegido (ver GAME_IDEAS.md); mobile-first; servidor con autoridad total sobre capturas y monedas
OPEN_QUESTIONS: ver sección 15
NEXT_STEP: Prototipo P0 — minijuego de pesca + acuario (sección 13)
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
- **Cañas** (vertical, cada una cambia algo): más ancho de zona verde, más resistencia o más suerte. La caña nº 4, por ejemplo, permite pescar en aguas profundas.
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

**Valor de venta** = `ValorBase(rareza) × Tamaño × Mutación`. Valores base iniciales: 10 / 40 / 150 / 600 / 3.000 / 20.000.

**Ingreso del acuario** = 2 % del valor de venta por minuto de cada captura expuesta (solo 6 huecos al empezar, ampliables).

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

## 15. Preguntas abiertas
1. **Nombre final** (ideas: *Meme Fishing*, *Pesca de Memes*, *Fish a Meme*, *Brainrot Bay*).
2. ¿Proyecto nuevo en el repo o reconvertir MEME WARRIORS? Recomendación: **carpeta nueva** que copie los sistemas reutilizables, para no romper lo que ya funciona.
3. ¿Idioma del juego: español, inglés o ambos? (El público grande de Roblox está en inglés.)
4. ¿Modelos 3D propios (Blender) para cada meme o tarjetas/imágenes en el MVP? Recomendación: **formas simples** en el prototipo y modelos de verdad en el vertical slice.

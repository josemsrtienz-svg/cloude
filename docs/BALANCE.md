# Balance — Pesca de Memes (Fase 3 · VS 0.2)

Simulador: [`PescaDeMemes/tools/balance_sim.py`](../PescaDeMemes/tools/balance_sim.py). Es una réplica en Python de la
generación de la inmersión, la tirada de rareza, el peso, el valor, los anzuelos, las capas por nivel y la XP.

```
python3 PescaDeMemes/tools/balance_sim.py <ingreso_parcela> <precios separados por comas>
```

Modelo del jugador:
- va a por los memes más valiosos que puede sacar (hasta 1,5× la capacidad de su caña);
- gana el 75 % de las peleas;
- se le escapa el 15 % de los memes.

Es un jugador bastante bueno, así que los tiempos reales serán aproximadamente ×1,5–2.

## Problema encontrado (v0.9)
- La Caña Abisal (secretos) se conseguía en unos **15 minutos**.
- La parcela pagaba el 25 % del valor por minuto, casi tanto como pescar.
- Toda la progresión barata se quemaba en la primera sesión.

## Cambios (VS 0.2)

| Qué | Antes | Ahora |
|---|---|---|
| Ingreso de la parcela | 25 %/min del valor | **8 %/min** (un meme "paga" su valor en ~12 min) |
| XP por nivel | 60 + 40·(n−1) | 60 + 40·(n−1) **+ 4·(n−1)²** |
| Precios de cañas | 1,5K … 900M | 2,5K … 1.200M (tabla) · reparación = 20 % del precio |

## Ritmo resultante (jugador bueno)

| Caña | Precio | Minutos hasta la siguiente |
|---|---|---|
| Palo → Bambú | 400 | ~1 |
| Bambú → Fibra | 2.500 | ~2 |
| Fibra → Pirata | 12.000 | ~5 |
| Pirata → Turbo | 40.000 | ~3 |
| Turbo → Coral | 120.000 | ~6 |
| Coral → Abisal | 400.000 | ~20 |
| Abisal → Glaciar | 1,2M | ~19 |
| Glaciar → Volcánica | 3M | ~36 |
| … → Dragón | 18M | ~1,5 h |
| … → Galáctica / Arcoíris | 45M / 100M | 3–6 h |
| … → Diamante / Brainrot / Divina | 220M / 500M / 1.200M | 10–20 h cada una |

- La **Abisal** llega en unos 40 minutos.
- Entre la **Volcánica** y la **CyberNeon** pasan unas 2 horas.
- La **Divina** cuesta unas 44 h en total: es la meta de muchas sesiones, y más adelante el renacer acelerará el camino.

## Pendiente de validar en el playtest (tarea 6)
- Tiempos reales con jugadores nuevos frente a la simulación.
- Precios de las mochilas, que no están simulados (el sitio en la mochila no se modela).
- Premios de las misiones a nivel alto, que escalan con el nivel.

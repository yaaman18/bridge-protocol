# Bridge Protocol
### Una prueba indeterminada del mundo fenomenológico derivada de axiomas

[English](README.md) | [日本語](README.ja.md) | **Español**

`Bridge` viene de `DCWorldBridge` (WorldDC.lean) y `bridgeOpen` (Gate.lean) — los tipos Lean que conectan el automantenimiento con el surgimiento del mundo. La compuerta fenomenológica es siempre `bridgeOpen`; nunca puede ser `pass`.

---

## Qué es este repositorio

Bridge Protocol es un protocolo para construir una teoría categórica de
sistemas que se automantienen y verificarla mecánicamente:

```
discusión informal → especificación categórica → demostraciones en Lean 4 → implementación en Julia
```

Las estructuras centrales de la teoría:

- **Adjunción sensoriomotriz `α ⊣ σ`** — una conexión de Galois entre actuar y
  sentir. Lo que un sistema puede tocar y lo que le devuelve el tacto son dos
  caras de una misma estructura.
- **Clausura `Φ` y su máximo punto fijo `νΦ`** — el automantenimiento se formaliza
  como un punto fijo *máximo*, es decir, seguir siendo viable, **no** maximizar
  nada.
- **Condición de bisagra `Act ≠ ∅`** — siempre existe al menos una acción
  disponible; el sistema nunca queda sellado respecto de su mundo.
- **Certificado de automantenimiento `DC`** — un testigo verificable por máquina
  de que un sistema se mantiene a sí mismo bajo su propia dinámica.
- **Mundo enactuado `Wld`** — el mundo *para* un sistema, que surge del ciclo de
  movimiento y sensación en lugar de venir dado desde fuera. Cambia el cuerpo y
  cambia el mundo.

Todo el proyecto obedece una estricta disciplina de dos capas: los sistemas
individuales viven en la **capa de objetos** (sujeta a los requisitos
estructurales M1–M4), mientras que cualquier supuesto orientado a la evolución o
la selección se inyecta únicamente en una **capa meta** separada, y nunca se
reescribe dentro de los individuos.

## Lo que este proyecto *no* afirma

Esta sección es tan importante como la teoría misma.

- **No se afirma consciencia.** Aunque la descripción estructural se complete y se
  verifique por completo, si «hay una luz encendida dentro» — si existe
  experiencia subjetiva — no puede demostrarse desde fuera. La teoría deja esa
  pregunta sin responder, fuera de la descripción, como una posibilidad. Esta
  honestidad se impone mecánicamente: el marcador
  `phenomenal_claim = :not_certified` forma parte de la cadena de artefactos
  certificados y, por diseño, ninguna demostración lo promueve jamás.
- **No hay relato de optimización.** El mantenimiento es un máximo punto fijo, no
  una recompensa que maximizar. La capa de objetos prohíbe los set points
  externos y los objetos terminales alcanzables (requisito M4).
- **No hay identificaciones silenciosas.** La viabilidad de sistemas abiertos
  (`viable`) y el certificado de automantenimiento de ERIE-C (`DC`) se mantienen
  distintos; su equivalencia no está demostrada y nunca se asume.

## Metodología de verificación

Cada afirmación matemática de este repositorio se registra como un **punto de
verificación** (VP) en un único libro mayor, [specs/ledger.toml](specs/ledger.toml),
y avanza por estados con compuertas:

```
proposed ──G1──▶ formalized ──G2──▶ bound ──G3──▶ implemented ──G4──▶ certified
```

- **G1** — la formalización en Lean 4 pasa el typecheck (`lake build`, sin `sorry`).
- **G2** — la declaración Lean queda ligada a un símbolo Julia mediante un test de contrato.
- **G3** — la implementación Julia pasa sus tests.
- **G4** — el contrato queda registrado en el catálogo de certificados y su grafo
  de dependencias se verifica.

Dos reglas dan sentido al libro mayor. Primera: una afirmación se marca
`certified` **solo** cuando existen registros reales de compuertas bajo
[logs/gates/](logs/gates/) — esos registros se incluyen como evidencia. Segunda:
el *principio de brecha visible*: una afirmación con motivación categórica pero
sin demostración en Lean permanece visiblemente por debajo de `certified`; nunca
se elimina ni se acepta en silencio.

A fecha de 2026-07-11, el libro mayor registra 47 puntos de verificación, de los
cuales 45 están certificados y 2 son propuestas abiertas.

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| [formal/ERIEC/](formal/ERIEC/) | Formalización en Lean 4 (47 módulos: adjunción, clausura, bisagra, DC, linaje, riqueza, generación, …) |
| [src/](src/) | Implementación de referencia en Julia (paquete `ERIEC.jl`) |
| [test/](test/) | Tests de Julia, incluido el test de contrato Lean–Julia |
| [specs/](specs/) | Libro mayor de puntos de verificación y statements congelados |
| [category/](category/) | Documentos de trabajo categóricos |
| [docs/](docs/) | Visión general de la teoría, requisitos, documentos de diseño |
| [logs/gates/](logs/gates/) | Registros de evidencia de compuertas (salida de build/test que respalda cada `certified`) |

La mayoría de los documentos de trabajo en `docs/` y `category/` están escritos en
japonés; las fuentes Lean y Julia son el núcleo independiente del idioma.

## Reproducir la verificación

La licencia que sigue concede: leer, compilar y reproducir de
forma independiente los resultados declarados.

```bash
# Demostraciones Lean (toolchain fijada en ./lean-toolchain)
lake build

# Implementación Julia y tests de contrato Lean–Julia
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

## Licencia — no es código abierto

Este repositorio se publica bajo la **Bridge Protocol Restricted Source-Available
License v1.0** ([LICENSE_ERIEC.md](LICENSE_ERIEC.md)). Es una licencia *source-available*,
**no** una licencia de código abierto aprobada por la OSI.

**Puedes**: leer las fuentes, compilarlas y hacer typecheck, ejecutar los modelos
de referencia para verificar los resultados declarados, y citar extractos
limitados con atribución para citas académicas, reseñas o comentarios.

**No puedes**, sin un acuerdo escrito aparte: usar la obra comercialmente, crear
o distribuir obras derivadas, redistribuir o replicar el repositorio, entrenar o
ajustar modelos de aprendizaje automático con ella, ni hacer afirmaciones de
certificación basadas en ella.

Dado que las obras derivadas están prohibidas, **no se aceptan pull requests ni
forks**. Si te interesa colaborar u obtener una licencia, contacta con el autor.

## Cita

> Mitsuyuki Yamaguchi. *Bridge Protocol*, v0.1.0, 2026.
> Publicado bajo la Bridge Protocol Restricted Source-Available License v1.0.
> https://github.com/yaaman18/bridge-protocol

---

© 2026 Mitsuyuki Yamaguchi. Todos los derechos reservados.

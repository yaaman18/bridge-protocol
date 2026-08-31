# Bridge Protocol
### Una prueba indeterminada del mundo fenomenológico derivada de axiomas

[English](README.md) | [日本語](README.ja.md) | **Español**

`Bridge` proviene de `DCWorldBridge` (WorldDC.lean) y `bridgeOpen` (Gate.lean), los tipos de Lean que conectan el automantenimiento con el surgimiento del mundo. La compuerta fenomenológica es siempre `bridgeOpen`; nunca puede ser `pass`.

---

## Qué es este repositorio

Bridge Protocol es un protocolo para construir una teoría categorial de los sistemas que se automantienen y verificarla por máquina:

```
discusión informal → especificación categorial → demostraciones en Lean 4 → implementación en Julia
```

### La capa de objetos: qué es un sistema individual

Todo sistema individual debe satisfacer cuatro requisitos estructurales, M1–M4. Nada en esta capa puede alcanzar un objeto terminal.

- **Clausura `Φ` y su punto fijo máximo `νΦ` (M1)** — el automantenimiento se formaliza como punto fijo *máximo*, es decir, permanecer viable, y **no** maximizar nada. El mantenimiento es precario: puede romperse bajo perturbación, de modo que debe sostenerse activamente.
- **Adjunción sensoriomotora `α ⊣ σ` (M2)** — una conexión de Galois entre actuar y sentir. Lo que un sistema puede tocar y lo que lo toca de vuelta son dos caras de una misma estructura.
- **Condición de bisagra `Act ≠ ∅` (M3)** — siempre hay al menos una acción disponible; el sistema nunca queda sellado respecto de su mundo.
- **Endogeneidad / ausencia de objeto terminal (M4)** — el diagrama de demandas `D` del sistema no tiene objeto terminal alcanzable, y no se le inyecta ningún punto de consigna desde fuera. Un objeto terminal sería un estado al que el sistema podría llegar y detenerse.
- **Certificado de automantenimiento `DC`** — un testigo verificable por máquina de que un sistema se mantiene bajo su propia dinámica.
- **Mundo actuado `Wld`** — el mundo *para* un sistema, que surge del bucle de movimiento y sensación en lugar de ser dado desde fuera. Cambia el cuerpo, y cambia el mundo.

### Líneas derivadas construidas sobre esa capa

- **Terminación funcional** (`TemporalDC`) — la pérdida del `DC` del sistema completo sobre el tiempo endógeno, junto con su permanencia y exclusividad. El objetivo de diseño de esta línea es hacer explícito que la terminación funcional *no puede eludirse estructuralmente* sin añadir un axioma externo; la inmortalidad interna exigiría violar M1 y M4b a la vez. La capa formal nunca emplea la palabra «muerte»: esa lectura queda en los documentos en prosa.
- **Generación y proliferación** — el hemisferio del nacimiento. `DC ⇒ viable` se realiza como testigo de traducción unidireccional, nunca como equivalencia, y la herencia de riqueza entre generaciones es un enunciado distinto del bombeo de ramificación de bisagra de un solo paso.
- **Individualidad como par ⟨sistema `S`, descomposición `D`⟩** — la individualidad no es una etiqueta sobre un sustrato. El mismo sustrato puede ser un individuo bajo una descomposición y una colonia bajo otra, y ambas lecturas pueden ser verdaderas.
- **La apuesta del §14 (`W1`–`W6`)** — seis enunciados congelados con testigos constructivos de independencia, que muestran que *no* son derivables de los axiomas de la capa de objetos. Aquí es donde lo «indeterminado» del subtítulo se formaliza.

### La capa meta, y por qué se mantiene separada

Una disciplina estricta de dos capas atraviesa todo. Los sistemas individuales viven en la **capa de objetos**; cualquier supuesto orientado a la evolución o la selección vive solo en la **capa meta** y nunca se reescribe dentro de los individuos.

- **Selección externa Σ1** — un selector `𝒮` que actúa sobre el estado poblacional y prefiere objetos estructuralmente más ricos. No es objeto de la teoría propia de ningún individuo, y es invisible para todos ellos.
- **Funcional de riqueza `Φ_rich`** — se calcula estrictamente en modo solo lectura, a través de la observación `σ`. Nunca se compone con el operador de clausura `Φ` de un individuo.
- **Σ-pureza (no interferencia)** — variar el valor o el estado del selector debe dejar la traza observacional de cada individuo `(νΦ, V, D, traza de acción)` idéntica bit a bit. Se comprueba tanto estáticamente (alcanzabilidad de contaminación desde el espacio de nombres de selección hasta los sumideros individuales) como dinámicamente (pruebas diferenciales metamórficas).
- **La preservación de M4 es unidireccional.** `M4(i) ∧ Σ-pureza(𝒮,i) ⇒ M4-preservado(𝒮,i)` está demostrado; el recíproco **no**, y nunca se supone.

## Lo que este proyecto *no* afirma

Esta parte es tan importante como la teoría misma.

- **Ninguna afirmación sobre la consciencia.** Aunque la descripción estructural se complete y se verifique por entero, si «hay una luz encendida dentro» —si hay experiencia subjetiva— no puede demostrarse desde fuera. La teoría deja esa pregunta sin responder, fuera de la descripción, como posibilidad. Esta honestidad se impone mecánicamente: el marcador `phenomenal_claim = :not_certified` forma parte de la cadena certificada de artefactos y, por diseño, ninguna demostración lo promueve. Puede certificarse una jerarquía de individualidad; cuántas luces contiene esa jerarquía —una, muchas o ninguna— no.
- **Ninguna historia de optimización.** El mantenimiento es un punto fijo máximo, no una recompensa que maximizar. La capa de objetos prohíbe puntos de consigna externos y objetos terminales alcanzables (requisito M4).
- **Ninguna identificación silenciosa.** La viabilidad de sistemas abiertos (`viable`) y el certificado ERIE-C de automantenimiento (`DC`) se mantienen distintos; su equivalencia no está demostrada y nunca se supone. Lo mismo vale para `DC` y `Wld`: la relación de no trivialidad entre ambos es un supuesto registrado explícitamente, no un teorema.
- **Ninguna afirmación de que un contrato certificado cubra su propia prosa.** Véase el principio de dos ejes más abajo. La mayoría de los contratos están certificados con la cobertura de su prosa aún sin auditar.
- **Aún no hay condiciones de falsación.** Las 91 afirmaciones atómicas llevan un campo `falsification_ja` y las 91 están actualmente en `未記入` («sin rellenar»). La deuda está registrada y protegida por trinquete para que no crezca, pero todavía no se ha saldado.

## Metodología de verificación

### La secuencia de compuertas

```
proposed ──G1──▶ formalized ──G2──▶ bound ──G3──▶ implemented ──G4──▶ certified
```

- **G1** — la formalización en Lean 4 pasa el chequeo de tipos (`lake build`, sin `sorry`).
- **G2** — la declaración de Lean queda ligada a un símbolo de Julia mediante un test de contrato.
- **G3** — la implementación en Julia pasa sus tests.
- **G4** — el contrato se registra en el catálogo de certificados y su grafo de dependencias se verifica.

### Dos libros mayores con papeles distintos

La evidencia de verificación se representa mediante dos libros mayores. El de esquema v1, [specs/ledger.toml](specs/ledger.toml), es un **índice** de vínculos Lean–Julia certificados, dependencias y entradas del catálogo de certificados. Sus 61 puntos de verificación son todos entradas terminales `certified`; no es la fuente de verdad del ciclo de vida de las afirmaciones, y el trabajo de implementación no avanza su estado.

El **libro mayor atómico del ciclo de vida** es [specs/claim-ledger-v2.toml](specs/claim-ledger-v2.toml). Registra 91 afirmaciones sobre cuatro ejes independientes —`spec_status`, `proof_status`, `implementation_status` y `certification_status`— agrupadas en 15 grupos con 44 lotes de evidencia. Cada afirmación apunta a un archivo de enunciado Lean congelado bajo [specs/statements/](specs/statements/) (108 archivos), y el libro mayor guarda el sha256 de ese archivo para que el enunciado no pueda cambiar por debajo de la afirmación.

### Qué significa y qué no significa `certified`

Cuatro reglas dan sentido a los libros mayores.

**1. Evidencia o nada.** Una afirmación se marca `certified` **solo** cuando existen registros reales de compuerta bajo [logs/gates/](logs/gates/); esos registros se versionan como evidencia (159 directorios de compuerta, 1389 archivos de registro al 2026-08-31). El validador comprueba de forma independiente que cada ruta `certification_log` existe en disco.

**2. El principio de la brecha visible.** v2 registra las afirmaciones que carecen de demostración o certificación en sus ejes correspondientes. Nunca se descartan ni se creen en silencio. A una afirmación con `proof_status = "unproved"` el validador le *impone* `claim_kind = "conjecture"` y `checker_relation = "observation_only"`.

**3. El principio de dos ejes** (introducido el 2026-08-01). `certified` en el libro mayor v1 significa únicamente que la **única** declaración de Lean referida por `contract_id` ha sido verificada por máquina; **no** garantiza todas las propiedades enumeradas en la prosa de `claim_ja`. El eje separado `coverage_audit` registra cuánto de esa prosa está respaldado por el contrato: `unreviewed` significa aún sin auditar, `complete` significa auditado. Los ejes son ortogonales: un contrato sigue certificado mientras `coverage_audit` sea `unreviewed`, y la certificación por sí sola nunca implica cobertura de la prosa.

**4. Los verificadores declaran qué deciden realmente.** Un verificador en Julia que devuelve `true` no es automáticamente un procedimiento de decisión para el enunciado Lean al que está ligado. [specs/checker-semantic-manifest.toml](specs/checker-semantic-manifest.toml) clasifica los 164 contratos según la relación que su verificador guarda con el enunciado:

| `checker_relation` | Núm. | Significado |
|---|---:|---|
| `lean_only` | 72 | verificado por máquina en Lean; no se afirma decisión del lado Julia |
| `exact_finite_decision` | 28 | decide el enunciado sobre los portadores finitos suministrados |
| `witness_validator` | 28 | valida un testigo suministrado; no establece identidad con un objeto Lean fijo |
| `regression_only` | 14 | fija el comportamiento actual; no decide nada sobre el enunciado |
| `observation_only` | 10 | registra solo una observación |
| `sound_only` | 5 | sin falsos positivos; puede omitir casos |
| `counterexample_generator` | 4 | construye un contraejemplo |
| `counterexample_validator` | 2 | valida un contraejemplo suministrado |
| `complete_only` | 1 | sin falsos rechazos; puede aceptar de más |

De los 164, 92 están `reviewed` (con revisor nombrado y registro de base) y 72 están `machine_verified`. Cada entrada registra además su `scope`, sus `assumptions` y la garantía (`guarantee`) que dará y la que no. [specs/cert-scope-registry.toml](specs/cert-scope-registry.toml) registra el alcance de certificación de esos mismos 164 contratos; actualmente todos son `context_local`, es decir, ningún contrato reclama un alcance más allá del contexto en que fue verificado.

### Proteger las propias verificaciones

Un conjunto de tests que solo recorre el camino feliz no puede detectar su propio vaciamiento. Las prácticas confirmadas el 2026-08-27 en [specs/verification-practices-v2-draft.md](specs/verification-practices-v2-draft.md) abordan tres modos de fallo observados: verificaciones de aceptación débiles, autoverificación por el propio autor del paquete, y el mismo error de diseño repetido tres veces.

- **La entrada adversaria va a una copia temporal.** La lógica de verificación se separa en validadores con ruta inyectable bajo [tools/verify/](tools/verify/) que devuelven códigos de violación estables. El test normal y el ejecutor de mutaciones comparten el mismo validador; el ejecutor nunca toca el árbol de trabajo real.
- **El corpus de mutaciones enumera las ediciones que deben detectarse.** [tools/mutation_corpus.toml](tools/mutation_corpus.toml) empareja cada edición deliberada con el código de violación concreto que debe producir, no con un mero código de salida distinto de cero. Actualmente contiene una mutación (`CERTIFIED_TEXT_HASH_MISMATCH`).
- **El texto de la afirmación queda separado de la certificación por hash.** Cada afirmación guarda un `claim_text_hash` que liga su `statement_ja` y su `conclusion`, además de un `certified_text_hash` que registra el texto contra el que se concedió la certificación. Debilitar la prosa de una afirmación para ajustarla a lo realmente demostrado rompe ahora la comparación de hashes.
- **Un registro de modos de fallo con identificadores estables.** [specs/verification-failure-modes.toml](specs/verification-failure-modes.toml) recoge 4 modos observados (booleanos de demostración suministrados por el llamador, identificación de callbacks opacos a partir de muestras finitas, oráculos circulares y condiciones de falsación no conectadas a las compuertas), cada uno con sus registros de evidencia.
- **Un trinquete sobre la deuda de falsación.** `tools/verify/ratchet_check.jl --base-ref <commit>` compara el `falsification_pending_max` del árbol de trabajo con el mismo campo en un commit base nombrado explícitamente y exige que no haya aumentado. El llamador debe suministrar la referencia base; cuando git no está disponible, la verificación informa `UNVERIFIED` en lugar de pasar en verde.

### Estado actual (2026-08-31)

| | Valor |
|---|---|
| Puntos de verificación v1 | 61, todos `certified` |
| `coverage_audit` v1 | 10 `complete`, 51 `unreviewed` |
| Auditoría `legacy_coverage` v1 | 10 entradas; los contratos cubren 7 afirmaciones atómicas y no cubren 85 |
| Afirmaciones atómicas v2 | 91 |
| `spec_status` v2 | 86 `frozen`, 5 `draft` |
| `proof_status` v2 | 68 `proved`, 22 `not_applicable`, 1 `unproved` |
| `implementation_status` v2 | 57 `tested`, 34 `not_applicable` |
| `certification_status` v2 | 38 `certified`, 53 `uncertified` |
| Condiciones de falsación escritas | 0 de 91 |

Léase la tercera fila con atención: en las 10 entradas auditadas, solo 7 de las propiedades que su prosa afirma están respaldadas por una verificación mecánica; las 85 restantes quedan fuera del contrato.

### Qué no está automatizado

En este repositorio **no hay CI**: ni `.github/workflows`, ni `.gitlab-ci.yml`, ni `Makefile`. Cada compuerta se ejecuta localmente y su registro se versiona.

El [pipeline categorial](bin/eriec-category-pipeline.jl) ejecutable es un ejecutor de compuertas para reverificar impacto, no un controlador que haga avanzar estados: lee solo el esquema v1, nunca v2, y no escribe ningún estado en los libros mayores. El controlador de avance de estado descrito en [la especificación de orquestación](specs/loop-orchestration-spec.md) sigue siendo un diseño no implementado y aplazado; su necesidad se reevaluará cuando order-10b cree los dos primeros puntos de verificación no terminales. Véase la [auditoría de solo lectura de los libros mayores](logs/ledger-design-audit-20260814.log) para la evidencia de respaldo.

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| [formal/ERIEC/](formal/ERIEC/) | Formalización en Lean 4 (71 módulos: adjunción, clausura, bisagra, DC, mundo, invariancia, linaje, riqueza, generación, DC temporal, apuesta, metaselección, …) |
| [specs/statements/](specs/statements/) | 108 archivos de enunciado Lean congelados, ligados por sha256 desde el libro mayor v2 |
| [src/](src/) | Implementación de referencia en Julia (paquete `ERIEC.jl`, 65 archivos) |
| [test/](test/) | Tests de Julia (63 archivos), incluidos el test de contrato Lean–Julia y los tests de integridad de libros mayores, manifiesto, alcance de certificación y revisión de paquetes |
| [tools/verify/](tools/verify/) | Validadores con ruta inyectable, ejecutor de mutaciones, verificación de trinquete |
| [bin/](bin/) | Pipeline categorial, evaluación de modelos, ejecutores de experimentos Lenia y TRM |
| [specs/](specs/) | Ambos libros mayores, el manifiesto semántico de verificadores, el registro de alcance de certificación, el registro de modos de fallo y los paquetes de implementación |
| [category/](category/) | Documentos de trabajo categoriales |
| [docs/](docs/) | Visión general de la teoría, requisitos, documentos de diseño |
| [adapters/](adapters/) | Adaptadores a marcos externos (PCI) |
| [logs/gates/](logs/gates/) | Registros de evidencia de compuerta (salida de build/test que respalda cada estado `certified`) |

La mayoría de los documentos de trabajo en `docs/` y `category/` están escritos en japonés; las fuentes en Lean y Julia son el núcleo independiente del idioma.

## Reproducir la verificación

La licencia siguiente concede: leer, compilar y reproducir de forma independiente los resultados enunciados.

```bash
# Demostraciones Lean (toolchain fijada en ./lean-toolchain)
lake build

# Implementación Julia, tests de contrato Lean–Julia y todos los tests de integridad
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

Las verificaciones de integridad pueden ejecutarse por separado:

```bash
# Integridad de libros mayores, manifiesto, alcance de certificación y revisión de paquetes
julia --project=. test/test_claim_ledger.jl
julia --project=. test/test_checker_semantic_manifest.jl
julia --project=. test/test_cert_scope.jl
julia --project=. test/test_packet_review.jl

# Reverificación de impacto contra la línea base categorial (lee v1, no escribe estado)
julia --project=. bin/eriec-category-pipeline.jl check

# Verificaciones de mutación y trinquete (G3V); --base-ref debe indicarse explícitamente
tools/quiet-verify.sh logs/gates/<batch>/G3V-<timestamp>.log --base-ref <commit>
```

## Licencia — no es código abierto

Este repositorio se publica bajo la **Bridge Protocol Restricted Source-Available License v1.0** ([LICENSE.md](LICENSE.md)). Es una licencia *source-available*, **no** una licencia de código abierto aprobada por la OSI.

**Puede**: leer las fuentes, compilarlas y verificar sus tipos, ejecutar los modelos de referencia para verificar los resultados enunciados, y citar extractos limitados con atribución para cita académica, revisión o comentario.

**No puede**, sin un acuerdo escrito aparte: usar la obra comercialmente, crear o distribuir obras derivadas, redistribuir o replicar el repositorio, entrenar o afinar modelos de aprendizaje automático con él, ni hacer afirmaciones de certificación basadas en él.

Dado que las obras derivadas están prohibidas, **no se aceptan pull requests ni forks**. Si le interesa colaborar u obtener una licencia, contacte con el autor.

## Cita

> Mitsuyuki Yamaguchi. *Bridge Protocol*, v0.1.0, 2026.
> Publicado bajo la Bridge Protocol Restricted Source-Available License v1.0.
> https://github.com/yaaman18/bridge-protocol

---

© 2026 Mitsuyuki Yamaguchi. Todos los derechos reservados.

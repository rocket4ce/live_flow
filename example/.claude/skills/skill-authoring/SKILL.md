---
name: skill-authoring
description: Meta-skill para crear, evaluar y corregir skills de Claude Code. Usar cuando necesites crear nuevas skills o mejorar skills existentes.
---

# Skill Authoring Guide

Esta skill enseña como crear, evaluar y corregir skills para Claude Code.

## Estructura de una Skill

```
.claude/skills/<skill-name>/
└── SKILL.md
```

### Formato del Archivo SKILL.md

```markdown
---
name: nombre-de-la-skill
description: Descripcion corta (1-2 oraciones). Debe indicar CUANDO usar esta skill.
---

# Titulo Principal

Contenido de la skill...
```

## Anatomia de una Buena Skill

### 1. Frontmatter YAML (Obligatorio)

```yaml
---
name: mi-skill                    # kebab-case, sin espacios
description: Descripcion clara.   # Responde: "Cuando debo usar esto?"
---
```

**Reglas del name:**
- Usar kebab-case: `mi-skill-nombre`
- Sin espacios ni caracteres especiales
- Descriptivo pero corto (2-4 palabras max)

**Reglas de la description:**
- Empezar con sustantivo o verbo
- Indicar el CONTEXTO de uso: "Usar cuando...", "Para implementar..."
- Maximo 2 oraciones
- Sin puntos suspensivos al final

### 2. Titulo Principal (H1)

Debe ser claro y descriptivo. Puede ser mas largo que el `name`.

### 3. Secciones Recomendadas

| Seccion | Proposito | Obligatoria |
|---------|-----------|-------------|
| Arquitectura | Diagrama de flujo o estructura | Si |
| Tipos/Estructuras | Definiciones de datos | Si |
| Ejemplos de Codigo | Implementacion practica | Si |
| Errores Comunes | Debugging y solucion | Recomendada |
| Archivos Clave | Referencias rapidas | Recomendada |

## Como Escribir Contenido Efectivo

### Principio 1: Mostrar, No Solo Decir

```markdown
<!-- MAL -->
Los paths bezier usan puntos de control.

<!-- BIEN -->
Los paths bezier usan puntos de control:

```elixir
def bezier_path(sx, sy, tx, ty) do
  # Control point 1: sale horizontal del source
  c1x = sx + offset
  c1y = sy

  # Control point 2: entra horizontal al target
  c2x = tx - offset
  c2y = ty

  "M #{sx},#{sy} C #{c1x},#{c1y} #{c2x},#{c2y} #{tx},#{ty}"
end
```
```

### Principio 2: Diagramas ASCII para Arquitectura

```markdown
```
User Action
    |
    v
[JS Hook] --pushEventTo--> [LiveComponent]
    |                            |
    | (optimistic)               | handle_event
    v                            v
DOM Update <--patch--------  State Update
```
```

### Principio 3: Codigo en el Lenguaje del Proyecto

Para este proyecto (LiveFlow/Elixir):
- Usar Elixir para logica del servidor
- Usar JavaScript para hooks y interaccion
- Incluir ambos cuando sea relevante

### Principio 4: Tipos Explicitos

Siempre incluir definiciones de tipos/estructuras:

```markdown
```typescript
type NodeDragItem = {
  id: string;
  position: XYPosition;
  distance: XYPosition;
}
```

Equivalente en Elixir:
```elixir
%{
  id: String.t(),
  position: %{x: float(), y: float()},
  distance: %{x: float(), y: float()}
}
```
```

### Principio 5: Errores y Soluciones

Incluir seccion de debugging:

```markdown
## Errores Comunes

### Error: FunctionClauseError en handle_event

**Sintoma**: `no function clause matching`

**Causa**: Evento JS no tiene handler

**Solucion**:
```elixir
def handle_event("lf:evento", params, socket) do
  {:noreply, socket}
end
```
```

## Checklist de Calidad

Antes de finalizar una skill, verificar:

### Estructura
- [ ] Tiene frontmatter YAML valido con `name` y `description`
- [ ] El `name` usa kebab-case
- [ ] La `description` indica cuando usar la skill
- [ ] Tiene titulo H1 descriptivo

### Contenido
- [ ] Incluye diagrama de arquitectura (ASCII o descripcion)
- [ ] Define tipos/estructuras de datos principales
- [ ] Tiene ejemplos de codigo ejecutables
- [ ] Codigo usa el lenguaje correcto del proyecto
- [ ] Incluye seccion de errores comunes (si aplica)

### Claridad
- [ ] Un desarrollador nuevo puede entender el concepto
- [ ] Los ejemplos son copy-paste ready
- [ ] No hay jerga sin explicar
- [ ] Los comentarios en codigo explican el "por que"

### Completitud
- [ ] Cubre el ciclo completo (inicio, proceso, fin)
- [ ] Menciona archivos clave del proyecto
- [ ] Referencias cruzadas a otras skills si es relevante

## Como Corregir Skills Existentes

### Paso 1: Diagnosticar

Leer la skill y evaluar contra el checklist de calidad.

### Paso 2: Identificar Problemas Comunes

| Problema | Sintoma | Solucion |
|----------|---------|----------|
| Muy abstracta | Solo texto, sin codigo | Agregar ejemplos concretos |
| Muy especifica | Solo un caso de uso | Generalizar con multiples ejemplos |
| Desactualizada | Referencias a codigo inexistente | Actualizar paths y funciones |
| Incompleta | Falta el "como" | Agregar pasos de implementacion |
| Desorganizada | Dificil de escanear | Agregar headers y tablas |

### Paso 3: Aplicar Mejoras

```markdown
<!-- Antes (abstracto) -->
## Manejo de Eventos
Los eventos se manejan en el LiveComponent.

<!-- Despues (concreto) -->
## Manejo de Eventos

```elixir
# En lib/live_flow/components/flow.ex

@impl true
def handle_event("lf:node_change", %{"changes" => changes}, socket) do
  nodes = apply_changes(socket.assigns.nodes, changes)
  {:noreply, assign(socket, nodes: nodes)}
end
```

**Eventos disponibles:**
- `lf:node_change` - Cambios de posicion/dimension
- `lf:connect_end` - Nueva conexion creada
```

### Paso 4: Validar

1. Leer la skill como si fuera la primera vez
2. Intentar seguir los ejemplos mentalmente
3. Verificar que los paths de archivos existen
4. Asegurar que el codigo compila/funciona

## Plantilla de Nueva Skill

```markdown
---
name: nombre-skill
description: Descripcion corta. Usar cuando [contexto especifico].
---

# Titulo Descriptivo

Parrafo introductorio (1-2 oraciones) explicando que hace esta skill.

## Arquitectura

```
Diagrama ASCII del flujo/estructura
```

## Tipos Principales

```typescript
type MiTipo = {
  campo: tipo;
}
```

## Implementacion

### Paso 1: [Nombre del paso]

```elixir
# Codigo de ejemplo
```

### Paso 2: [Nombre del paso]

```javascript
// Codigo de ejemplo
```

## Uso en el Proyecto

Archivos relevantes:
- `path/al/archivo.ex` - Descripcion
- `path/al/otro.js` - Descripcion

## Errores Comunes

### Error: [Nombre del error]

**Sintoma**: Descripcion del sintoma

**Causa**: Explicacion de la causa

**Solucion**:
```elixir
# Codigo de solucion
```
```

## Cuando NO Crear una Skill

- Informacion que cambia frecuentemente (versiones, configs temporales)
- Conocimiento muy especifico de un bug particular
- Documentacion que ya existe en el README del proyecto
- Conceptos generales de programacion (usar conocimiento base)

## Mantenimiento de Skills

### Revisar Skills Cuando:

1. El codigo del proyecto cambia significativamente
2. Se encuentran errores siguiendo una skill
3. Hay nuevas mejores practicas
4. Se repiten preguntas sobre un tema

### Proceso de Actualizacion:

1. Identificar skill desactualizada
2. Leer codigo actual del proyecto
3. Actualizar ejemplos y paths
4. Agregar nuevos patrones descubiertos
5. Remover informacion obsoleta

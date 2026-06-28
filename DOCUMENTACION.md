# Void Notes - Documentación del Proyecto

## 📱 ¿Qué es Void Notes?

Void Notes es una aplicación de **notas de voz inteligentes** para Android. Permite grabar audio, transcribirlo automáticamente y estructurarlo en notas Markdown usando inteligencia artificial. La app funciona como una **base de conocimiento personal** con búsqueda semántica, categorización automática y navegación por enlaces.

---

## 🏗️ Arquitectura del Proyecto

### Estructura de Carpetas

```
v13_backup/
├── lib/
│   ├── main.dart                    # Punto de entrada, configuración del tema
│   ├── models/
│   │   ├── note.dart                # Modelo de datos de una nota
│   │   └── app_settings.dart        # Configuración global de la app
│   ├── screens/
│   │   └── home_screen.dart         # Pantalla principal (orquesta todo)
│   ├── services/
│   │   ├── ai_service.dart          # Cliente HTTP para OpenRouter/Cerebras
│   │   ├── search_service.dart      # Búsqueda semántica y clasificación de intents
│   │   └── storage_service.dart     # Persistencia en SharedPreferences
│   └── widgets/
│       ├── audio_fab.dart           # Botón flotante de grabación con animaciones
│       ├── editor_view.dart         # Editor Markdown con wiki-links
│       ├── folder_sidebar.dart      # Drawer lateral con lista de notas
│       ├── settings_sheet.dart      # Modal básico de configuración
│       └── advanced_settings_view.dart  # Configuración avanzada completa
├── android/                         # Proyecto Android nativo
├── ios/                             # Proyecto iOS nativo
├── pubspec.yaml                     # Dependencias y configuración del proyecto
└── DOCUMENTACION.md                 # Este archivo
```

---

## 📦 Dependencias Principales

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `speech_to_text` | ^7.3.0 | Reconocimiento de voz nativo |
| `http` | ^1.6.0 | Cliente HTTP para APIs de IA |
| `google_fonts` | ^8.0.0 | Fuentes tipográficas (Inter, JetBrains Mono) |
| `shared_preferences` | ^2.5.4 | Almacenamiento local persistente |
| `permission_handler` | ^12.0.1 | Gestión de permisos (micrófono) |
| `animate_do` | ^4.2.0 | Animaciones predefinidas |
| `flutter_markdown` | ^0.7.7+1 | Renderizado de Markdown |
| `uuid` | ^4.5.2 | Generación de identificadores únicos |

---

## 🧠 Modelos de Datos

### [`Note`](v13_backup/lib/models/note.dart)

```dart
class Note {
  final String id;           // UUID único
  String title;              // Título de la nota
  String content;            // Contenido en Markdown
  String folder;             // Carpeta: 'Default', 'INDEX', 'SEARCH'
  DateTime modifiedAt;       // Última modificación
}
```

**Características:**
- Serialización JSON para persistencia
- Soporte para carpetas (sistema de organización)
- Campo `folder` especial para índices automáticos

### [`AppSettings`](v13_backup/lib/models/app_settings.dart)

```dart
class AppSettings {
  String openRouterApiKey;       // API key de OpenRouter
  String cerebrasApiKey;         // API key de Cerebras
  AIProvider activeProvider;     // Proveedor de IA activo
  String targetLanguage;         // Idioma objetivo (Spanish, English, etc.)
  String systemInstructions;     // Prompt del sistema para la IA
  bool useGlobalContext;         // Activar contexto global en la IA
}
```

**Características:**
- Dos proveedores de IA configurables
- Prompt del sistema editable por el usuario
- Contexto global opcional (la IA ve notas relacionadas)

---

## 🔄 Flujo de la Aplicación

### 1. Inicio de la App
1. [`HomeScreen`](v13_backup/lib/screens/home_screen.dart) carga la configuración y notas desde [`StorageService`](v13_backup/lib/services/storage_service.dart)
2. Si no hay notas, crea una nueva automáticamente
3. Inicializa el reconocimiento de voz y solicita permisos de micrófono

### 2. Grabación de Voz
1. Usuario mantiene presionado el [`AudioFAB`](v13_backup/lib/widgets/audio_fab.dart)
2. Se activa `speech_to_text` con el idioma configurado
3. La transcripción aparece en tiempo real en el [`EditorView`](v13_backup/lib/widgets/editor_view.dart)
4. Al soltar el botón, se detiene la grabación

### 3. Procesamiento con IA
1. Se clasifica la **intención de voz** usando [`SearchService.classifyIntent()`](v13_backup/lib/services/search_service.dart)
2. Según la intención:
   - **undo**: Deshace el último cambio
   - **save**: Guarda la nota manualmente
   - **open**: Abre una nota por título
   - **search**: Realiza búsqueda semántica
   - **remember**: Fuerza creación de nota nueva
   - **none**: Lógica automática (nueva si pasaron >3 min, actualizar si no)
3. Se envía la transcripción a [`AIService`](v13_backup/lib/services/ai_service.dart)
4. La IA devuelve la nota estructurada con metadatos

### 4. Estructura de la Respuesta de la IA

La IA devuelve un texto con este formato:

```markdown
# Título de la Nota
Contenido de la nota en Markdown...

METADATA_START
ACTION: NUEVA
TARGET: NONE
TITLE: Título de la Nota
CATEGORY: Categoría
SUMMARY: Resumen corto
METADATA_END
```

- **ACTION**: `NUEVA` o `ACTUALIZAR`
- **TARGET**: ID de la nota a actualizar (o `NONE`)
- **CATEGORY**: Categoría para indexación automática
- **SUMMARY**: Resumen para el índice lateral

### 5. Sistema de Índices Automáticos

Cuando la IA asigna una categoría:
1. Se crea/actualiza una nota en la carpeta `INDEX` con el nombre de la categoría
2. Se agrega un enlace `[[Título de la Nota]]` al índice
3. Se incluye un bloque de keywords oculto para búsqueda semántica:

```markdown
# Comida

- [[Compra Súper]] - Lista de compras del supermercado
- [[Receta Tacos]] - Receta de tacos al pastor

<!-- KEYWORDS: alimentación, nutrición, recetas, hambre, cocina -->
```

---

## 🔍 Búsqueda Semántica

[`SearchService.findRelevantNotes()`](v13_backup/lib/services/search_service.dart:56) implementa un sistema de scoring avanzado:

### Ponderación de Puntos

| Criterio | Puntos |
|----------|--------|
| Coincidencia en título (exacta) | +10 |
| Coincidencia en título (parcial) | +3 |
| Coincidencia exacta de sub-token en título | +5 |
| Coincidencia en categoría | +6 |
| Relación por wiki-link (índice) | +8 |
| Coincidencia en contenido | +1 |

### Características
- **Taxonomía Bridge**: Busca en bloques `<!-- KEYWORDS: ... -->` de los índices
- **Relational Graph Boosting**: Las notas relacionadas por wiki-links tienen prioridad
- **Single Note Fallback**: Si solo hay una nota, la devuelve automáticamente
- **Normalización**: Ajusta el score por longitud del contenido

---

## 🎤 Reconocimiento de Voz

### Biblioteca: `speech_to_text`

- **Idioma configurable**: Español (`es_ES`) o Inglés (`en_US`) según configuración
- **Resultados continuos**: Transcripción en tiempo real
- **Nivel de sonido**: Visualización de intensidad en el `AudioFAB`
- **Permisos nativos**: Solicitud explícita al usuario

### Intents de Voz Soportados

| Comando de voz | Acción |
|----------------|--------|
| "vuelve", "regresa", "atrás", "undo" | Deshacer último cambio |
| "guardar", "save", "listo", "ok" | Guardar nota manualmente |
| "abre [título]", "open [título]" | Abrir nota por título |
| "busca [término]", "search [término]" | Búsqueda semántica |
| "recuerda", "nuevo", "apunta" | Forzar creación de nota nueva |

---

## 🎨 Interfaz de Usuario

### Tema
- **Modo oscuro** forzado
- **Colores**: Negro (`#000000`), superficie (`#111111`), acento rojo (`Colors.redAccent`)
- **Fuentes**: Inter (UI) + JetBrains Mono (editor)

### Componentes Principales

#### [`AudioFAB`](v13_backup/lib/widgets/audio_fab.dart)
- Botón circular de 72px con animación de rotación
- Pulso rojo durante grabación
- Escala dinámica según nivel de sonido
- Interacción por **hold** (presionar y soltar)

#### [`EditorView`](v13_backup/lib/widgets/editor_view.dart)
- Modo edición: `TextField` con fuente monoespaciada
- Modo vista: `MarkdownBody` con estilo personalizado
- Texto transitorio parpadeante durante grabación/procesamiento
- Soporte para wiki-links `[[Título]]` con navegación

#### [`FolderSidebar`](v13_backup/lib/widgets/folder_sidebar.dart)
- Drawer lateral con organización por carpetas
- Notas `INDEX` siempre al principio
- Indicador de urgencia (rojo) para notas prioritarias
- Confirmación de eliminación con diálogo

#### [`AdvancedSettingsView`](v13_backup/lib/widgets/advanced_settings_view.dart)
- Selector de proveedor de IA (OpenRouter / Cerebras)
- Toggle de contexto global
- Campos para API keys
- Selector de idioma
- Editor de prompt del sistema

---

## 🤖 Inteligencia Artificial

### Proveedores Soportados

| Proveedor | Modelo | URL |
|-----------|--------|-----|
| OpenRouter | `deepseek/deepseek-r1-0528:free` | `https://openrouter.ai/api/v1/chat/completions` |
| Cerebras | `gpt-oss-120b` | `https://api.cerebras.ai/v1/chat/completions` |

### Prompt del Sistema (por defecto)

```
Eres un asistente experto estructurando notas. Tu tarea es dar formato markdown a la siguiente transcripción. Debes dar un resumen, omitir muletillas, cosas no relevantes, repeticiones y redundancias. El estilo debe ser minimalista y directo. Responde ÚNICAMENTE con el contenido de la nota formateada, sin introducciones ni conclusiones.
```

### Contexto Global

Cuando está activado, la IA recibe hasta 5 notas relacionadas como contexto:

```
CONTEXTO PARA REFERENCIA:
--- [ID: xxx] TITULO: Nota Relacionada ---
Contenido de la nota relacionada...
```

---

## 💾 Persistencia

### [`StorageService`](v13_backup/lib/services/storage_service.dart)

- **Tecnología**: `shared_preferences` (clave-valor en disco)
- **Claves**:
  - `void_settings`: Configuración de la app (JSON)
  - `void_notes`: Lista de notas (JSON array)
- **Manejo de errores**: Si los datos están corruptos, reinicia a valores por defecto

---

## 🔄 Historial de Versiones

El código contiene referencias a versiones en comentarios:

| Versión | Característica |
|---------|----------------|
| v7.8 | Deduplicación por título + categoría |
| v8.0 | Estructura híbrida de respuesta de IA |
| v8.1 | Forzado de nota nueva/actualización |
| v8.2 | Ordenamiento de notas (INDEX primero) |
| v8.7 | Pulso en texto transitorio |
| v8.9 | Detección robusta de bloque METADATA |
| v10.0 | Safe H1 Strip (elimina H1 duplicado) |
| v11.0 | Historial de undo (20 snapshots) |
| v11.2 | Clasificación de intents de voz |
| v12.0 | Bonus por coincidencia completa de query |
| v12.1 | Relational Graph Boosting |
| v12.2 | Categoría tag boost + fuzzy matching |
| v13.0 | Lógica de auto-creación por tiempo |
| v13.1 | Taxonomy Bridge + limpieza de referencias en INDEX |

---

## 🚀 Compilación

### Requisitos
- Flutter SDK ^3.9.2
- Android SDK (API 21+)
- Java 17 (para Gradle)

### Comandos

```bash
# Instalar dependencias
flutter pub get

# Compilar APK debug
flutter build apk --debug

# Compilar APK release (optimizado)
flutter build apk --release

# Ejecutar en dispositivo conectado
flutter run
```

### GitHub Actions

El archivo [`.github/workflows/compilar.yml`](v13_backup/.github/workflows/compilar.yml) configura compilación automática en cada push a `main`:
1. Checkout del código
2. Configuración de Java 17
3. Instalación de Flutter stable
4. `flutter pub get`
5. `flutter build apk --release`
6. Subida del APK como artifact

---

## 📋 TODO / Mejoras Futuras

- [ ] Sincronización en la nube (Firebase, Supabase)
- [ ] Exportación de notas (PDF, TXT)
- [ ] Widgets de escritorio para notas frecuentes
- [ ] Modo offline completo con cola de sincronización
- [ ] Soporte para imágenes en notas
- [ ] Temas personalizables (claro/oscuro/auto)
- [ ] Copia de seguridad automática
- [ ] Integración con calendario para recordatorios

# Plan Técnico — Feature 001: Setup y CI/CD

> **ID Feature:** `001-setup-y-cicd`  
> **Estado:** En Implementación  
> **Target:** iOS 17.0+ | Swift 6 (Strict Concurrency Complete)  
> **Especificación de referencia:** `spec/features/001-setup-y-cicd/spec.md`

---

## 1. Arquitectura Técnica y Estrategia

Esta feature establece la infraestructura inicial para **SwipeCleaner**. Debido a que la edición de código se realiza en un entorno sin Xcode local (Windows/VS Code), **GitHub Actions** actúa como el entorno exclusivo de build, lint, testing y empaquetado.

### Decisiones Arquitectónicas Principales

1. **Configuración de Target Xcode (`SwipeCleaner.xcodeproj`):**
   - **Deployment Target:** iOS 17.0
   - **Lenguaje:** Swift 6.0 con `SWIFT_STRICT_CONCURRENCY = complete` y `SWIFT_VERSION = 6.0`.
   - **Firma de Código:** Deshabilitada en CI mediante flags `CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO` y `CODE_SIGNING_ALLOWED=NO`.
   - **Estructura Modular Nativa:** Código organizado en `/codigo/SwipeCleaner` y tests en `/codigo/SwipeCleanerTests`.

2. **Aislamiento Estricto de Red y Privacidad:**
   - **Guardarraíl Estático (`lint_network.sh`):** Script Bash que busca patrones prohibidos (`import URLSession`, `import FoundationNetworking`, `import Network`, `import CFNetwork`, `import Alamofire`, `import WebKit`, `NSAllowsArbitraryLoads`) mediante `grep` recursivo en `/codigo`.
   - **Test de Infraestructura (`NetworkGuardrailTests.swift`):** Unit test escrito en Swift Testing (`@Test`) que ejecuta la validación programática de la ausencia de APIs de red.

3. **Pipeline CI/CD (`.github/workflows/build.yml`):**
   - Runner: `macos-latest` con Xcode 16.x (`/Applications/Xcode_16.0.app`).
   - Fases secuenciales:
     1. Checkout del código.
     2. Selección explícita de Xcode 16.x (`xcode-select`).
     3. Ejecución del script `lint_network.sh`.
     4. Build y Tests en Simulador (iPhone 15, iOS 17+) con generación de `TestResults.xcresult`.
     5. Publicación del artefacto `test-results-xcresult` (`if: always()`).
     6. Build Release para `iphoneos` y empaquetado en `.ipa` no firmado (`SwipeCleaner-unsigned.ipa`).
     7. Publicación del artefacto `SwipeCleaner-unsigned-ipa`.

---

## 2. Estructura de Componentes y Archivos

```text
codigo/
├── SwipeCleaner.xcodeproj/
│   └── project.pbxproj                  ← Proyecto Xcode con build settings Swift 6
├── SwipeCleaner/
│   ├── App/
│   │   ├── SwipeCleanerApp.swift       ← Entrypoint SwiftUI con @main y WindowGroup
│   │   └── Info.plist                   ← Declaración de NSPhotoLibraryUsageDescription
│   └── Resources/
│       └── Assets.xcassets/             ← AppIcon y AccentColor
├── SwipeCleanerTests/
│   └── InfrastructureTests/
│       └── NetworkGuardrailTests.swift  ← Pruebas unitarias de aislamiento de red
└── scripts/
    └── lint_network.sh                  ← Script ejecutable de guardarraíl de red

.github/
└── workflows/
    └── build.yml                        ← Workflow completo de CI/CD para GitHub Actions
```

---

## 3. Especificaciones Detalladas de Implementación

### 3.1 Proyecto Xcode (`project.pbxproj`)
- Definición estructurada del proyecto Xcode compatible con Xcode 16.
- Claves de build settings obligatorias:
  - `SWIFT_STRICT_CONCURRENCY`: `complete`
  - `SWIFT_VERSION`: `6.0`
  - `IPHONEOS_DEPLOYMENT_TARGET`: `17.0`
  - `INFOPLIST_KEY_NSPhotoLibraryUsageDescription`: `"SwipeCleaner necesita acceso a tu fototeca para permitirte revisar y clasificar tus fotos y vídeos para liberar espacio localmente."`

### 3.2 Script de Guardarraíl (`codigo/scripts/lint_network.sh`)
- Permisos `chmod +x`.
- Búsqueda con `grep -rE` en el directorio `/codigo` ignorando directorios de build.
- Lista de símbolos prohibidos: `URLSession`, `FoundationNetworking`, `import Network`, `import CFNetwork`, `import Alamofire`, `import WebKit`, `NSAllowsArbitraryLoads`.
- Si se detecta cualquier coincidencia, imprime el detalle con nombre de archivo y número de línea, y termina con `exit 1`.

### 3.3 Suite de Tests (`NetworkGuardrailTests.swift`)
- Import de `Testing` (`import Testing`).
- Estructura `@Suite struct NetworkGuardrailTests`.
- Pruebas para verificar que la configuración del proyecto y el código fuente no contienen imports ni llamadas a APIs de red.

### 3.4 Workflow CI/CD (`.github/workflows/build.yml`)
- Triggers: Push y PRs a `main` y `dev`.
- Concurrencia con `cancel-in-progress: true`.
- Pasos de compilación sin firma para simulador y dispositivo.
- Empaquetado `Payload/SwipeCleaner.app` -> `zip SwipeCleaner-unsigned.ipa`.

---

## 4. Plan de Verificación y Criterios de Aceptación

| Criterio | Método de Verificación | Resultado Esperado |
|---|---|---|
| **1.1 Strict Concurrency & Swift 6** | `xcodebuild build` en GitHub Actions | Compilación sin warnings ni errores de concurrencia. |
| **1.2 Guardarraíl de Red** | Ejecución de `lint_network.sh` en CI | Exit Code 0. Si se añade `import Network`, Exit Code 1. |
| **1.3 Tests & XCResult** | `xcodebuild test` en simulador iPhone 15 | 100% pass + artefacto `test-results-xcresult` generado siempre. |
| **1.4 Empaquetado IPA** | Script de packaging `.ipa` en CI | Artefacto `SwipeCleaner-unsigned-ipa` disponible para descarga. |

---

## 5. Riesgos Técnicos y Mitigaciones

1. **Riesgo:** Versión de Xcode en GitHub Actions difiere entre ejecuciones de `macos-latest`.  
   *Mitigación:* Se ejecuta `sudo xcode-select -s /Applications/Xcode_16.0.app/Contents/Developer` y `xcodebuild -version` al inicio del job.
2. **Riesgo:** Fallos en `xcodebuild` por requerimientos de firma de código en runners sin certificados.  
   *Mitigación:* Se pasan explícitamente los parámetros `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`.
3. **Riesgo:** Incompatibilidad de sintaxis Swift Testing si se usa Xcode anterior.  
   *Mitigación:* Garantizar Xcode 16+ en el runner del CI.

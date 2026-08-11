# Especificación Funcional y Técnica (SDD) — Feature 001: Setup y CI/CD

> **ID Feature:** `001-setup-y-cicd`  
> **Estado:** Especificado  
> **Versión target:** iOS 17.0+ | Swift 6.0 (Strict Concurrency Complete)  
> **Ubicación del código:** `/codigo`  
> **Runner CI:** GitHub Actions (`macos-latest`, Xcode 16.x)

---

## 1. Visión General y Objetivos

El objetivo de esta feature es establecer la arquitectura base del proyecto Xcode y la infraestructura de Integración y Despliegue Continuo (CI/CD) para **SwipeCleaner**. Dado que el desarrollo local se realiza en un entorno sin Xcode local (Windows), GitHub Actions actúa como el **único entorno de compilación, verificación estática y ejecución de pruebas automatizadas**.

### Objetivos Clave
1. Inicializar la estructura del proyecto Xcode en la carpeta `/codigo` cumpliendo estrictamente con Swift 6, strict concurrency activado (`SWIFT_STRICT_CONCURRENCY = complete`) y target mínimo en iOS 17.0.
2. Definir el `Info.plist` con la declaración estricta de privacidad para PhotoKit y la ausencia total de permisos de red.
3. Crear el workflow `.github/workflows/build.yml` que compile, ejecute la suite de pruebas unitarias/integración, verifique guardarraíles de privacidad mediante un script de lint y genere un archivo `.ipa` no firmado como artefacto descargable.

---

## 2. Criterios de Aceptación (Medibles y Testeables)

### Criterio 1.1: Compilación Nativa y Strict Concurrency
- **Given** el código fuente en la carpeta `/codigo`.
- **When** GitHub Actions ejecuta `xcodebuild build` con Xcode 16.x para el SDK `iphonesimulator`.
- **Then** el proyecto debe compilar con **cero advertencias (warnings) de concurrencia estricta** y cero errores.

### Criterio 1.2: Guardarraíl de Red en CI (Verificación de Privacidad)
- **Given** una verificación de CI en progreso.
- **When** se ejecuta el paso de análisis estático (`lint-network`).
- **Then** el workflow debe **fallar inmediatamente** si se encuentra cualquier referencia o `import` a `URLSession`, `FoundationNetworking`, `Network`, `CFNetwork`, `Alamofire`, `WebKit`, `NetworkExtension` o la clave `NSAllowsArbitraryLoads` en el repositorio.

### Criterio 1.3: Ejecución de Tests Automatizados y Artefactos de Diagnóstico
- **Given** una suite de pruebas escrita con Swift Testing (`@Test`, `#expect`).
- **When** CI ejecuta `xcodebuild test` en un simulador de iPhone (e.g. `iPhone 15`, iOS 17+).
- **Then** todos los tests deben pasar exitosamente (100% pass) y se debe subir el archivo `TestResults.xcresult` como artefacto de GitHub Actions **siempre** (`if: always()`).

### Criterio 1.4: Emisión del Artefacto `.ipa` Sin Firma
- **Given** una compilación exitosa de la rama `dev` o `main`.
- **When** se completa la etapa de empaquetado del workflow de CI.
- **Then** el workflow genera un archivo `.ipa` comprimido (unsigned) y lo publica utilizando `actions/upload-artifact@v4` con el nombre `SwipeCleaner-unsigned-ipa`.

---

## 3. Fuera de Alcance (Out of Scope)

1. Firma de código mediante certificados Apple Developer (`Provisioning Profiles` o certificados p12) en GitHub Secrets (reservado para fases de distribución beta/App Store).
2. Despliegue automático a TestFlight o App Store Connect.
3. Implementación de lógica de interfaz o modelos de dominio de PhotoKit (cubierto en Features 002, 003 y 004).

---

## 4. Diseño Arquitectónico y Estructura del Proyecto

### 4.1 Estructura de Directorios en `/codigo`
```text
codigo/
├── SwipeCleaner.xcodeproj/
│   └── project.pbxproj
├── SwipeCleaner/
│   ├── App/
│   │   ├── SwipeCleanerApp.swift       ← Entry point SwiftUI (@main)
│   │   └── Info.plist                   ← Declaraciones de permisos nativos
│   ├── Resources/
│   │   └── Assets.xcassets              ← AppIcon y paleta de colores nativa
│   └── Preview Content/
├── SwipeCleanerTests/
│   ├── InfrastructureTests/
│   │   └── NetworkGuardrailTests.swift  ← Unit test para verificar aislamiento de red
│   └── Mocks/
└── scripts/
    └── lint_network.sh                  ← Guardarraíl ejecutable por el CI
```

### 4.2 Configuración del Target y Build Settings
- **Product Name:** `SwipeCleaner`
- **Bundle Identifier:** `com.tindercleaner.app`
- **Deployment Target:** `iOS 17.0`
- **Swift Language Version:** `Swift 6`
- **Build Settings Clave:**
  - `SWIFT_STRICT_CONCURRENCY = complete`
  - `ENABLE_HARDENED_RUNTIME = YES`
  - `ONLY_ACTIVE_ARCH = YES` (para builds de simulador en CI)
  - `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` = `"SwipeCleaner necesita acceso a tu fototeca para permitirte revisar y clasificar tus fotos y vídeos para liberar espacio localmente."`

---

## 5. Diseño del Workflow CI/CD (`.github/workflows/build.yml`)

### 5.1 Especificación del Job de CI
```yaml
name: CI & Build Pipeline

on:
  push:
    branches: [ main, dev ]
  pull_request:
    branches: [ main, dev ]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-test-package:
    runs-on: macos-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Select Xcode Version
        run: |
          sudo xcode-select -s /Applications/Xcode_16.0.app/Contents/Developer
          xcodebuild -version

      - name: Run Network Guardrail Lint
        run: |
          chmod +x ./codigo/scripts/lint_network.sh
          ./codigo/scripts/lint_network.sh

      - name: Build and Test (iOS Simulator)
        run: |
          xcodebuild test \
            -project codigo/SwipeCleaner.xcodeproj \
            -scheme SwipeCleaner \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
            -resultBundlePath TestResults.xcresult \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Upload Test Results Artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-xcresult
          path: TestResults.xcresult
          retention-days: 14

      - name: Package Unsigned IPA
        if: success()
        run: |
          mkdir -p Payload
          xcodebuild build \
            -project codigo/SwipeCleaner.xcodeproj \
            -scheme SwipeCleaner \
            -sdk iphoneos \
            -configuration Release \
            -derivedDataPath build/DerivedData \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO
          
          cp -r build/DerivedData/Build/Products/Release-iphoneos/SwipeCleaner.app Payload/
          zip -r SwipeCleaner-unsigned.ipa Payload
          
      - name: Upload IPA Artifact
        if: success()
        uses: actions/upload-artifact@v4
        with:
          name: SwipeCleaner-unsigned-ipa
          path: SwipeCleaner-unsigned.ipa
          retention-days: 30
```

---

## 6. Restricciones de Seguridad, Privacidad y Concurrencia

1. **Guardarraíl Estricto de Privacidad (`lint_network.sh`):**
   El script escanea recurrentemente el directorio `/codigo` en busca de patrones prohibidos:
   - Expresiones regulares prohibidas: `import URLSession`, `import FoundationNetworking`, `import Network`, `import CFNetwork`, `import Alamofire`, `import WebKit`, `URLSession.shared`, `URLSessionConfiguration`.
   - Si se detecta alguna coincidencia en archivos `.swift` o `.plist`, el script imprime la línea ofensiva y retorna `exit 1`.
2. **Swift 6 Strict Concurrency:**
   - Todo el código en `/codigo` debe cumplir con comprobaciones completas de transferencia de ownership (`Sendable`) y aislamiento de actores (`@MainActor`).
   - Los tipos globales o singletons prohibidos; el estado se inyecta explícitamente.

---

## 7. Casos Límite y Manejo de Fallos en CI

| Caso Límite / Error | Comportamiento Esperado | Acción de Mitigación |
|---|---|---|
| Inclusión accidental de una librería de red por SPM | El paso `lint_network.sh` en CI falla inmediatamente. | Cancelación del job, reporte en log de CI. |
| Incompatibilidad de versión de Xcode en runner `macos-latest` | `xcode-select` fuerza explícitamente Xcode 16.x. | El workflow registra `xcodebuild -version` al inicio. |
| Fallo en un test unitario en el simulador | CI marca el check como `failed` y sube `TestResults.xcresult`. | El desarrollador analiza el `.xcresult` descargado. |
| Intento de firmar app sin certificados en CI | `CODE_SIGNING_ALLOWED=NO` evita fallos por falta de provisioning profiles. | Se emite un `.ipa` no firmado explícitamente. |

---

## 8. Criterio de Cierre de la Feature

La Feature `001-setup-y-cicd` se considera **completada y cerrada** únicamente cuando:
1. Existe un push/merge en la rama `dev` o `main`.
2. El workflow de GitHub Actions finaliza en verde (Exit Code 0).
3. El artefacto `SwipeCleaner-unsigned-ipa` está disponible para su descarga desde la ejecución del workflow.

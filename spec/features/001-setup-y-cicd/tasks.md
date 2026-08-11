# Tareas de Implementación (Tasks) — Feature 001: Setup y CI/CD

> **ID Feature:** `001-setup-y-cicd`  
> **Estado:** Completado  
> **Especificación:** `spec/features/001-setup-y-cicd/spec.md`  
> **Plan Técnico:** `spec/features/001-setup-y-cicd/plan.md`

---

## Grupo 1: Estructura del Proyecto Base Xcode (/codigo)

- [x] **Task 1.1:** Crear la estructura de directorios del proyecto en `/codigo` (`SwipeCleaner/App`, `SwipeCleaner/Resources`, `SwipeCleanerTests/InfrastructureTests`, `scripts`).
  - *Criterio de Aceptación:* Directorios creados según el plan técnico.
- [x] **Task 1.2:** Crear y configurar `SwipeCleaner.xcodeproj/project.pbxproj` para target iOS 17.0, Swift 6 con `SWIFT_STRICT_CONCURRENCY = complete` y sin firma requerida.
  - *Criterio de Aceptación:* El archivo PBX define la configuración de build requerida sin errores de formato.
- [x] **Task 1.3:** Crear `SwipeCleanerApp.swift` como entrypoint `@main` SwiftUI e `Info.plist` con `NSPhotoLibraryUsageDescription` exacto.
  - *Criterio de Aceptación:* El texto de permiso coincide exactamente con la spec y no hay claves de red (`NSAllowsArbitraryLoads`).

---

## Grupo 2: Script Guardarraíl de Privacidad y Red

- [x] **Task 2.1:** Crear `codigo/scripts/lint_network.sh` con permisos de ejecución (`chmod +x`).
  - *Criterio de Aceptación:* El script es ejecutable en entorno POSIX / macOS.
- [x] **Task 2.2:** Implementar la lógica de escaneo estático en `lint_network.sh` para detectar imports/uso de `URLSession`, `FoundationNetworking`, `Network`, `CFNetwork`, `Alamofire`, `WebKit`, etc.
  - *Criterio de Aceptación:* Retorna `0` si el código está limpio de red y `1` si detecta uso prohibido.

---

## Grupo 3: Pruebas Unitarias con Swift Testing

- [x] **Task 3.1:** Crear el archivo `NetworkGuardrailTests.swift` en `codigo/SwipeCleanerTests/InfrastructureTests/`.
  - *Criterio de Aceptación:* Archivo creado con import de `Testing`.
- [x] **Task 3.2:** Implementar tests unitarios usando `@Test` e `#expect` que verifiquen que la infraestructura cumple el aislamiento de red.
  - *Criterio de Aceptación:* Los tests compilan con Swift Testing y pasan al ejecutarse con `xcodebuild test`.

---

## Grupo 4: Workflow CI/CD de GitHub Actions

- [x] **Task 4.1:** Crear `.github/workflows/build.yml` configurando los triggers para `main` y `dev` (push y PRs) y control de concurrencia.
  - *Criterio de Aceptación:* Workflow YAML válido sintetizado según especificación 001.
- [x] **Task 4.2:** Configurar en `build.yml` la selección de Xcode 16.x y la ejecución del paso `Run Network Guardrail Lint`.
  - *Criterio de Aceptación:* CI falla si el lint falla.
- [x] **Task 4.3:** Configurar el paso de `Build and Test (iOS Simulator)` con exportación de `TestResults.xcresult` y subida del artefacto siempre (`if: always()`).
  - *Criterio de Aceptación:* El archivo `test-results-xcresult` se publica en los artefactos de GitHub Actions.
- [x] **Task 4.4:** Configurar el paso de compilación Release y empaquetado `.ipa` no firmado (`Payload/SwipeCleaner.app` zipped a `SwipeCleaner-unsigned.ipa`).
  - *Criterio de Aceptación:* El pipeline genera la estructura `.ipa` correcta.
- [x] **Task 4.5:** Configurar la subida del artefacto `SwipeCleaner-unsigned-ipa` mediante `actions/upload-artifact@v4`.
  - *Criterio de Aceptación:* El artefacto `.ipa` está disponible para descarga al finalizar exitosamente el workflow.

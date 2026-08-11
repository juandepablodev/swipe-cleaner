# Tareas de Implementación (Tasks) — Feature 004: Eliminación por Lotes con PhotoKit

> **ID Feature:** `004-eliminacion-photokit`  
> **Estado:** Completado  
> **Especificación:** `spec/features/004-eliminacion-photokit/spec.md`  
> **Plan Técnico:** `spec/features/004-eliminacion-photokit/plan.md`

---

## Grupo 1: Capa de Modelos de Eliminación

- [x] **Task 1.1:** Crear `DeletionError.swift`, `SizeEstimate.swift` y `DeletionOutcome.swift` conformes a `Sendable` y `Equatable`.
  - *Criterio de Aceptación:* Ningún modelo contiene clases UIKit/PhotoKit no-Sendable.

---

## Grupo 2: Capa de Servicios de Eliminación PhotoKit

- [x] **Task 2.1:** Crear `PhotoKitDeletionServiceProtocol.swift` definiendo los contratos asíncronos para `estimateSize` y `deleteAssets`.
  - *Criterio de Aceptación:* El protocolo es `Sendable` y no expone `PHAsset`.
- [x] **Task 2.2:** Crear `PhotoKitDeletionService.swift` implementando la estimación de tamaño por recursos y la transacción con `PHAssetChangeRequest.deleteAssets`, traduciendo el código `3072` a `.userCancelled`.
  - *Criterio de Aceptación:* Mapea la cancelación del usuario y maneja assets inaccesibles.
- [x] **Task 2.3:** Crear `FakePhotoKitDeletionService.swift` permitiendo simular estimaciones de tamaño, borrados exitosos y cancelaciones para CI.
  - *Criterio de Aceptación:* Permite probar el ViewModel y la UI sin invocar la fototeca real del simulador.

---

## Grupo 3: ViewModel de Resumen de Sesión

- [x] **Task 3.1:** Crear `SessionSummaryViewModel.swift` anotado con `@Observable` y `@MainActor` incorporando el guard `deletionInFlight`.
  - *Criterio de Aceptación:* Gestiona el estado de borrado y el cálculo de tamaño sin reentrancia.

---

## Grupo 4: Componentes de Interfaz SwiftUI

- [x] **Task 4.1:** Crear `SummaryHeaderView.swift` y `DeletionSuccessView.swift` para visualización del espacio a liberar y pantalla de confirmación.
  - *Criterio de Aceptación:* Muestra la comunicación de seguridad (recuperables 30 días).
- [x] **Task 4.2:** Crear `SessionSummaryContainerView.swift` integrando la cabecera, carrusel de miniaturas, botones de acción y respuesta al resultado.
  - *Criterio de Aceptación:* Conmuta a la pantalla de éxito al finalizar la eliminación.

---

## Grupo 5: Pruebas Unitarias y Configuración de Proyecto Xcode

- [x] **Task 5.1:** Crear `SessionSummaryViewModelTests.swift` con Swift Testing verificando:
  - Formateo de bytes y presencia de prefijo "≥".
  - Transacción exitosa y actualización de `deletionCompleted`.
  - Manejo de `userCancelled` preservando el estado de la sesión.
  - Guard de atomicidad `deletionInFlight`.
  - Estimación de 500 assets sintéticos en < 200 ms.
  - *Criterio de Aceptación:* Pruebas unitarias pasan en CI.
- [x] **Task 5.2:** Actualizar `SwipeCleaner.xcodeproj/project.pbxproj` registrando todos los nuevos archivos de la Feature 004.
  - *Criterio de Aceptación:* `xcodebuild build` y `xcodebuild test` compilan sin errores en CI.

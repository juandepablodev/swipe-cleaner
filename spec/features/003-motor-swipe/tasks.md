# Tareas de Implementación (Tasks) — Feature 003: Motor de Swipe y Tarjetas Interactivas

> **ID Feature:** `003-motor-swipe`  
> **Estado:** Completado  
> **Especificación:** `spec/features/003-motor-swipe/spec.md`  
> **Plan Técnico:** `spec/features/003-motor-swipe/plan.md`

---

## Grupo 1: Capa de Modelos de Swipe

- [x] **Task 1.1:** Crear `SwipeDecision.swift` (`keep`, `delete`) y `ClassifiedAsset.swift` conformes a `Sendable` y `Equatable`.
  - *Criterio de Aceptación:* Los modelos compilan en Swift 6 sin advertencias.
- [x] **Task 1.2:** Crear `SessionResult.swift` struct `Sendable` para empaquetar las decisiones finales de la sesión.
  - *Criterio de Aceptación:* Exporta arrays inmutables de assets conservados y pendientes de eliminación.

---

## Grupo 2: Estimador de Velocidad y ViewModel Atómico

- [x] **Task 2.1:** Crear `VelocityEstimator.swift` calculando la velocidad horizontal `Δx/Δt` en ventanas de 100 ms.
  - *Criterio de Aceptación:* Retorna velocidades precisas a partir de muestras de arrastre sintéticas.
- [x] **Task 2.2:** Crear `SwipeEngineViewModel.swift` anotado con `@Observable` y `@MainActor` integrando el guard atómico `swipeInFlight` y el límite de 200 entradas en `historyStack`.
  - *Criterio de Aceptación:* Ignora peticiones de clasificación mientras `swipeInFlight` sea verdadero.
- [x] **Task 2.3:** Implementar la precarga acotada a 3 tarjetas (`preloadWindow()`) y la liberación de recursos en `SwipeEngineViewModel`.
  - *Criterio de Aceptación:* En todo momento `imageCache.count ≤ 3` y `activeRequests.count ≤ 3`.

---

## Grupo 3: Componentes de Interfaz SwiftUI

- [x] **Task 3.1:** Crear `CardView.swift` renderizando la foto/vídeo con badges "CONSERVAR" / "ELIMINAR", rotación dinámica y soporte para `accessibilityReduceMotion`.
  - *Criterio de Aceptación:* La rotación y el badge responden fluidamente al arrastre.
- [x] **Task 3.2:** Crear `CardStackView.swift` con `ZStack` de 2 tarjetas y manejo del gesto `DragGesture` utilizando `VelocityEstimator`.
  - *Criterio de Aceptación:* Desliza la tarjeta superior e invoca `swipeAnimationCompleted()` al finalizar.
- [x] **Task 3.3:** Crear `ActionBarView.swift` con los botones de Deshacer, Eliminar y Conservar.
  - *Criterio de Aceptación:* El botón Deshacer se deshabilita cuando el historial está vacío o hay una animación en vuelo.
- [x] **Task 3.4:** Crear `SwipeEngineContainerView.swift` unificando la pila de tarjetas, la barra de acciones y la transición al resumen cuando no quedan assets.
  - *Criterio de Aceptación:* Renderiza la experiencia completa de swipe.

---

## Grupo 4: Pruebas Unitarias y de Concurrencia

- [x] **Task 4.1:** Crear `SwipeEngineViewModelTests.swift` con Swift Testing validando:
  - Clasificación por umbrales y por `VelocityEstimator`.
  - Guard de atomicidad `swipeInFlight` frente a llamadas concurrentes.
  - Límite de `imageCache.count ≤ 3` tras 500 swipes.
  - Operación de deshacer (`undoLastDecision`).
  - Procesamiento de 1.000 swipes en < 100 ms.
  - *Criterio de Aceptación:* Tests pasan exitosamente en CI.

---

## Grupo 5: Integración en Proyecto Xcode

- [x] **Task 5.1:** Registrar todos los nuevos archivos de la Feature 003 en `SwipeCleaner.xcodeproj/project.pbxproj` en los targets `SwipeCleaner` y `SwipeCleanerTests`.
  - *Criterio de Aceptación:* `xcodebuild build` y `xcodebuild test` compilan sin errores en CI.

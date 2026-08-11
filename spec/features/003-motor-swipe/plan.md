# Plan Técnico — Feature 003: Motor de Swipe y Tarjetas Interactivas

> **ID Feature:** `003-motor-swipe`  
> **Estado:** En Implementación  
> **Target:** iOS 17.0+ | Swift 6 (Strict Concurrency Complete)  
> **Especificación de referencia:** `spec/features/003-motor-swipe/spec.md`

---

## 1. Arquitectura Técnica y Estrategia

Esta feature implementa el núcleo interactivo de **SwipeCleaner**: la pila de tarjetas estilo Tinder para clasificar fotos y vídeos mediante gestos de arrastre (`DragGesture`) o botones accesibles.

### Principios de Diseño
1. **Modelos 100% `Sendable`:** `SwipeDecision`, `ClassifiedAsset` y `SessionResult` son tipos inmutables conforme a `Sendable`.
2. **Guardia de Atomicidad (`swipeInFlight`):** Previene clasificaciones dobles o estados inconsistentes cuando se realizan swipes ultrarrápidos o pulsaciones de botones solapadas.
3. **Precarga Acotada (Ventana de 3 Tarjetas):** Mantiene en memoria como máximo las miniaturas de las 3 tarjetas superiores (`i`, `i+1`, `i+2`) y cancela las peticiones de los assets descartados.
4. **Estimador de Velocidad Novedoso (`VelocityEstimator`):** Calcula la velocidad horizontal (`Δx/Δt`) en ventanas de 100 ms para soportar gestos rápidos sin requerir APIs deprecadas o inexistentes en iOS 17.
5. **Historial de Deshacer Acotado:** Mantiene un límite de 200 entradas en `historyStack` para acotar la memoria durante sesiones largas.

---

## 2. Estructura de Archivos del Proyecto

```text
codigo/SwipeCleaner/
├── Features/
│   └── SwipeEngine/
│       ├── Models/
│       │   ├── SwipeDecision.swift             ← Enum keep / delete
│       │   ├── ClassifiedAsset.swift           ← Struct con decisión y timestamp
│       │   └── SessionResult.swift             ← Struct inmutable exportable a Feature 004
│       ├── ViewModels/
│       │   ├── SwipeEngineViewModel.swift      ← @Observable @MainActor VM con guard atómico
│       │   └── VelocityEstimator.swift         ← Cálculo de velocidad Δx/Δt (100 ms)
│       └── Views/
│           ├── SwipeEngineContainerView.swift  ← Contenedor principal de la sesión de swipe
│           ├── CardStackView.swift             ← ZStack de 2 tarjetas (activa + siguiente)
│           ├── CardView.swift                  ← Tarjeta con imagen, badge e indicadores CONSERVAR/ELIMINAR
│           └── ActionBarView.swift             ← Botones de Deshacer, Eliminar y Conservar
└── ...

codigo/SwipeCleanerTests/
└── SwipeEngineTests/
    └── SwipeEngineViewModelTests.swift         ← Swift Testing suite con FakePhotoLibraryService
```

---

## 3. Especificaciones de Componentes

### 3.1 Modelos
- `SwipeDecision`: `enum SwipeDecision: Sendable, Equatable { case keep, delete }`.
- `ClassifiedAsset`: `asset: AssetModel`, `decision: SwipeDecision`, `timestamp: Date`.
- `SessionResult`: `keep: [AssetModel]`, `pendingDeletion: [AssetModel]`.

### 3.2 Estimador de Velocidad
- `VelocityEstimator`: Mantiene un buffer de `(x: CGFloat, t: TimeInterval)` de los últimos 100 ms. Devuelve `horizontalVelocity` dividiendo el desplazamiento entre el delta de tiempo.

### 3.3 ViewModel (`SwipeEngineViewModel`)
- Atributos: `remainingAssets`, `historyStack` (máx 200), `swipeInFlight: Bool`, `imageCache` (máx 3), `activeRequests` (máx 3).
- `processDecision(_ decision: SwipeDecision)`: Verifica `!swipeInFlight`, activa `swipeInFlight = true`, registra en `historyStack`, cancela y libera recursos del asset descartado y llama a `preloadWindow()`.
- `swipeAnimationCompleted()`: Desactiva `swipeInFlight = false`.
- `undoLastDecision()`: Restaura el último asset en `remainingAssets[0]` y solicita de nuevo la precarga.

### 3.4 Vistas SwiftUI
- `CardStackView`: Renderiza únicamente 2 tarjetas en `ZStack` (siguiente con escala 0.95 y opacidad 0.8).
- `CardView`: Aplica `DragGesture`, rotación (`translation.width / 20`), resortes física y badges "CONSERVAR" (verde) / "ELIMINAR" (rojo). Soporta `accessibilityReduceMotion`.
- `ActionBarView`: Botones accesibles con estados habilitados/deshabilitados.

---

## 4. Plan de Verificación

| Criterio | Verificación | Resultado Esperado |
|---|---|---|
| **3.1 Umbrales y Velocidad** | `SwipeEngineViewModelTests` | Swipes > 120 pt o velocidad > 500 pt/s clasifican correctamente. |
| **3.2 Memoria & Precarga** | `SwipeEngineViewModelTests` | `imageCache.count ≤ 3` y `activeRequests.count ≤ 3` tras 500 swipes. |
| **3.3 Atomicidad** | `SwipeEngineViewModelTests` | Llamadas concurrentes procesan exactamente 1 asset sin duplicar. |
| **3.4 Deshacer (Undo)** | `SwipeEngineViewModelTests` | `undoLastDecision()` restaura el asset y actualiza el contador. |
| **3.5 Reduce Motion** | Pruebas de IU | Transiciones suaves de opacidad al habilitar Reduce Motion. |

# Especificación Funcional y Técnica (SDD) — Feature 003 (v2): Motor de Swipe y Tarjetas Interactivas

> **ID Feature:** `003-motor-swipe`
> **Estado:** Especificado (v2 — corregida: API de velocidad, atomicidad, cancelación y memoria)
> **Versión target:** iOS 17.0+ | Swift 6.0 (`SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`)
> **Ubicación del código:** `/codigo/SwipeCleaner/Features/SwipeEngine`
> **ViewModel central:** `SwipeEngineViewModel`
> **Dependencias:** Feature 001 (CI + lint de red), Feature 002 (`PhotoLibraryServiceProtocol`, `AssetModel`, invariante `isNetworkAccessAllowed = false`)

---

## 1. Visión General y Objetivos

Núcleo de interacción de **SwipeCleaner**: pila de tarjetas deslizables estilo Tinder para clasificar la galería mediante gestos o botones. Reutiliza **íntegramente** el `PhotoLibraryServiceProtocol` de la Feature 002 (manager inyectado, cancelación por `PHImageRequestID`, sin red).

### Objetivos Clave
1. Pila de tarjetas con `DragGesture`, física de muelle y overlays de intención ("CONSERVAR" verde / "ELIMINAR" rojo).
2. Ventana de precarga asíncrona de 3 imágenes a tamaño de pantalla con **cancelación explícita** de las peticiones de tarjetas descartadas.
3. Pila de decisiones en memoria con "Deshacer" instantáneo y animación física.
4. Botones accesibles y soporte de `accessibilityReduceMotion`.
5. Clasificación **atómica**: swipes concurrentes/solapados nunca clasifican dos assets ni desincronizan el historial.

---

## 2. Criterios de Aceptación

### Criterio 3.1: Clasificación por Gestos, Umbrales y Velocidad Estimada
- **Given** la tarjeta superior activa.
- **When** el arrastre supera +120 pt en X **o** la velocidad horizontal estimada es `> 500 pt/s` → swipe derecha: `keep`.
- **When** supera -120 pt **o** velocidad `< -500 pt/s` → swipe izquierda: `pendingDeletion`.
- **When** no se superan umbrales al soltar → retorno a (0,0) con `Spring(duration: 0.3, bounce: 0.2)`.
- **Nota vinculante (iOS 17):** `DragGesture.Value` **no expone `velocity`**. La velocidad se estima en el ViewModel/vista manteniendo las últimas muestras `(translation, timestamp)` de `onChanged` dentro de una ventana de 100 ms y calculando `Δx/Δt` (ver §5.2). El test unitario alimenta muestras sintéticas y verifica la clasificación.

### Criterio 3.2: Ventana de Precarga (3 Tarjetas), Cancelación, Vídeo Nativo y Calidad HD
- **Given** la tarjeta `i` en pantalla.
- **Then** el motor pre-carga vía `photoService.requestThumbnail` imágenes en alta resolución (`.opportunistic` con entrega progresiva y resolución final `.exact`) de `i`, `i+1`, `i+2`, registrando cada `PHImageRequestID` mediante `onRequestID`.
- **And** si la tarjeta activa es un vídeo (`asset.isVideo`), se solicita `requestPlayerItem` y se presenta mediante `VideoPlayerView` (`AVPlayerLayer`) reproduciéndose automáticamente en bucle con control de silencio gestionado en la pila activa.
- **And** al procesar la tarjeta `i`: se cancela su `PHImageRequestID` si sigue en vuelo, se eliminan sus entradas de `imageCache`, `playerItemCache` y `activeRequests`, y `i+3` entra en la cola.
- **And** invariantes testeables en CI: en todo momento `imageCache.count ≤ 3`, `playerItemCache.count ≤ 3`, `activeRequests.count ≤ 3` y `highQualityLoaded.count ≤ 3`, verificados con el `FakePhotoLibraryService` tras 500 operaciones de swipe.

### Criterio 3.3: Atomicidad de la Clasificación
- **Given** un swipe en curso cuya animación de salida aún no ha terminado.
- **When** llega un segundo gesto/botón antes de que termine.
- **Then** el segundo intento se **ignora o se encola** hasta que el primero finalice; en ningún caso se clasifican dos assets ni se desincroniza `historyStack` (guard `swipeInFlight` en §4.1).
- **And** test: dos llamadas concurrentes a `processDecision` clasifican exactamente un asset.

### Criterio 3.4: Deshacer (Undo Stack)
- **Given** al menos una decisión en `historyStack`.
- **When** el usuario pulsa "Deshacer".
- **Then** se desapila la última decisión, la tarjeta regresa al tope con animación física y el contador de `pendingDeletion` se actualiza inmediatamente.
- **And** la imagen del asset restaurado se re-solicita a la ventana de precarga.
- **And** `historyStack` tiene **límite de 200 entradas** (las más antiguas se purgan).

### Criterio 3.5: Botones Accesibles, Respuesta Táctiles y Desactivación de Back Gesture
- **When** el usuario toca "Check Verde" o "Papelera Roja" → misma clasificación con animación y respuesta háptica (`UIImpactFeedbackGenerator`).
- **And** con `accessibilityReduceMotion` activo, las animaciones de arrastre/salida se sustituyen por fundidos `.opacity`.
- **And** `SwipeEngineContainerView` deshabilita el botón nativo de atrás (`.navigationBarBackButtonHidden(true)`) para evitar que el gesto de arrastre desde el borde izquierdo active el pop del `NavigationStack` a la Galería.

---

## 3. Fuera de Alcance

1. Eliminación física en PhotoKit (Feature 004).
2. Edición o recorte.
3. Persistencia de sesión en disco. **Riesgo aceptado explícitamente:** si iOS mata la app, se pierden las clasificaciones de la sesión; la mitigación (checkpoint en disco) se evalúa como feature futura.

---

## 4. Diseño Arquitectónico y Modelos

### 4.1 Estado, Guard Atómico y Caché Acotada

```swift
import Foundation
import SwiftUI
import Photos

public enum SwipeDecision: Sendable, Equatable {
    case keep
    case delete
}

public struct ClassifiedAsset: Identifiable, Sendable, Equatable {
    public let asset: AssetModel
    public let decision: SwipeDecision
    public let timestamp: Date
    public var id: String { asset.id }
}

@Observable
@MainActor
public final class SwipeEngineViewModel {
    public private(set) var remainingAssets: [AssetModel] = []
    public private(set) var historyStack: [ClassifiedAsset] = []
    /// Guard de atomicidad (Criterio 3.3): true mientras la animación de
    /// salida de una tarjeta está en vuelo. Bloquea decisiones solapadas.
    public private(set) var swipeInFlight: Bool = false

    private static let historyLimit = 200

    public var currentAsset: AssetModel? { remainingAssets.first }
    public var nextAsset: AssetModel? { remainingAssets.dropFirst().first }
    public var pendingDeletionCount: Int { historyStack.filter { $0.decision == .delete }.count }

    /// Invariantes 3.2: count ≤ 3 en todo momento
    private var imageCache: [String: UIImage] = [:]
    private var activeRequests: [String: PHImageRequestID] = [:]

    private let photoService: PhotoLibraryServiceProtocol   // inyectado (Feature 002)

    public init(assets: [AssetModel], photoService: PhotoLibraryServiceProtocol) {
        self.remainingAssets = assets
        self.photoService = photoService
        preloadWindow()
    }

    /// Atómico: ignora llamadas mientras hay un swipe en vuelo (3.3).
    /// La vista llama a `swipeAnimationCompleted()` al terminar la animación.
    public func processDecision(_ decision: SwipeDecision) {
        guard !swipeInFlight, let asset = remainingAssets.first else { return }
        swipeInFlight = true

        historyStack.append(ClassifiedAsset(asset: asset, decision: decision, timestamp: Date()))
        if historyStack.count > Self.historyLimit { historyStack.removeFirst() }

        releaseResources(for: asset)
        remainingAssets.removeFirst()
        preloadWindow()
    }

    public func swipeAnimationCompleted() {
        swipeInFlight = false
    }

    public func undoLastDecision() {
        guard !swipeInFlight, let last = historyStack.popLast() else { return }
        remainingAssets.insert(last.asset, at: 0)
        preloadWindow()   // re-solicita la imagen liberada (3.4)
    }

    /// Cancelación explícita + liberación (Criterio 3.2, patrón de Feature 002)
    private func releaseResources(for asset: AssetModel) {
        if let requestID = activeRequests.removeValue(forKey: asset.id) {
            photoService.cancelImageRequest(requestID)
        }
        imageCache.removeValue(forKey: asset.id)
    }

    private func preloadWindow() {
        let window = Array(remainingAssets.prefix(3))
        let wanted = Set(window.map(\.id))

        // Cancelar peticiones de assets que salieron de la ventana
        for (id, requestID) in activeRequests where !wanted.contains(id) {
            photoService.cancelImageRequest(requestID)
            activeRequests.removeValue(forKey: id)
            imageCache.removeValue(forKey: id)
        }

        // Solicitar los que falten, registrando el requestID al crear la petición
        for asset in window where imageCache[asset.id] == nil && activeRequests[asset.id] == nil {
            Task {
                let image = await photoService.requestThumbnail(
                    for: asset,
                    targetSize: Self.displayTargetSize
                ) { [weak self] requestID in
                    Task { @MainActor in self?.activeRequests[asset.id] = requestID }
                }
                self.activeRequests.removeValue(forKey: asset.id)
                if let image { self.imageCache[asset.id] = image }
            }
        }
    }
}
```

**Notas vinculantes:**
- `displayTargetSize` se deriva del tamaño del contenedor vía `GeometryReader` × `displayScale`. **Prohibido `UIScreen.main`** (deprecated en iOS 17 y erróneo en multi-ventana).
- Todas las peticiones heredan el invariante de la Feature 002: `isNetworkAccessAllowed = false` (lint + test).
- Para colas muy largas, la implementación puede sustituir `[AssetModel]` por cursor + ventana (el `removeFirst()` es O(n)); el test 3.3/§8 lo acota, no lo prohíbe.

---

## 5. Diseño de Interfaz y Gestos

### 5.1 Jerarquía

```text
SwipeEngineContainerView
├── CardStackView (ZStack de 2 tarjetas)
│   ├── CardView (siguiente — scale 0.95, opacity 0.8)
│   └── CardView (activa — DragGesture, rotationEffect, offset)
│       ├── OverlayBadgeView ("CONSERVAR" si offset.width > 0)
│       └── OverlayBadgeView ("ELIMINAR" si offset.width < 0)
└── ActionBarView
    ├── UndoButton (disabled si historyStack vacío o swipeInFlight)
    ├── DeleteButton
    └── KeepButton
```

### 5.2 Física y Estimación de Velocidad (iOS 17)

Rotación: `grados = translation.width / 20`.

```swift
/// Estimador de velocidad: DragGesture.Value NO tiene `velocity` en iOS 17.
/// Se mantienen muestras (x, t) de los últimos 100 ms y se calcula Δx/Δt.
struct VelocityEstimator {
    private var samples: [(x: CGFloat, t: TimeInterval)] = []
    private let window: TimeInterval = 0.1

    mutating func add(x: CGFloat, at t: TimeInterval) {
        samples.append((x, t))
        samples.removeAll { t - $0.t > window }
    }

    var horizontalVelocity: CGFloat {
        guard let first = samples.first, let last = samples.last, last.t > first.t else { return 0 }
        return (last.x - first.x) / CGFloat(last.t - first.t)
    }
}
```

```swift
.gesture(
    DragGesture()
        .onChanged { g in
            offset = g.translation
            velocityEstimator.add(x: g.translation.width, at: g.time.timeIntervalSinceReferenceDate)
        }
        .onEnded { g in
            handleDragEnd(translation: g.translation,
                          velocityX: velocityEstimator.horizontalVelocity)
        }
)
```

Al completarse la animación de salida (o el retorno por muelle), la vista invoca `viewModel.swipeAnimationCompleted()`. Con `accessibilityReduceMotion`, la salida es un fundido y `swipeAnimationCompleted()` se invoca tras la transición de opacidad.

---

## 6. Rendimiento y Memoria

1. La `ZStack` renderiza **solo 2 tarjetas** (activa + siguiente).
2. Solo display-size en tarjetas; prohibido full-resolution salvo zoom explícito (fuera de alcance aquí).
3. Liberación triple al descartar: `cancelImageRequest` + `imageCache` + `activeRequests` (§4.1).
4. Invariantes CI: `imageCache.count ≤ 3`, `activeRequests.count ≤ 3` (testeables con el Fake; sustituyen al criterio de 150 MB, movido a verificación manual con Instruments).

---

## 7. Casos Límite

| Caso Límite | Comportamiento | Solución |
|---|---|---|
| Fin de cola (0 pendientes) | Navega a `SessionSummaryView` | `remainingAssets.isEmpty` |
| Swipes ultrarrápidos solapados | Segundo gesto ignorado/encolado; nunca doble clasificación | Guard `swipeInFlight` (3.3) |
| Vídeo en tarjeta activa | Reproducción nativa automática en bucle con AVPlayer/VideoPlayerView, control de silencio y badge de duración en la tarjeta superior activa; la tarjeta en espera muestra miniatura | AssetModel.isVideo + VideoPlayerView |
| Vídeo/foto solo en iCloud | Petición devuelve `nil` inmediatamente → placeholder (heredado de 002) | `isNetworkAccessAllowed = false` |
| Undo con historial vacío | Botón deshabilitado | `disabled(historyStack.isEmpty || swipeInFlight)` |
| Undo tras liberar imagen | Re-solicitud a la ventana de precarga con placeholder | §4.1 `undoLastDecision` |
| App matada por iOS a mitad de sesión | Se pierde la clasificación (riesgo aceptado §3) | Documentado; checkpoint futuro |

---

## 8. Guardarraíles de Verificación en CI

1. **Unit tests (`SwipeEngineViewModelTests`):**
   - `processDecision(.keep)` actualiza historial y avanza la cola.
   - Dos `processDecision` solapados clasifican **exactamente un** asset (Criterio 3.3).
   - `undoLastDecision()` restaura el asset en el tope y re-solicita su imagen.
   - Invariantes de memoria: tras 500 swipes sintéticos, `imageCache.count ≤ 3` y `activeRequests.count ≤ 3`; el Fake registra que cada asset descartado recibió `cancelImageRequest`.
   - 1.000 swipes < 100 ms total.
   - `VelocityEstimator`: muestras sintéticas a 600 pt/s clasifican por velocidad aunque translation < 120 pt.
2. **Cierre:** tests verdes en GitHub Actions + cero warnings de concurrencia (heredado de 001).

---

## 9. Contrato con la Feature 004

`SwipeEngineViewModel` expone al final de sesión un snapshot inmutable `SessionResult(keep: [AssetModel], pendingDeletion: [AssetModel])` (tipo `Sendable`) que la Feature 004 consume por inyección. No hay singleton ni estado global compartido (coherente con Feature 001).

---

## 10. Ejecución con Agentes y Skills

| Fase | Skill / Comando | Entrada | Salida |
|---|---|---|---|
| Planificación | `speckit.plan` | Este spec + specs 001/002 + `constitution.md` | `plan.md` |
| Desglose | `speckit.tasks` | `plan.md` | `tasks.md` |
| Implementación | `speckit.implement` | `tasks.md` | Código en `/Features/SwipeEngine` |
| Verificación | Checklist criterios 3.1–3.5 + lint Feature 001 | Código generado | Cierre de feature |

Regla del agente: los bloques de §4 y §5.2 son contratos vinculantes; cualquier desviación requiere actualizar este spec primero.

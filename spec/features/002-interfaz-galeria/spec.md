# Especificación Funcional y Técnica (SDD) — Feature 002 (v2): Carga de Galería e Interfaz PhotoKit

> **ID Feature:** `002-interfaz-galeria`
> **Estado:** Especificado (v2 — corregida tras análisis de concurrencia y contratos)
> **Versión target:** iOS 17.0+ | Swift 6.0 (`SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`)
> **Ubicación del código:** `/codigo/SwipeCleaner/Features/Gallery`
> **Protocolo principal:** `PhotoLibraryServiceProtocol`
> **Dependencias:** Feature 001 (CI + guardarraíl de red, invariante `isNetworkAccessAllowed = false`)

---

## 1. Visión General y Objetivos

Gestiona el ciclo de vida de permisos de PhotoKit y presenta la biblioteca en una cuadrícula fluida, ordenada por `creationDate` descendente. La capa de abstracción es **gruesa** (expone diffs incrementales y request IDs) para no destruir las propiedades clave de `PHFetchResult`/`PHCachingImageManager` al cruzar el protocolo.

### Objetivos Clave
1. Manejar reactivamente los 5 estados de autorización (`notDetermined`, `authorized`, `limited`, `denied`, `restricted`).
2. Grid con `PHCachingImageManager` inyectado (nunca `PHImageManager.default()`), prefetching con búfer y cancelación explícita por `PHImageRequestID`.
3. Sincronización incremental vía `PHPhotoLibraryChangeObserver` propagando **diffs**, no arrays completos.
4. Contrato 100% conforme a Swift 6 strict concurrency (compila con cero warnings bajo el criterio 1.1 de Feature 001).
5. Invariante de privacidad: **toda** petición de imagen usa `PHImageRequestOptions.isNetworkAccessAllowed = false` (coherente con el lint de Feature 001).

---

## 2. Criterios de Aceptación

### Criterio 2.1: Gestión Reactiva de Permisos
- **Given** la app en estado `notDetermined`.
- **When** el usuario pulsa "Dar acceso a la fototeca".
- **Then** se invoca `PHPhotoLibrary.requestAuthorization(for: .readWrite)`.
- **And** `authorized` → grid inmediato; `limited` → grid + banner con `presentLimitedLibraryPicker` (vía `UIViewControllerRepresentable` dedicado, §5.2); `denied`/`restricted` → pantalla con botón a `UIApplication.openSettingsURLString`.

### Criterio 2.2: Carga Eficiente de Miniaturas y Cancelación Real
- **Given** una biblioteca con miles de assets.
- **When** el usuario hace scroll.
- **Then** las imágenes se cargan con el `PHCachingImageManager` **inyectado**, `targetSize = celda × displayScale`.
- **And** la celda recibe el `PHImageRequestID` en el momento de crearse la petición (callback `onRequestID`), lo almacena y cancela en `onDisappear` **sobre la misma instancia del manager**.
- **And** al cancelarse el `Task` async, `withTaskCancellationHandler` cancela también el `PHImageRequestID` (sin peticiones huérfanas).
- **And** `updatePrefetchWindow` invoca `startCaching`/`stopCaching` sobre el rango visible ± 2 pantallas.

### Criterio 2.3: Sincronización Incremental (verificable)
- **Given** el grid visible.
- **When** ocurre un cambio externo en la fototeca.
- **Then** el servicio emite un `AssetLibraryChange` con `inserted`/`removed`/`changed` (IndexSets) y el `fetchResultAfterChanges` actualizado.
- **And** el ViewModel aplica el diff sin recargar el array completo ni reiniciar el scroll (test: mutación de 1 asset sobre 5.000 no re-emite los 4.999 restantes).

### Criterio 2.4: Testing en CI con Assets Sintéticos
- **Given** `FakePhotoLibraryService` con 5.000 assets.
- **When** corren los tests de `GalleryViewModel`.
- **Then** verifican en < 500 ms: orden cronológico inverso, transiciones de permiso, **rango exacto de `startCaching`/`stopCaching` en `updatePrefetchWindow`** (criterio nuevo), y aplicación correcta de un diff incremental.
- **And** un test de invariante verifica que toda petición del servicio real configura `isNetworkAccessAllowed = false`.

### Criterio 2.5: Rendimiento de Scroll (presupuesto medible)
- **Then** con los 5.000 assets del Fake, el renderizado de un frame de scroll no supera 8 ms en el dispositivo de CI (XCTest metric `XCTClockMetric` sobre `updatePrefetchWindow` + diff). Presupuesto orientativo para detectar regresiones, no benchmark absoluto.

---

## 3. Fuera de Alcance

1. Visualización a pantalla completa y reproducción de vídeo (Feature 003).
2. Gestos de swipe y descarte (Feature 003).
3. Eliminación de assets (Feature 004).

---

## 4. Diseño Arquitectónico y Contratos (corregido)

### 4.1 Modelo de Datos — sin tipos no-Sendable

```swift
import Foundation
import Photos
import SwiftUI

/// Asset para la capa de presentación. Sendable real:
/// NO contiene PHAsset (no conforma Sendable en Swift 6).
/// El PHAsset se resuelve bajo demanda por localIdentifier dentro del servicio.
public struct AssetModel: Identifiable, Sendable, Equatable {
    public let id: String            // = localIdentifier del PHAsset
    public let mediaType: PHAssetMediaType
    public let duration: TimeInterval
    public let creationDate: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int

    public var isVideo: Bool { mediaType == .video }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Diff incremental: preserva la granularidad de PHFetchResultChangeDetails
/// al cruzar el protocolo (corrige el cuello de botella de la v1).
public struct AssetLibraryChange: Sendable {
    public let inserted: IndexSet
    public let removed: IndexSet
    public let changed: IndexSet
    public let snapshotAfter: [AssetModel]   // solo para reconciliación; la UI aplica los IndexSets
    public let hasIncrementalChanges: Bool   // false = fetch result cambió por completo (reset)
}
```

### 4.2 Contrato del servicio — cancelación e instancia coherentes

```swift
public protocol PhotoLibraryServiceProtocol: Sendable {
    var authorizationStatus: PHAuthorizationStatus { get }
    func requestAuthorization() async -> PHAuthorizationStatus

    /// Snapshot lazy-paginable: el servicio real mantiene PHFetchResult interno
    /// y materializa por ventana, no los 50.000 assets de golpe.
    func fetchAssetCount() async -> Int
    func fetchAssets(in range: Range<Int>) async -> [AssetModel]

    /// El requestID se entrega SINCRÓNICAMENTE al crear la petición,
    /// porque es el único momento en que existe. La cancelación se aplica
    /// sobre la MISMA instancia de PHCachingImageManager que la creó.
    func requestThumbnail(
        for asset: AssetModel,
        targetSize: CGSize,
        onRequestID: @Sendable (PHImageRequestID) -> Void
    ) async -> UIImage?

    func cancelImageRequest(_ requestID: PHImageRequestID)
    func startCaching(for assets: [AssetModel], targetSize: CGSize)
    func stopCaching(for assets: [AssetModel], targetSize: CGSize)

    /// Stream de diffs (no arrays completos)
    func changeStream() -> AsyncStream<AssetLibraryChange>
}
```

**Notas de implementación obligatorias (vinculantes):**
- La implementación real (`PhotoLibraryService`) recibe su `PHCachingImageManager` **por inyección en el init** (prohibido `PHImageManager.default()`, coherente con la prohibición de singletons de Feature 001).
- `requestThumbnail` se implementa con `withCheckedContinuation` + `withTaskCancellationHandler`: el handler de cancelación invoca `cancelImageRequest(requestID)` sobre el manager inyectado.
- Toda petición construye `PHImageRequestOptions` con `isNetworkAccessAllowed = false` (lint + test de invariante).
- El bridge de `PHPhotoLibraryChangeObserver` se traduce a `AssetLibraryChange` aplicando `PHFetchResultChangeDetails` antes de emitir.

### 4.3 ViewModel

```swift
@Observable
@MainActor
public final class GalleryViewModel {
    public private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    public private(set) var assets: [AssetModel] = []
    public private(set) var isLoading: Bool = false
    public var errorMessage: String? = nil

    private let photoService: PhotoLibraryServiceProtocol
    private var changeTask: Task<Void, Never>?

    public init(photoService: PhotoLibraryServiceProtocol) {
        self.photoService = photoService
        self.authorizationStatus = photoService.authorizationStatus
    }

    public func checkAndRequestPermission() async { /* igual que v1 */ }

    public func loadGallery() async {
        isLoading = true
        defer { isLoading = false }
        let count = await photoService.fetchAssetCount()
        self.assets = await photoService.fetchAssets(in: 0..<count)
        startObservingChanges()
    }

    private func startObservingChanges() {
        changeTask?.cancel()
        changeTask = Task { [photoService] in
            for await change in photoService.changeStream() {
                await MainActor.run { [weak self] in self?.apply(change) }
            }
        }
    }

    func apply(_ change: AssetLibraryChange) {
        if !change.hasIncrementalChanges {
            assets = change.snapshotAfter        // reset completo
        } else {
            for i in change.removed.sorted().reversed() { assets.remove(at: i) }
            for i in change.inserted.sorted() { assets.insert(change.snapshotAfter[i], at: i) }
            for i in change.changed { assets[i] = change.snapshotAfter[i] }
        }
    }

    public func updatePrefetchWindow(visibleIndices: IndexSet, targetSize: CGSize) {
        guard let lo = visibleIndices.min(), let hi = visibleIndices.max() else { return }
        let page = max(hi - lo + 1, 1)
        let prefetch = max(lo - 2 * page, 0)..<min(hi + 2 * page + 1, assets.count)
        photoService.startCaching(for: Array(assets[prefetch]), targetSize: targetSize)
    }

    deinit { changeTask?.cancel() }
}
```

---

## 5. Diseño de Vistas SwiftUI

### 5.1 Jerarquía
1. `GalleryContainerView` conmuta por `authorizationStatus` (igual que v1).
2. `GalleryGridView`: `LazyVGrid` 3 columnas; cada `ThumbnailCellView`:
   - `@State private var requestID: PHImageRequestID?`
   - En `onAppear`/`.task`: llama a `requestThumbnail` pasando `onRequestID: { requestID = $0 }`.
   - En `onDisappear`: si hay ID, `photoService.cancelImageRequest(id)` sobre el servicio inyectado (misma instancia del manager).
3. Badge de duración de vídeo **formateado en el ViewModel** (`formattedDuration: String` derivado de `AssetModel.duration`), no en la vista (cierra la deuda señalada en el análisis).

### 5.2 Acceso Limitado
`LimitedLibraryPickerRepresentable: UIViewControllerRepresentable` dedicado que presenta `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)`. Prohibido el acceso informal a `keyWindow`/escenas (frágil entre versiones de iOS).

---

## 6. Concurrencia y Memoria

1. Prohibido cargar full-size en celdas; `targetSize = puntos × displayScale`.
2. Cancelación doble: `onDisappear` (cancelación por reciclaje) + `withTaskCancellationHandler` (cancelación por Task). Ambas sobre el manager inyectado.
3. Actualización de `assets` solo en `@MainActor`; el bridge del observer y la ordenación en background.
4. El filtrado de `PHFetchResult` se materializa **por ventanas** (`fetchAssets(in:)`), nunca el fetch completo (corrige el riesgo de memoria de la v1 con bibliotecas de 50.000+ assets).

---

## 7. Casos Límite

| Caso Límite | Comportamiento | Solución |
|---|---|---|
| Galería vacía | `ContentUnavailableView` | Estado explícito |
| Permiso revocado en Ajustes | iOS reinicia el proceso; reevaluar en `onAppear` | ViewModel |
| Asset solo en iCloud | Petición devuelve `nil` inmediatamente (`isNetworkAccessAllowed = false`) → placeholder gris, sin reintentos | Invariante + test 2.4 |
| Scroll agresivo | `onDisappear` cancela requests en vuelo; `stopCaching` descarta prefetch obsoleto — son mecanismos distintos, ambos obligatorios | §6.2 |
| Diff masivo sin `changeDetails` | `hasIncrementalChanges = false` → reset de `snapshotAfter` | §4.3 `apply` |

---

## 8. Guardarraíles de Verificación en CI

1. Unit tests con `FakePhotoLibraryService`: transiciones de permiso, orden inverso, **rango de prefetch exacto** (2.4), aplicación de diffs, cancelación registrada sobre el mock del manager.
2. Test de invariante: toda petición usa `isNetworkAccessAllowed = false`.
3. Test de rendimiento con `XCTClockMetric` (criterio 2.5).
4. **Cierre:** tests verdes en GitHub Actions + cero warnings de concurrencia (heredado de Feature 001).

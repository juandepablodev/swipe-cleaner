# Plan Técnico — Feature 002: Carga de Galería e Interfaz PhotoKit

> **ID Feature:** `002-interfaz-galeria`  
> **Estado:** En Implementación  
> **Target:** iOS 17.0+ | Swift 6 (Strict Concurrency Complete)  
> **Especificación de referencia:** `spec/features/002-interfaz-galeria/spec.md`

---

## 1. Arquitectura Técnica y Estrategia

Esta feature implementa el servicio de fototeca con PhotoKit y la interfaz de usuario en cuadrícula para navegar por las fotos/vídeos del usuario ordenados por fecha de creación descendente.

### Principios de Diseño
1. **Modelos 100% `Sendable`:** `AssetModel` y `AssetLibraryChange` son independientes de tipos UIKit/PhotoKit no-Sendable (`PHAsset` no se expone fuera del servicio).
2. **Inyección de Dependencias:** `PhotoLibraryService` recibe una instancia de `PHCachingImageManager` en el init. Prohibido usar `PHImageManager.default()`.
3. **Invariante de Red Local:** Peticiones de miniaturas configuran `isNetworkAccessAllowed = false` en `PHImageRequestOptions`.
4. **Sincronización Incremental:** `PHPhotoLibraryChangeObserver` genera `AssetLibraryChange` con `IndexSet` de inserts, removes y changes para evitar recargar el array completo en el ViewModel.
5. **UI SwiftUI Reactiva:** `GalleryContainerView` conmuta vistas según los 5 estados de `PHAuthorizationStatus`.

---

## 2. Estructura de Archivos del Proyecto

```text
codigo/SwipeCleaner/
├── Features/
│   └── Gallery/
│       ├── Models/
│       │   ├── AssetModel.swift                 ← Struct Sendable con metadatos del asset
│       │   └── AssetLibraryChange.swift          ← Diff incremental (IndexSets)
│       ├── Services/
│       │   ├── PhotoLibraryServiceProtocol.swift ← Contrato del servicio
│       │   ├── PhotoLibraryService.swift         ← Implementación real PhotoKit
│       │   └── FakePhotoLibraryService.swift     ← Fake mock para pruebas y CI
│       ├── ViewModels/
│       │   └── GalleryViewModel.swift            ← @Observable @MainActor VM
│       └── Views/
│           ├── GalleryContainerView.swift        ← Enrutador por estado de permisos
│           ├── GalleryGridView.swift             ← Grid 3 columnas + LazyVGrid + prefetch
│           ├── ThumbnailCellView.swift           ← Celda individual con manejo de PHImageRequestID
│           └── PermissionViews.swift             ← Vistas de permiso denegado, no determinado y LimitedPicker
└── ...

codigo/SwipeCleanerTests/
└── GalleryTests/
    ├── GalleryViewModelTests.swift               ← Tests Swift Testing con Fake (5.000 assets)
    ├── PhotoLibraryServiceInvariantTests.swift   ← Test de invariante isNetworkAccessAllowed = false
    └── GalleryPerformanceTests.swift             ← Test XCTClockMetric de scroll
```

---

## 3. Especificaciones de Componentes

### 3.1 Modelos
- `AssetModel`: `id: String` (`localIdentifier`), `mediaType`, `duration`, `creationDate`, `pixelWidth`, `pixelHeight`, `formattedDuration: String`.
- `AssetLibraryChange`: `inserted: IndexSet`, `removed: IndexSet`, `changed: IndexSet`, `snapshotAfter: [AssetModel]`, `hasIncrementalChanges: Bool`.

### 3.2 Servicio PhotoKit
- Implementa `PHPhotoLibraryChangeObserver` canalizado a `AsyncStream<AssetLibraryChange>`.
- `requestThumbnail` entrega el `PHImageRequestID` síncronamente en `onRequestID` y se envuelve en `withTaskCancellationHandler` para cancelar sobre el `PHCachingImageManager` inyectado.
- `updatePrefetchWindow`: invoca `startCachingImages`/`stopCachingImages` en rangos visibles ± 2 pantallas.

### 3.3 ViewModel
- `@Observable @MainActor class GalleryViewModel`.
- Métodos: `checkAndRequestPermission()`, `loadGallery()`, `apply(_ change:)`, `updatePrefetchWindow(visibleIndices:targetSize:)`.

### 3.4 Vistas SwiftUI
- `GalleryContainerView`: conmuta entre `NotDeterminedPermissionView`, `GalleryGridView`, `PermissionDeniedView`.
- `ThumbnailCellView`: administra el ciclo de vida de la petición de miniatura con `@State private var requestID: PHImageRequestID?`.
- `LimitedLibraryPickerRepresentable`: `UIViewControllerRepresentable` para `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)`.

---

## 4. Plan de Verificación

| Criterio | Verificación | Resultado Esperado |
|---|---|---|
| **2.1 Permisos Reactivos** | Unit tests & UI flow | Conmutación correcta entre los 5 estados de autorización. |
| **2.2 Miniaturas y Cancelación** | `GalleryViewModelTests` | Cancelación explícita mediante `cancelImageRequest` verificada en Fake. |
| **2.3 Diff Incremental** | `GalleryViewModelTests` | Aplicación de `IndexSet` sin modificar elementos no alterados. |
| **2.4 Testing sintético 5k** | `GalleryViewModelTests` | Suite ejecutada en < 500 ms con 5.000 assets simulados. |
| **2.5 Invariante Privacidad** | `PhotoLibraryServiceInvariantTests` | `isNetworkAccessAllowed` es siempre `false`. |

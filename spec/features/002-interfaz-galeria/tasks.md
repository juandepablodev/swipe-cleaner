# Tareas de Implementación (Tasks) — Feature 002: Carga de Galería e Interfaz PhotoKit

> **ID Feature:** `002-interfaz-galeria`  
> **Estado:** Completado  
> **Especificación:** `spec/features/002-interfaz-galeria/spec.md`  
> **Plan Técnico:** `spec/features/002-interfaz-galeria/plan.md`

---

## Grupo 1: Capa de Modelos de Dominio

- [x] **Task 1.1:** Crear `AssetModel.swift` con conformación estricta a `Sendable`, `Identifiable`, `Equatable` y derivación de `formattedDuration`.
  - *Criterio de Aceptación:* `AssetModel` no contiene ninguna propiedad no-Sendable y compila sin advertencias en Swift 6.
- [x] **Task 1.2:** Crear `AssetLibraryChange.swift` estructurando el diff incremental (`inserted`, `removed`, `changed`, `snapshotAfter`, `hasIncrementalChanges`).
  - *Criterio de Aceptación:* `AssetLibraryChange` conforma a `Sendable` y representa fielmente los cambios de la fototeca.

---

## Grupo 2: Capa de Servicios e Inyección de PhotoKit

- [x] **Task 2.1:** Crear `PhotoLibraryServiceProtocol.swift` definiendo los métodos asíncronos de autorización, fetch por rangos, miniaturas con callback de ID, caching y `changeStream()`.
  - *Criterio de Aceptación:* Protocolo conforma a `Sendable` sin exponer tipos `PHAsset`/`PHFetchResult`.
- [x] **Task 2.2:** Crear `PhotoLibraryService.swift` implementando el protocolo real con `PHCachingImageManager` inyectado e invariante `isNetworkAccessAllowed = false`.
  - *Criterio de Aceptación:* Implementa `PHPhotoLibraryChangeObserver` y emite diffs por `AsyncStream`.
- [x] **Task 2.3:** Crear `FakePhotoLibraryService.swift` con soporte para simulación de 5.000 assets, estados de autorización, registro de rangos de prefetch y cancelación de requests.
  - *Criterio de Aceptación:* Permite testear el ViewModel y la UI sin acceder a la fototeca real del simulador.

---

## Grupo 3: ViewModel de Galería

- [x] **Task 3.1:** Crear `GalleryViewModel.swift` anotado con `@Observable` y `@MainActor`.
  - *Criterio de Aceptación:* Mantiene el estado mutable (`authorizationStatus`, `assets`, `isLoading`, `errorMessage`) de forma segura.
- [x] **Task 3.2:** Implementar en `GalleryViewModel` los métodos `checkAndRequestPermission()`, `loadGallery()`, `apply(_ change:)` y `updatePrefetchWindow()`.
  - *Criterio de Aceptación:* Aplica diffs incrementales sin re-crear la lista completa y gestiona ventanas de prefetch de ± 2 pantallas.

---

## Grupo 4: Componentes de Interfaz SwiftUI

- [x] **Task 4.1:** Crear `ThumbnailCellView.swift` con visualización de imagen, badge de vídeo y ciclo de vida de `PHImageRequestID` (`onAppear` / `onDisappear`).
  - *Criterio de Aceptación:* Cancela la petición de miniatura al desaparecer la celda.
- [x] **Task 4.2:** Crear `GalleryGridView.swift` utilizando `LazyVGrid` de 3 columnas y detección de índices visibles para prefetch.
  - *Criterio de Aceptación:* Renderiza la cuadrícula fluida y dispara `updatePrefetchWindow`.
- [x] **Task 4.3:** Crear `PermissionViews.swift` implementando `NotDeterminedPermissionView`, `PermissionDeniedView` y `LimitedLibraryPickerRepresentable`.
  - *Criterio de Aceptación:* `LimitedLibraryPickerRepresentable` presenta el picker nativo de iOS para selección limitada.
- [x] **Task 4.4:** Crear `GalleryContainerView.swift` actuando como enrutador principal del estado de autorización.
  - *Criterio de Aceptación:* Muestra la vista apropiada según el estado reactivo de permisos.

---

## Grupo 5: Pruebas Unitarias y de Rendimiento

- [x] **Task 5.1:** Crear `GalleryViewModelTests.swift` con Swift Testing validando 5.000 assets sintéticos en < 500 ms, transiciones de permiso, orden inverso y diffs.
  - *Criterio de Aceptación:* Tests pasan en CI.
- [x] **Task 5.2:** Crear `PhotoLibraryServiceInvariantTests.swift` verificando que las peticiones reales configuran `isNetworkAccessAllowed = false`.
  - *Criterio de Aceptación:* Test de invariante pasa.
- [x] **Task 5.3:** Crear `GalleryPerformanceTests.swift` midiendo el presupuesto de renderizado de scroll (< 8 ms por frame) usando `XCTClockMetric`.
  - *Criterio de Aceptación:* Test de rendimiento registrado en CI.

---

## Grupo 6: Integración en Xcode Project y CI

- [x] **Task 6.1:** Actualizar `SwipeCleaner.xcodeproj/project.pbxproj` agregando los nuevos archivos de la Feature 002 en los targets `SwipeCleaner` y `SwipeCleanerTests`.
  - *Criterio de Aceptación:* `xcodebuild build` y `xcodebuild test` compilan sin errores en CI.

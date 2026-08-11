# Plan Técnico — Feature 004: Eliminación por Lotes con PhotoKit

> **ID Feature:** `004-eliminacion-photokit`  
> **Estado:** En Implementación  
> **Target:** iOS 17.0+ | Swift 6 (Strict Concurrency Complete)  
> **Especificación de referencia:** `spec/features/004-eliminacion-photokit/spec.md`

---

## 1. Arquitectura Técnica y Estrategia

Esta feature implementa la fase final del flujo: la revisión de la sesión de clasificación, estimación del espacio a liberar y la eliminación no destructiva por lotes mediante PhotoKit.

### Principios de Diseño
1. **Modelos 100% `Sendable`:** `SizeEstimate`, `DeletionOutcome` y `DeletionError` son tipos inmutables libres de referencias a `PHAsset`.
2. **Estimación Declarada de Tamaño:** Calcula el tamaño sumando recursos (`PHAssetResource`) en background y muestra el prefijo `"≥"` si existen recursos con tamaño desconocido.
3. **Traducción de Errores del Dominio:** Mapea el código de cancelación nativo de iOS (`3072`) a `.userCancelled` garantizando que la clasificación permanece intacta.
4. **Borrado No Destructivo:** La eliminación envía los assets a "Eliminados recientemente" de iOS (recuperables durante 30 días).
5. **Actualización Reactiva de Galería:** No modifica manualmente el estado de la galería; confía en el `PHPhotoLibraryChangeObserver` de la Feature 002.

---

## 2. Estructura de Archivos del Proyecto

```text
codigo/SwipeCleaner/
├── Features/
│   └── BatchDeletion/
│       ├── Models/
│       │   ├── DeletionError.swift             ← Enum userCancelled / deletionFailed
│       │   ├── SizeEstimate.swift              ← Struct bytes y recursos desconocidos
│       │   └── DeletionOutcome.swift           ← Struct con IDs borrados y no accesibles
│       ├── Services/
│       │   ├── PhotoKitDeletionServiceProtocol.swift ← Contrato del servicio
│       │   ├── PhotoKitDeletionService.swift   ← Servicio PhotoKit real (performChanges)
│       │   └── FakePhotoKitDeletionService.swift ← Fake mock para tests unitarios
│       ├── ViewModels/
│       │   └── SessionSummaryViewModel.swift   ← @Observable @MainActor VM con deletionInFlight
│       └── Views/
│           ├── SessionSummaryContainerView.swift ← Contenedor principal de resumen
│           ├── SummaryHeaderView.swift         ← Cabecera con recuento y espacio estimado
│           └── DeletionSuccessView.swift       ← Vista de éxito y confirmación de papelera
└── ...

codigo/SwipeCleanerTests/
└── BatchDeletionTests/
    └── SessionSummaryViewModelTests.swift      ← Tests Swift Testing con Fake (cálculo, borrado, cancelación)
```

---

## 3. Especificaciones de Componentes

### 3.1 Modelos
- `DeletionError`: `userCancelled`, `deletionFailed(String)`.
- `SizeEstimate`: `totalBytes: Int64`, `assetsWithUnknownSize: Int`.
- `DeletionOutcome`: `deletedIDs: [String]`, `inaccessibleIDs: [String]`.

### 3.2 Servicio de Eliminación
- `PhotoKitDeletionService`: Resuelve `PHAsset` por `localIdentifier` internamente.
- `estimateSize`: Suma `fileSize` de `PHAssetResource` en `Task.detached`.
- `deleteAssets`: Ejecuta `PHPhotoLibrary.shared().performChanges` con `PHAssetChangeRequest.deleteAssets`. Intercepta error `3072` lanzando `DeletionError.userCancelled`.

### 3.3 ViewModel (`SessionSummaryViewModel`)
- Atributos: `session: SessionResult`, `estimatedSizeText: String`, `isDeleting: Bool`, `deletionInFlight: Bool`, `deletionCompleted: Bool`, `userMessage: String?`.
- `computeSize()`: Formatea bytes usando `ByteCountFormatter` agregando `"≥"` si hay desconocidos.
- `executeBatchDeletion()`: Protegido por `guard !deletionInFlight`. Maneja `.userCancelled` y errores sin destruir el estado de la sesión.

### 3.4 Vistas SwiftUI
- `SessionSummaryContainerView`: Muestra resumen, carrusel de miniaturas y botones de acción.
- `DeletionSuccessView`: Pantalla festiva de confirmación indicando que los archivos son recuperables durante 30 días.

---

## 4. Plan de Verificación

| Criterio | Verificación | Resultado Esperado |
|---|---|---|
| **4.1 Cálculo de Espacio** | `SessionSummaryViewModelTests` | Formato correcto MB/GB y prefijo "≥" en < 200 ms. |
| **4.2 Transacción Nativa** | `SessionSummaryViewModelTests` | `executeBatchDeletion` exitoso genera `deletionCompleted = true`. |
| **4.3 Cancelación Nativa** | `SessionSummaryViewModelTests` | `.userCancelled` genera mensaje amigable y mantiene sesión. |
| **4.4 Sincronización Reactiva** | Pruebas de integración | El observer de la Feature 002 refleja el borrado automáticamente. |

# Especificación Funcional y Técnica (SDD) — Feature 004 (v2): Eliminación por Lotes con PhotoKit

> **ID Feature:** `004-eliminacion-photokit`
> **Estado:** Especificado (v2 — corregida: Sendable, contrato SessionResult, cancelación nativa, sincronización reactiva)
> **Versión target:** iOS 17.0+ | Swift 6.0 (`SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`)
> **Ubicación del código:** `/codigo/SwipeCleaner/Features/BatchDeletion`
> **Servicio clave:** `PhotoKitDeletionService`
> **Dependencias:** Feature 001 (CI + lint), Feature 002 (`AssetModel`, observer de cambios, invariante `isNetworkAccessAllowed = false`), Feature 003 (contrato `SessionResult`)

---

## 1. Visión General y Objetivos

Etapa final del flujo de **SwipeCleaner**: revisión de la sesión de clasificación, estimación del espacio a liberar y eliminación segura por lotes con PhotoKit. Consume el `SessionResult` producido por la Feature 003 y delega la actualización del grid en el observer de cambios de la Feature 002 (fuente única de verdad).

### Objetivos Clave
1. Pantalla de Resumen de Sesión con lista de assets `pendingDeletion` y espacio total formateado.
2. Transacción de borrado masivo con `PHAssetChangeRequest.deleteAssets`, que desencadena la alerta nativa del sistema.
3. Borrado **100% no destructivo**: los assets van a "Eliminados recientemente" (recuperables 30 días) — y el copy de la app lo comunica explícitamente.
4. Manejo explícito de la cancelación del diálogo nativo (código de dominio PhotoKit), errores parciales y assets no accesibles.
5. Compatibilidad total con strict concurrency: ningún `PHAsset` cruza fronteras de actor (se resuelve por `localIdentifier` dentro del servicio).

---

## 2. Criterios de Aceptación

### Criterio 4.1: Cálculo de Espacio con Semántica Declarada
- **Given** el `SessionResult.pendingDeletion` de la sesión.
- **When** el usuario entra al Resumen.
- **Then** el servicio resuelve los `PHAsset` por `localIdentifier` y suma `fileSize` de los recursos (`PHAssetResource`).
- **And** semántica declarada: la cifra es la **suma de todos los recursos asociados** al asset (incluye componentes de Live Photo); es una estimación hacia arriba, no el tamaño exacto del archivo principal.
- **And** los recursos sin `fileSize` disponible se contabilizan aparte: si existen, la UI muestra el total como `"≥ 450 MB"` en vez de un 0 engañoso.
- **And** el cálculo completa en < 200 ms para 500 assets (test con Fake).
- **Riesgo aceptado (declarado):** `fileSize` se obtiene vía KVO no documentado de `PHAssetResource`; si Apple lo elimina, el fallback es mostrar "Tamaño no disponible" (nunca crash ni 0 MB falso). Verificado por test del Fake.

### Criterio 4.2: Transacción Nativa de Borrado
- **Given** la confirmación en la UI de Resumen.
- **When** el usuario pulsa "Confirmar y Limpiar Galería".
- **Then** se ejecuta `PHPhotoLibrary.shared().performChanges` con `PHAssetChangeRequest.deleteAssets`.
- **And** se muestra el diálogo nativo de iOS; al aceptar, los assets van a "Eliminados recientemente".
- **And** durante la transacción el botón queda deshabilitado (`deletionInFlight`, mismo patrón de guard atómico de la Feature 003): reintentos imposibles.
- **And** los assets cuyo `localIdentifier` ya no se resuelve (p. ej., retirados del acceso limitado) se excluyen del lote y se reportan: `"N fotos no accesibles no se han eliminado"`.

### Criterio 4.3: Cancelación del Diálogo Nativo (manejo explícito)
- **Given** la alerta nativa de iOS en pantalla.
- **When** el usuario pulsa "No permitir"/Cancelar.
- **Then** `performChanges` completa con `success = false` y error del dominio `PHPhotosErrorDomain` con código de cancelación de usuario.
- **And** el servicio traduce ese código al caso `.userCancelled` del error propio (§4.1) — **no** se muestra `error.localizedDescription` técnico.
- **And** la app conserva la clasificación de la sesión intacta y muestra: `"Operación cancelada. Tus fotos no han sido modificadas."`
- **And** otros errores (permisos, fallo interno) se mapean a `.deletionFailed` con mensaje de reintento.

### Criterio 4.4: Sincronización Reactiva (sin acoplamiento)
- **Given** el borrado exitoso.
- **Then** la app **no modifica manualmente** el `GalleryViewModel`: el `PHPhotoLibraryChangeObserver` de la Feature 002 emite el diff y el grid se actualiza solo (criterio 2.3 ya testeado).
- **And** se muestra `DeletionSuccessView` con nº de elementos, espacio recuperado y el mensaje: `"Recuperables durante 30 días en Eliminados recientemente"`.
- **And** si iOS mata la app a mitad de transacción, al reabrir los assets no borrados reaparecen en el grid automáticamente (vía observer) — comportamiento declarado, sin persistencia de sesión.

---

## 3. Fuera de Alcance

1. Eliminación permanente/shredding (prohibido por diseño y por iOS).
2. Borrado en nube (iCloud Photos lo gestiona iOS al borrar localmente).
3. Gestión de álbumes del sistema.
4. Persistencia de sesión entre arranques (coherente con Feature 003 §3).

---

## 4. Diseño Arquitectónico

### 4.1 Servicio — resolución por `localIdentifier` (sin `PHAsset` en structs)

```swift
import Foundation
import Photos

/// Error propio con cancelación explícita (Criterio 4.3)
public enum DeletionError: Error, Sendable, Equatable {
    case userCancelled
    case deletionFailed(String)
}

/// Resultado del cálculo de tamaño (Criterio 4.1)
public struct SizeEstimate: Sendable, Equatable {
    public let totalBytes: Int64
    public let assetsWithUnknownSize: Int   // > 0 → la UI muestra "≥"
}

public protocol PhotoKitDeletionServiceProtocol: Sendable {
    func estimateSize(for assets: [AssetModel]) async -> SizeEstimate
    /// Devuelve los IDs efectivamente borrados y los no resolubles
    func deleteAssets(_ assets: [AssetModel]) async throws -> DeletionOutcome
}

public struct DeletionOutcome: Sendable, Equatable {
    public let deletedIDs: [String]
    public let inaccessibleIDs: [String]
}

public final class PhotoKitDeletionService: PhotoKitDeletionServiceProtocol {
    public init() {}

    /// Resuelve PHAsset DENTRO del servicio, en background, por localIdentifier.
    /// AssetModel sigue siendo Sendable puro (Feature 002 v2).
    private func resolvePHAssets(from models: [AssetModel]) -> (found: [PHAsset], missing: [String]) {
        let ids = models.map(\.id)
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var found: [PHAsset] = []
        var foundIDs = Set<String>()
        result.enumerateObjects { asset, _, _ in
            found.append(asset)
            foundIDs.insert(asset.localIdentifier)
        }
        let missing = ids.filter { !foundIDs.contains($0) }
        return (found, missing)
    }

    public func estimateSize(for assets: [AssetModel]) async -> SizeEstimate {
        await Task.detached(priority: .userInitiated) {
            let (found, _) = self.resolvePHAssets(from: assets)
            var total: Int64 = 0
            var unknown = 0
            for phAsset in found {
                let resources = PHAssetResource.assetResources(for: phAsset)
                var assetBytes: Int64 = 0
                var hasUnknown = false
                for resource in resources {
                    if let size = resource.value(forKey: "fileSize") as? Int64 {
                        assetBytes += size
                    } else {
                        hasUnknown = true
                    }
                }
                total += assetBytes
                if hasUnknown { unknown += 1 }
            }
            return SizeEstimate(totalBytes: total, assetsWithUnknownSize: unknown)
        }.value
    }

    public func deleteAssets(_ assets: [AssetModel]) async throws -> DeletionOutcome {
        let (found, missing) = await Task.detached { self.resolvePHAssets(from: assets) }.value
        guard !found.isEmpty else {
            return DeletionOutcome(deletedIDs: [], inaccessibleIDs: missing)
        }
        let deletedIDs = found.map(\.localIdentifier)
        let nsArray = found as NSArray

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(nsArray)
                }, completionHandler: { success, error in
                    if let error { cont.resume(throwing: error) }
                    else if success { cont.resume() }
                    else { cont.resume(throwing: DeletionError.deletionFailed("Sin detalle")) }
                })
            }
            return DeletionOutcome(deletedIDs: deletedIDs, inaccessibleIDs: missing)
        } catch let nsError as NSError
            where nsError.domain == "PHPhotosErrorDomain"
               && nsError.code == 3072 {  // cancelación de usuario en el diálogo nativo
            throw DeletionError.userCancelled
        } catch {
            throw DeletionError.deletionFailed(error.localizedDescription)
        }
    }
}
```

**Notas vinculantes:**
- El código `3072` de `PHPhotosErrorDomain` se encapsula en una constante documentada (`private static let userCancelledCode = 3072`) con test que verifica el mapeo a `.userCancelled` (Criterio 4.3). Si Apple introduce un código dedicado de cancelación en SDKs futuros, basta actualizar la constante.
- Assets solo en iCloud (no descargados): el borrado los elimina igualmente de la biblioteca (PhotoKit no requiere los bytes locales para borrar); la estimación de tamaño puede ser parcial para ellos → contabilizados en `assetsWithUnknownSize`.

### 4.2 ViewModel — consume `SessionResult` (contrato Feature 003 §9)

```swift
@Observable
@MainActor
public final class SessionSummaryViewModel {
    public private(set) var session: SessionResult
    public private(set) var estimatedSizeText: String = "Calculando…"
    public private(set) var isDeleting: Bool = false
    public private(set) var deletionInFlight: Bool = false   // guard atómico (4.2)
    public private(set) var deletionCompleted: Bool = false
    public private(set) var deletionOutcome: DeletionOutcome? = nil
    public var userMessage: String? = nil

    private let deletionService: PhotoKitDeletionServiceProtocol

    public init(session: SessionResult, deletionService: PhotoKitDeletionServiceProtocol) {
        self.session = session
        self.deletionService = deletionService
        Task { await computeSize() }
    }

    public func computeSize() async {
        let estimate = await deletionService.estimateSize(for: session.pendingDeletion)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        let base = formatter.string(fromByteCount: estimate.totalBytes)
        self.estimatedSizeText = estimate.assetsWithUnknownSize > 0 ? "≥ \(base)" : base
    }

    public func executeBatchDeletion() async {
        guard !deletionInFlight else { return }
        deletionInFlight = true
        isDeleting = true
        defer { isDeleting = false; deletionInFlight = false }

        do {
            let outcome = try await deletionService.deleteAssets(session.pendingDeletion)
            deletionOutcome = outcome
            deletionCompleted = true
        } catch DeletionError.userCancelled {
            userMessage = "Operación cancelada. Tus fotos no han sido modificadas."
        } catch DeletionError.deletionFailed(let detail) {
            userMessage = "No se pudo completar la eliminación. Puedes reintentarlo. (\(detail))"
        } catch {
            userMessage = "Error inesperado al eliminar."
        }
    }
}
```

---

## 5. Diseño de Interfaz (SwiftUI)

```text
SessionSummaryContainerView
├── SummaryHeaderView (nº de marcadas + estimatedSizeText)
├── InaccessibleBannerView (si outcome.inaccessibleIDs no vacío)
├── AssetPreviewScrollView (carrusel de miniaturas via photoService de Feature 002)
├── ActionFooterView
│   ├── ConfirmDeletionButton (rojo, disabled si deletionInFlight)
│   └── KeepReviewingButton (volver al swipe)
└── DeletionSuccessView (celebración + "Recuperables durante 30 días en Eliminados recientemente")
```

El `ConfirmDeletionButton` muestra `ProgressView` indeterminado durante la transacción (PhotoKit no reporta progreso parcial — caso límite §7 declarado).

---

## 6. Concurrencia y Errores

1. `estimateSize` y la resolución de `PHAsset` ocurren en `Task.detached` — pero los `PHAsset` (no-Sendable) **nunca salen del servicio ni cruzan actores**: solo viajan IDs (`String`) y estructuras Sendable (`SizeEstimate`, `DeletionOutcome`).
2. Guard `deletionInFlight` idéntico al patrón `swipeInFlight` de la Feature 003: transacción no reentrante.
3. Mapeo de errores estricto: cancelación nativa → `.userCancelled` con copy amigable; resto → `.deletionFailed` con reintento.

---

## 7. Casos Límite

| Caso Límite | Comportamiento | Solución |
|---|---|---|
| Lote > 1.000 fotos | Una sola transacción atómica; spinner indeterminado (PhotoKit no da progreso) | `deletionInFlight` + `ProgressView` |
| Cancelación en diálogo nativo | Estado de sesión intacto + mensaje amigable | Criterio 4.3 (código 3072) |
| App minimizada durante el diálogo | iOS gestiona; el completion handler evalúa el resultado al volver | Flujo 4.2 |
| Assets retirados del acceso limitado | Excluidos del lote y reportados | `inaccessibleIDs` (4.2) |
| Assets solo en iCloud | Se borran de la biblioteca; tamaño estimado parcial | `assetsWithUnknownSize` |
| Tamaño 0 bytes o metadatos ausentes | Muestra "≥ 0 MB" o "Tamaño no disponible", nunca crash ni 0 engañoso | `SizeEstimate` + fallback |
| App matada a mitad de transacción | Assets no borrados reaparecen en el grid vía observer al reabrir | Declarado (4.4) |

---

## 8. Guardarraíles de Verificación en CI

1. **Unit tests con `FakePhotoKitDeletionService`:**
   - `executeBatchDeletion()` → `deletionCompleted = true` con mock exitoso.
   - Mock que lanza `.userCancelled` → mensaje exacto "Operación cancelada…" y clasificación intacta.
   - Mock con `.deletionFailed` → mensaje de reintento.
   - Formateo: `ByteCountFormatter` con 0 bytes, 450 MB, 1.45 GB y prefijo "≥" cuando hay tamaños desconocidos.
   - `deletionInFlight`: dos llamadas concurrentes solo ejecutan una transacción.
   - Cálculo < 200 ms con 500 assets sintéticos.
2. **Verificación manual (smoke test SideStore, cierre Feature 001):** borrado real de fotos de prueba en dispositivo — no automatizable con mocks.
3. **Cierre:** tests verdes en GitHub Actions + cero warnings de concurrencia.

---

## 9. Ejecución con Agentes y Skills

| Fase | Skill / Comando | Entrada | Salida |
|---|---|---|---|
| Planificación | `speckit.plan` | Este spec + specs 001–003 + `constitution.md` | `plan.md` |
| Desglose | `speckit.tasks` | `plan.md` | `tasks.md` |
| Implementación | `speckit.implement` | `tasks.md` | Código en `/Features/BatchDeletion` |
| Verificación | Checklist criterios 4.1–4.4 + lint Feature 001 | Código generado | Cierre de feature |

Regla del agente: los bloques de §4 son contratos vinculantes; ningún `PHAsset` puede aparecer en structs Sendable ni cruzar fronteras de actor.

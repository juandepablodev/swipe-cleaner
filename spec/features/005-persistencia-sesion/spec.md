# Especificación Funcional y Técnica (SDD) — Feature 005: Persistencia de Sesión (Guardado Automático)

> **ID Feature:** `005-persistencia-sesion`
> **Estado:** Especificado
> **Versión target:** iOS 17.0+ | Swift 6.0 (`SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`)
> **Ubicación del código:** `/codigo/SwipeCleaner/Features/SessionPersistence`
> **Servicio clave:** `SessionPersistenceService`
> **Dependencias:** Feature 001 (CI + lint), Feature 002 (`AssetModel`), Feature 003 (`SwipeEngineViewModel`, `ClassifiedAsset`, `SwipeDecision`)

---

## 1. Visión General y Objetivos

Esta feature añade **recuperación automática y persistencia local** de las sesiones de revisión en SwipeCleaner. Si el usuario cierra la aplicación a mitad de clasificar 200 fotos (o sufre una interrupción por llamada/segundo plano), el progreso no se pierde.

### Objetivos Clave
1. Guardar de forma atómica y ligera en `UserDefaults` (o archivo JSON privado en el sandbox) el estado de la sesión activa tras cada swipe/deshacer.
2. Detectar al abrir la app si existe una sesión guardada no finalizada.
3. Ofrecer en la Galería un botón secundario **"Continuar sesión anterior (N fotos clasificadas)"**.
4. Limpiar automáticamente la sesión persistida cuando la eliminación masiva (Feature 004) se completa con éxito.

---

## 2. Criterios de Aceptación

### Criterio 5.1: Guardado Atómico Ligero
- **Given** una sesión de swipe en curso.
- **When** el usuario realiza un swipe (`keep` o `delete`) o deshace (`undo`).
- **Then** el servicio codifica `SavedSessionState` (`Codable`) con la lista de `ClassifiedAsset` (IDs, decisiones y fechas) y los IDs de los `remainingAssets`.
- **And** la operación en disco toma < 5 ms sin bloquear el hilo principal (`MainActor`).

### Criterio 5.2: Detección y Restauración de Sesión
- **Given** una sesión guardada previa en la que el usuario clasificó N fotos.
- **When** el usuario abre `GalleryContainerView`.
- **Then** se muestra una tarjeta/banner promocional: `"Tienes una sesión en curso (N fotos revisadas)"` con el botón `"Continuar Sesión"`.
- **And** al pulsar "Continuar Sesión", `SwipeEngineViewModel` se inicializa restaurando las decisiones previas y recuperando los assets correspondientes a los `remainingAssetIDs` desde `photoService`.

### Criterio 5.3: Limpieza Automática de Sesión Persistida
- **Given** una sesión restaurada o activa.
- **When** la eliminación masiva en `SessionSummaryViewModel` finaliza con éxito.
- **Then** la sesión persistida se elimina de `UserDefaults`/disco para evitar ofrecer continuar una sesión cuyos elementos ya fueron borrados.

---

## 3. Estructura de Datos (Codable & Sendable)

```swift
public struct SavedClassifiedAsset: Codable, Sendable, Equatable {
  public let assetID: String
  public let decision: SwipeDecision
  public let timestamp: Date
}

public struct SavedSessionState: Codable, Sendable, Equatable {
  public let lastModified: Date
  public let classifiedAssets: [SavedClassifiedAsset]
  public let remainingAssetIDs: [String]
}
```

---

## 4. Guardarraíles de Verificación en CI

1. **Unit tests (`SessionPersistenceServiceTests`):**
   - Guardar y cargar `SavedSessionState` preserva el orden exacto y las decisiones.
   - `clearSavedSession()` borra la entrada en `UserDefaults`.
   - Inicializar `SwipeEngineViewModel` con un estado restaurado reconstruye `historyStack` y los recuentos de `pendingDeletionCount` y `keepCount`.
2. **Cierre:** tests verdes en GitHub Actions con cero warnings de concurrencia en Swift 6.

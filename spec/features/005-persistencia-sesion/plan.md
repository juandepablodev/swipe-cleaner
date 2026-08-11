# Plan Técnico — Feature 005: Persistencia de Sesión (Guardado Automático)

> **ID Feature:** `005-persistencia-sesion`

---

## 1. Arquitectura de Módulos

El módulo `SessionPersistence` se ubica en `/codigo/SwipeCleaner/Features/SessionPersistence` y consta de:

```text
SessionPersistence/
├── Models/
│   └── SavedSessionState.swift             ← Modelos Codable & Sendable
└── Services/
    ├── SessionPersistenceServiceProtocol.swift ← Protocolo Sendable
    ├── SessionPersistenceService.swift     ← Implementación UserDefaults (JSONEncoder)
    └── FakeSessionPersistenceService.swift ← Mock para pruebas unitarias
```

---

## 2. Puntos de Integración

1. **`SwipeEngineViewModel`**:
   - Inyección de `SessionPersistenceServiceProtocol`.
   - Llamada a `persistCurrentState()` tras `processDecision(_:)` y `undoLastDecision()`.
   - Soporte para restaurar el estado mediante `init(restoringSavedState:allAssets:photoService:persistenceService:)`.

2. **`SessionSummaryViewModel`**:
   - Inyección de `SessionPersistenceServiceProtocol`.
   - Llamada a `clearSavedSession()` al finalizar con éxito `executeBatchDeletion()`.

3. **`GalleryContainerView`**:
   - Consulta `loadSavedSession()` y presenta el botón promocional `"Continuar Sesión (N revisadas)"` si existe una sesión guardada activa.

---

## 3. Estrategia de Testing

- Suite `SessionPersistenceTests` en `SwipeCleanerTests/SessionPersistenceTests/SessionPersistenceTests.swift`.
- Mocks aislados con `FakeSessionPersistenceService`.
- Validación de codificación, decodificación, borrado y reconstrucción de estado en `SwipeEngineViewModel`.

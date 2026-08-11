# Reglas y Convenciones del Proyecto (AGENTS.md)

> Contrato operativo para cualquier agente de código que trabaje
> en este repositorio. Lee este archivo COMPLETO antes de escribir una sola
> línea. Si algo aquí contradice tu intuición, gana este archivo.

## 1. Stack Tecnológico
- Lenguaje: Swift 6.x con strict concurrency habilitado.
  Cualquier excepción temporal debe justificarse en la spec y dejar una tarea
  explícita para eliminarla.
- Interfaz: SwiftUI (UIKit solo mediante `UIViewRepresentable` si un control
  nativo no existe en SwiftUI, justificándolo en la spec).
- Frameworks nativos: PhotoKit (gestión de galería), Observation y Swift Concurrency.
- Persistencia v1: estado de sesión solo en memoria y preferencias mínimas en
  `UserDefaults`. SwiftData, bases de datos y ficheros propios están fuera de
  alcance salvo aprobación explícita en una spec.
- Target: iOS 17+ (ajustar según la spec vigente).
- IDE: VS Code / Antigravity (solo edición de código, sin build local).
- Build: GitHub Actions (macos-latest) - ÚNICO entorno de compilación.
- Testing: GitHub Actions con simulador de iOS.
- Dependencias: SOLO código nativo. SPM únicamente si la spec lo justifica.

## 2. Prohibiciones Estrictas (SEGURIDAD Y PRIVACIDAD)
- PRIVACIDAD ABSOLUTA: la aplicación es 100% local y privada.
- RED: está TERMINANTEMENTE PROHIBIDO incluir `URLSession`, frameworks de
  analítica, tracking, telemetría, llamadas de red o dependencias externas
  con acceso a internet. Ni siquiera "opcionales" o "degradadas".
- `Info.plist` NO debe declarar `NSAllowsArbitraryLoads` ni ningún
  permiso de red. Los únicos permisos permitidos son los de PhotoKit
  (`NSPhotoLibraryUsageDescription`, con el texto exacto definido en /spec).
- AISLAMIENTO: la app debe funcionar al 100% en Modo Avión y cumplir el
  Sandbox de Apple. Sin App Groups salvo que una spec lo requiera.
- DATOS: nunca escribir imágenes del usuario fuera del sandbox ni en logs.
  Prohibido loggear rutas, metadatos EXIF o identificadores de assets.

## 3. Patrones de Diseño y Convenciones
- Arquitectura: MVVM con `@Observable` (Observation framework). Vistas
  delgadas: toda la lógica va en ViewModels o servicios dedicados.
- Concurrencia: `async/await` y concurrencia estructurada (`async let`,
  `TaskGroup`). Prohibidos completion handlers anidados y `Task {}`
  sin cancelación en código de producción.
- Estado: un ViewModel por pantalla/feature. Estado mutable solo en el
  ViewModel; las vistas reciben datos y emiten acciones.
- Memoria (CRÍTICO con PhotoKit):
  - Usar `PHCachingImageManager` con `startCachingImages`/`stopCachingImages`,
    nunca cargar imágenes full-size en colecciones.
  - Miniaturas con `targetSize` explícito; full-size solo bajo demanda.
  - Toda petición de imagen debe conservar su `PHImageRequestID` y cancelarse con
  `PHImageManager.cancelImageRequest(_:)` cuando la vista o tarea deje de
  necesitarla. Usar `[weak self]` solo cuando una closure de larga vida retenga
  a `self`; no aplicarlo mecánicamente.
  - Responder a `PHPhotoLibraryChangeObserver` para mantener el fetch
    actualizado sin recargar todo.
- Estilo de código: indentación de 2 espacios, nombres en inglés, comentarios solo
  para explicar el "porqué", nunca el "qué".
- Errores: tipos `Error` propios por dominio; nunca `try!` ni force-unwrap
  fuera de tests.

## 4. Flujo de Trabajo del Agente
1. ANTES de implementar, presenta el plan y espera aprobación.
2. Implementa SOLO lo que pide la spec.
3. Commit + push a rama `dev`.
4. Push → GitHub Actions compila y ejecuta tests.
5. Si CI falla, el agente lee los logs y corrige.
6. Solo mergear a `main` cuando CI pase al 100%.

## 5. Estructura del Proyecto (SDD)
El desarrollo se rige por Spec-Driven Development (SDD):
- La carpeta `/spec` es la fuente de verdad. Cada spec define: objetivo,
  criterios de aceptación testeables, qué está fuera de scope, restricciones
  y casos límite.
- NUNCA escribas código de una feature sin spec. Si no existe, propón la
  spec primero.
- Si el código y la spec divergen, se corrige la spec o el código, pero
  ambos deben quedar alineados antes de mergear.
- Los criterios funcionales, unitarios e integración deben ser verificables en
  GitHub Actions.
- El CI puede detectar regresiones de rendimiento mediante métricas
  automatizadas, pero no certifica 60 fps, consumo de memoria real ni el
  comportamiento de PhotoKit en un dispositivo físico.
- La validación de rendimiento real, memoria y experiencia táctil queda
  bloqueada como requisito previo a una beta pública o publicación en App Store,
  cuando exista acceso a un iPhone físico y macOS.

Estructura de carpetas:
SwipeCleaner/
├── .agents/
│   └── skills/
│       ├── github-actions/
│       ├── ios-swift-development/
│       ├── mobile-ios-design/
│       ├── photokit/
│       ├── swiftui-animation/
│       └── swiftui-performance/
│
├── .github/
│   └── workflows/
│       └── build.yml                   
│
├── codigo/                              ← Raíz reservada al proyecto Xcode
│   └── .gitkeep                         
│
├── spec/                                ← Estructura base del Spec-Driven Development
│   ├── constitution/
│   │   ├── mission.md                   ← Qué construimos y para quién
│   │   ├── tech-stack.md                ← Decisiones técnicas de producto
│   │   └── roadmap.md                   ← Orden y cierre de las fases
│   │
│   └── features/
│       ├── 001-setup-y-cicd/
│       │   ├── spec.md                  ← Requisitos y aceptación
│       │   ├── plan.md                  ← Diseño técnico
│       │   └── tasks.md                 ← Tareas verificables
│       ├── 002-interfaz-galeria/
│       │   ├── spec.md
│       │   ├── plan.md
│       │   └── tasks.md
│       ├── 003-motor-swipe/
│       │   ├── spec.md
│       │   ├── plan.md
│       │   └── tasks.md
│       ├── 004-eliminacion-photokit/
│       │   ├── spec.md
│       │   ├── plan.md
│       │   └── tasks.md
│       └── 005-persistencia-sesion/
│           ├── spec.md
│           ├── plan.md
│           └── tasks.md
│
├── AGENTS.md                            ← Reglas operativas del agente
├── README.md                            ← Instalación y uso
├── .gitignore
└── skills-lock.json                     ← Registro de skills y versiones instaladas

## 6. Testing
- Framework principal: Swift Testing (`@Test`, `#expect`) para tests unitarios
  e integración. XCTest/XCUITest solo para pruebas de interfaz.
- Todo nuevo ViewModel, servicio o lógica de dominio no trivial debe incluir
  tests automatizados.
- Testear comportamiento observable y criterios de aceptación; no detalles de
  implementación interna.
- Aislar PhotoKit tras protocolos e inyectar fakes o mocks en los tests:
  los tests no deben acceder a la fototeca real del simulador.
- El entorno local es Windows: no se ejecutan builds ni tests localmente.
- GitHub Actions es la fuente de verdad de compilación y testing. Todo cambio
  debe hacer `push` a una rama y el workflow debe ejecutar los tests con
  `xcodebuild test` en un simulador iOS.
- Un PR solo puede mergearse a `main` si el job de build y tests de GitHub
  Actions termina correctamente.
- El workflow debe subir `TestResults.xcresult` como artefacto siempre
  (`if: always()`), incluso cuando fallen los tests, para facilitar el
  diagnóstico remoto.
- Para la Fase 2, usar fakes de `PHAsset`/PhotoKit para validar paginación,
  orden, estados de permisos y gestión de caché lógica; el rendimiento real
  y el uso de memoria en un iPhone físico quedan pendientes de validación
  manual antes de publicar.

## 7. Estilo de Commits y CI/CD
- Commits en formato Conventional Commits: `feat:`, `fix:`, `refactor:`,
  `test:`, `docs:`, `chore:` — mensajes en inglés, imperativo.
- Todo código que pase a `main` debe compilar Y pasar los tests.
- `.github/workflows/build.yml` debe compilar el proyecto y generar un
  `.ipa` sin firma.
- El CI debe incluir un paso de lint que falle si se detecta `URLSession`
  o imports de frameworks de red (guardarraíl de la sección 2).
- Aunque el runner sea `macos-latest`, el workflow debe seleccionar una versión
  explícita de Xcode con `xcode-select` y registrar `xcodebuild -version`.

## 8. Skills del agente
Aplicar estas skills cuando sean relevantes para la tarea:

- github-actions: workflows, secretos, artefactos, diagnóstico de CI y
  automatización en GitHub Actions.
- ios-swift-development: Swift 6, concurrencia estructurada, `@Observable`,
  MVVM y convenciones de código.
- mobile-ios-design: Human Interface Guidelines, interfaz nativa de iPhone,
  jerarquía visual, feedback y áreas táctiles.
- photokit: permisos, caché, `PHAsset`, `PHCachingImageManager`,
  observación de cambios y eliminación por lotes.
- swiftui-animation: `DragGesture`, animaciones spring, transiciones y
  feedback visual del motor de swipe.
- swiftui-performance: actualización de vistas, layout, rendering y
  prevención de regresiones de rendimiento.
# Ajustes puntuales de las pruebas de MoodMusic

Base de esta revisión: mood_music (2).zip, enviado después de restaurar el proyecto.
Esta revisión conserva la versión y las dependencias del proyecto recibido.

## Comentarios atendidos

| Comentario | Ajuste |
| --- | --- |
| Abelardo: requisitos de contraseña | Validación solo en el formulario de registro: 8–20 caracteres, letra, número y símbolo. El formulario de acceso y su validación no se cambian. |
| Abelardo: playlists | Acceso Mis playlists desde Mi música, con creación, edición, reproducción y eliminación. Almacenamiento local separado por cuenta; favoritos independientes. |
| Brandon y Jessica: ubicar Mi música en la navegación | Pestaña entre Buscar y Favoritos; se retira el acceso redundante del perfil. Se reutiliza la pantalla existente de gestión. |
| Brandon: feedback al elegir un archivo | Nombre del archivo, tamaño, icono y tarjeta de archivo listo. Indicador indeterminado durante preparación y guardado, sin porcentajes de progreso inventados. |
| Jessica: formulario adaptable | Área segura, ancho máximo, márgenes y desplazamiento con teclado. Se incorpora prueba de pantalla pequeña y texto grande. |
| Jessica: confirmar salida | Diálogo Cancelar/Salir antes de cerrar sesión o salir de la demostración. Cancelar conserva el estado. |
| Jessica: diferenciar Sistema | Icono azul para Sistema; continúa siguiendo la apariencia del teléfono. |

## Bienvenida animada y exportación añadidas

- Bienvenida: animación automática del icono, halo suave, marca y barras musicales. Dura aproximadamente 4 segundos y se desvanece hacia el login habitual. No incorpora una pantalla intermedia con botones. Si la sesión ya existe, se conserva la entrada habitual al catálogo.
- Exportación: Mi música → menú de una canción local → Exportar audio → Elegir dónde guardar. Android permite elegir Descargas u otro destino. Se copia el archivo, conservando el original y su formato. La extracción existente de videos con AAC a M4A permanece igual; no se agrega conversión universal ni descarga de redes sociales.
- Detalles visuales: fondo y halo de bienvenida, transiciones suaves, acceso a playlists destacado y hoja de exportación con el degradado de MoodMusic. Se respetan tema claro/oscuro y animaciones reducidas del sistema.
- La captura específica de responsividad mencionada por Jessica no acompaña esta revisión; debe comprobarse el caso visual original en su dispositivo.

## Archivos protegidos

La comparación con la base recibida protege los siguientes componentes, con las excepciones indicadas:

- main.dart: inicialización de servicios. mood_music_app.dart solo cambia la presentación y duración de la animación de entrada; su selección entre login, sesión y demostración se conserva.
- auth_screen.dart y firebase_auth_repository.dart: login, Google y acceso a Firebase.
- auth_layout.dart y social_button.dart: presentación original del login.
- player_screen.dart: diseño del reproductor.
- app_theme.dart: colores y estilos de la app.
- pubspec.yaml y pubspec.lock: versión y dependencias.
- Configuración Android, archivos de Firebase y reglas de Firestore. El plugin local se extiende para exportar mediante el selector de archivos de Android; su algoritmo de extracción permanece idéntico.

El controlador recibe únicamente métodos de playlists; el manejador de audio comprueba la cola completa para poder cambiar de playlist aunque empiece por la canción actual. No se modifica la pantalla del reproductor.

## Pruebas

Nuevas pruebas:

- ajustes_companeros_test.dart: registro, playlists por cuenta, confirmación de salida, editor y responsividad.
- original_flow_regression_test.dart: animación previa, desbloqueo automático del AuthScreen original, aceptación de contraseña existente y orden de pestañas.
- export_audio_sheet_test.dart: éxito, cancelación, error recuperable, prevención de doble envío y bloqueo si cambia la cuenta (canal nativo simulado).

Se actualiza register_screen_test.dart para usar una contraseña que cumpla los nuevos requisitos de registro.

Comprobaciones locales realizadas: integridad del alcance y de los archivos protegidos; sintaxis Dart y Java; casos independientes de contraseña y serialización de playlists. Las pruebas del selector de Android requieren un teléfono y no se sustituyen por el canal simulado. Flutter completo y Android deben comprobarse en el equipo del proyecto. La ejecución de Flutter en este entorno quedó bloqueada por la revisión automática y no se eludió el bloqueo.

Desde la raíz:

```powershell
flutter analyze
flutter test
flutter run
```

Detener la ejecución anterior y compilar de nuevo: el plugin Android cambió. Hot reload no incorpora Java. No desinstalar la app ni borrar datos.

Prueba manual:

1. Confirmar que el login se ve igual y que correo y Google mantienen su funcionamiento. Esta revisión no diagnostica ni cambia la configuración del fallo previo de Google.
2. Registrar una cuenta nueva con una contraseña válida y rechazar contraseñas incompletas.
3. Agregar, editar y eliminar una canción desde Mi música.
4. Elegir un audio de nombre largo, comprobar nombre/tamaño y guardar. Cancelar el selector debe conservar la selección anterior.
5. Crear y editar una playlist; reproducir y avanzar; cambiar a otra lista que empiece con la misma canción.
6. Reiniciar la app y comprobar persistencia; cambiar de cuenta y comprobar separación.
7. Eliminar una playlist y confirmar que sus canciones permanecen.
8. Cancelar y confirmar el cierre de sesión.
9. Abrir el formulario con teclado y tamaño de letra grande.
10. Revisar favoritos, historial y panel de administrador existentes.

No se creó commit, etiqueta ni Release. Registrar resultados reales antes de integrar.

11. Abrir desde cero: animación y transición automática al login original; comprobar también sesión restaurada, tema claro/oscuro y animaciones reducidas.
12. Extraer un video compatible y guardar el audio. Exportar a Descargas y reproducir la copia con otra aplicación.
13. Cancelar el selector: no mostrar éxito y permitir elegir de nuevo. Simular un destino sin espacio: mostrar error y permitir reintentar.
14. Exportar dos canciones con el mismo título y comprobar los nombres que asigna Android. Verificar que los originales siguen en Mi música.
15. Abrir y cerrar la hoja de exportación con letra grande, pantalla pequeña y orientación horizontal.

Referencia del mecanismo de exportación: https://developer.android.com/training/data-storage/shared/documents-files


## Ajustes del 28 de octubre: formularios y recuperación de audio

- Nombre de registro: hasta 40 caracteres; letras Unicode, acentos y espacios. Se rechazan números y signos al enviar.
- Contraseña nueva: entre 8 y 20 caracteres, letra, número y símbolo. Acceso a cuentas existentes sin cambios.
- Artista: hasta 100 caracteres, al menos una letra y puntuación habitual de nombres artísticos. Se permiten AC/DC, blink-182 y P!nk; se rechazan campos solo numéricos, signos sin nombre y controles/saltos de línea.
- Título: hasta 100 caracteres; debe contener letras o números. Un título numérico como 505 sigue siendo válido.
- Las reglas de título/artista se comprueban tanto al crear/editar en pantalla como al guardar en la biblioteca local. Los registros existentes no se reescriben.
- Reintentar recarga la canción actual y conserva su posición. Reproducir y cambiar de canción también permiten recuperarse de un error.
- Cargas y saltos sin respuesta tienen un límite de 25 segundos, con hasta 3 segundos adicionales para liberar recursos. Los callbacks de operaciones anteriores se invalidan al recargar. Las cancelaciones de carga no se muestran como un archivo dañado.
- Se añaden pruebas para reglas de formularios, reintento en la segunda canción, posición y recuperación tras una carga sin respuesta.

La grabación muestra un error de reproducción, pero no incluye el error nativo que lo originó. Estas correcciones mejoran la recuperación; no prueban que el problema original de red/archivo haya desaparecido. No se ejecutaron flutter analyze, flutter test ni una compilación Android en este entorno. Ejecutarlos en el equipo y probar la canción compartida y un archivo local, adelantar, reintentar y cambiar de canción.

Si reaparece, conservar la salida de `MoodMusic audio:` y `ExoPlayer` del mismo instante. La dependencia documenta errores de fuente/red e interrupciones de carga en https://pub.dev/documentation/just_audio/latest/index.html.

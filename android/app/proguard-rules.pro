# Reglas de R8 para el build de release (ver build.gradle.kts).
#
# Flutter y los plugins que usa la app (photo_manager, video_player, drift) ya
# publican sus propias reglas de conservación; aquí solo va lo que haga falta
# añadir al descubrir un fallo propio del release. Cada regla debe llevar un
# comentario con el motivo.

# photo_manager llama a Glide por reflexión para generar miniaturas; se
# conservan sus clases para que el recorte no las elimine.
-keep class com.fluttercandies.photo_manager.** { *; }

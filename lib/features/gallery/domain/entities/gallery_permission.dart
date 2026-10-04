/// Estado del permiso de acceso a la galería, independiente de la plataforma.
enum GalleryPermission {
  /// Aún no se le preguntó al usuario.
  notDetermined,

  /// Acceso completo a fotos y videos.
  granted,

  /// Acceso parcial: el usuario eligió solo algunos elementos (iOS 14+,
  /// Android 14+). La app funciona, pero con una galería incompleta.
  limited,

  /// El usuario lo rechazó. Solo se puede revertir desde los ajustes.
  denied,

  /// Bloqueado por control parental o políticas del dispositivo.
  restricted;

  /// Si se puede leer la galería (aunque sea parcialmente).
  bool get canRead => this == granted || this == limited;

  /// Si volver a pedir el permiso muestra el diálogo del sistema. Cuando es
  /// `false` hay que llevar al usuario a los ajustes del dispositivo.
  bool get canRequest => this == notDetermined;
}

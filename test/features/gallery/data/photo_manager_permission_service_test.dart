import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/data/photo_manager_permission_service.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  test('cada estado de photo_manager tiene su equivalente de dominio', () {
    expect(
      galleryPermissionFrom(PermissionState.notDetermined),
      GalleryPermission.notDetermined,
    );
    expect(
      galleryPermissionFrom(PermissionState.authorized),
      GalleryPermission.granted,
    );
    expect(
      galleryPermissionFrom(PermissionState.limited),
      GalleryPermission.limited,
    );
    expect(
      galleryPermissionFrom(PermissionState.denied),
      GalleryPermission.denied,
    );
    expect(
      galleryPermissionFrom(PermissionState.restricted),
      GalleryPermission.restricted,
    );
  });

  test('solo concedido y limitado permiten leer; solo "sin decidir" pide', () {
    expect(GalleryPermission.values.where((p) => p.canRead), [
      GalleryPermission.granted,
      GalleryPermission.limited,
    ]);
    expect(GalleryPermission.values.where((p) => p.canRequest), [
      GalleryPermission.notDetermined,
    ]);
  });
}

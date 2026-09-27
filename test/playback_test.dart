import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/playback.dart';

void main() {
  const id = '1AbCdEfGhIjKlMnOpQrStUvWxYz_-012';

  test('reconnaît les formats de liens Google Drive', () {
    expect(idFichierDrive('https://drive.google.com/file/d/$id/view?usp=sharing'), id);
    expect(idFichierDrive('https://drive.google.com/file/d/$id/view?usp=drive_link'), id);
    expect(idFichierDrive('https://drive.google.com/open?id=$id'), id);
    expect(idFichierDrive('https://drive.google.com/uc?id=$id&export=download'), id);
    expect(idFichierDrive('  https://drive.google.com/file/d/$id  '), id);
  });

  test('refuse ce qui n\'est pas un lien Drive', () {
    expect(idFichierDrive(''), isNull);
    expect(idFichierDrive('https://www.youtube.com/watch?v=abc'), isNull);
    expect(idFichierDrive('https://drive.google.com/drive/my-drive'), isNull);
  });

  test('lien via l’API Google Drive (clé obligatoire)', () {
    expect(
      lienApiDrive('https://drive.google.com/file/d/$id/view', 'CLE'),
      'https://www.googleapis.com/drive/v3/files/$id?alt=media&key=CLE',
    );
    expect(lienApiDrive('https://drive.google.com/file/d/$id/view', ''), isNull);
  });

  test('lien direct de téléchargement', () {
    expect(
      lienDirectDrive('https://drive.google.com/file/d/$id/view'),
      'https://drive.google.com/uc?export=download&id=$id',
    );
  });
}

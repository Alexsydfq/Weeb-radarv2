/// Gdzie trzymamy własne tło: na Androidzie i Windowsie plik w folderze
/// aplikacji, w przeglądarce (iPad) pamięć podręczna strony.
library;

export 'bg_store_io.dart' if (dart.library.js_interop) 'bg_store_web.dart';

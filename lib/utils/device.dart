import 'package:flutter/foundation.dart';

/// Where the data lives, in words. The browser build keeps everything in the
/// one browser it runs in, which is a narrower place than "this phone" and the
/// warnings about backing up should say so.
const thisDevice = kIsWeb ? 'this browser' : 'this phone';

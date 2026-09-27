// Generates launcher icons for Android, iOS and web from a single source
// image (defaults to icon.png at the project root).
//
// Usage:
//   dart run tool/generate_icons.dart [source.png]
//
// Uses package:image (already a project dependency) so no extra tools needed.
import 'dart:io';
import 'package:image/image.dart' as img;

/// Standard Flutter web/manifest icons plus favicon.
const webIcons = <String, int>{
  'web/icons/Icon-192.png': 192,
  'web/icons/Icon-512.png': 512,
  'web/favicon.png': 32,
};

/// Android launcher mipmap densities.
const androidMipmaps = <String, int>{
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// iOS AppIcon.appiconset — filename → pixel size (matches Contents.json).
const iosAppIcons = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

const androidResDir = 'android/app/src/main/res';
const iosIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main(List<String> args) {
  final sourcePath = args.isNotEmpty ? args.first : 'icon.png';
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source icon not found: $sourcePath');
    exit(1);
  }

  final source = img.decodeImage(sourceFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode source icon: $sourcePath');
    exit(1);
  }
  stdout.writeln('Source: $sourcePath (${source.width}x${source.height})');

  // Android
  androidMipmaps.forEach((folder, size) {
    final out = File('$androidResDir/$folder/ic_launcher.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(img.encodePng(img.copyResize(source, width: size, height: size)));
    stdout.writeln('  ✓ ${out.path} (${size}x$size)');
  });

  // iOS
  iosAppIcons.forEach((name, size) {
    final out = File('$iosIconDir/$name');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(img.encodePng(img.copyResize(source, width: size, height: size)));
    stdout.writeln('  ✓ ${out.path} (${size}x$size)');
  });

  // Web regular
  webIcons.forEach((path, size) {
    final out = File(path);
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(img.encodePng(img.copyResize(source, width: size, height: size)));
    stdout.writeln('  ✓ ${out.path} (${size}x$size)');
  });

  // NOTE: web maskable icons are intentionally NOT generated here —
  // tool/generate_icon_art.py writes them with the green-gradient artwork at
  // the 72% safe zone (a white-background version would clash with the art).
  // Use generate_icon_art.py as the canonical icon generator.

  stdout.writeln('Done.');
}

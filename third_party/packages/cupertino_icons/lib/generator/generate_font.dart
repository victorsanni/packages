import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:icon_font_generator/icon_font_generator.dart'; // Replace with Weiyu's package
import 'package:path/path.dart' as path;

import 'existing_map.dart';

final String SCRIPT_PATH = path.dirname(Platform.script.toFilePath());
final String INPUT_SVG_DIR = path.join(SCRIPT_PATH, '..', '..', 'assets', 'src');
final String OUTPUT_FONT_DIR = path.join(SCRIPT_PATH, '..', 'assets');

Map<String, String> unusable_names = <String, String>{
  // Keywords in Dart we can't use as names.
  'return': 'return_icon',
};

// Start at this codepoint since it's the last manually used codepoint from
// cupertino_icons 0.1.3.
int nextCodepoint = 0xf4d3;
final Map<String, List<int>> iconMap = <String, List<int>>{};

int compare(FileSystemEntity a, FileSystemEntity b) {
  // Extract filenames and compare them
  final String filenameA = path.basename(a.path);
  final String filenameB = path.basename(b.path);
  return filenameA.compareTo(filenameB);
}

void main() {
  final String fontFileName = '$OUTPUT_FONT_DIR/CupertinoIconsNew.ttf';
  final Map<String, String> svgMap = <String, String>{};

  final Directory inputSvgDir = Directory(INPUT_SVG_DIR);
  final List<FileSystemEntity> directories = inputSvgDir.listSync();

  for (final FileSystemEntity directory in directories) {
    if (directory is Directory) {
      for (final FileSystemEntity entity in directory.listSync()..sort(compare)) {
        if (entity is File) {
          final String filename = path.basename(entity.path);
          String name = path.basenameWithoutExtension(filename);
          final String ext = path.extension(filename);

          if (ext == '.svg' || ext == '.eps') {
            // Handle the <switch> tag removal.
            final String svgText = entity.readAsStringSync();
            final String modifiedSvgText =
                svgText.replaceAll('<switch>', '').replaceAll('</switch>', '');
            final File tempFile =
                File('${Directory.systemTemp.path}/temp_$filename');
            tempFile.writeAsStringSync(modifiedSvgText);

            if (unusable_names.containsKey(name)) {
              name = unusable_names[name]!;
            }

            // Extract SVG content.
            final Document document = parser.parse(modifiedSvgText);
            final Element? svgElement = document.querySelector('svg');
            if (svgElement != null && !iconMap.containsKey(name)) {
              svgMap[filename] = svgElement.outerHtml;

              final List<int> codepoints;
              if (mapped_codepoints.containsKey(name)) {
                codepoints = mapped_codepoints[name]!;
                mapped_codepoints.remove(name);
              } else {
                nextCodepoint += 1;
                codepoints = <int>[nextCodepoint];
              }
              iconMap[name] = codepoints;
              if (aliases.containsKey(name)) {
                for (final String alias in aliases[name]!) {
                  iconMap[alias] = codepoints;
                }
              }
            }
          }
        }
      }
    }
  }
  final SvgToOtfResult svgToOtfResult = svgToOtf(
    svgMap: svgMap,
    fontName: 'CupertinoIconsNew',
  );
  writeToFile(fontFileName, svgToOtfResult.font);
  print(svgMap.length);

  // Write the JSON output to a file.
  final File jsonFile = File('$OUTPUT_FONT_DIR/CupertinoIcons.json');
  final JsonEncoder encoder = JsonEncoder.withIndent(
      '  ', (value) => value); // 2 spaces indent, ',' and ': ' separators
  // Sort by name alphabetically.
  final List<String> sortedKeys = iconMap.keys.toList()..sort();
  final Map<dynamic, List<int>?> sortedMap = <String, List<int>?>{ for (final String k in sortedKeys) k : iconMap[k] };
  final Map<String, Object> jsonOutput = <String, Object>{'name': 'CupertinoIcons', 'icons': sortedMap};
  jsonFile.writeAsStringSync(encoder.convert(jsonOutput));
}

import 'dart:convert';
import 'dart:io';

import 'config.dart';

final PALETTE_ALPHA = 'PaletteAlpha';

final fileSh = File("temp.sh");
final List<File> pngFiles = [];

int compressedPngNum = 0;

main() async {
  Config config = await _readConfig();
  // print('config : ${json.encode(config)}');

  Directory dir = Directory(config.rootPath);

  await _listPic(dir, config);
  print('total png: ${pngFiles.length}');

  compressedPngNum = 0;
  for (final file in pngFiles) {
    bool isPaletteAlpha = await _isPaletteAlphaType(file.path);
    if (!isPaletteAlpha) {
      await _compressPng(file.path);
    }
  }
  print('total png: ${pngFiles.length}, compressed png: $compressedPngNum');
  if (fileSh.existsSync()) {
    fileSh.delete();
  }
}

Future<void> _listPic(Directory dirRoot, Config config) async {
  List<String> includePath = config.includePath;
  List<WhiteListItem> whiteList = config.whiteList;

  for (final file in dirRoot.listSync(recursive: true)) {
    String path = file.path;
    bool containPath = false;
    for (final p in includePath) {
      if (path.contains(p)) {
        containPath = true;
      }
    }
    if (!containPath) {
      continue;
    }

    bool inWhite = false;
    for (final white in whiteList) {
      String wPath = white.path;
      String wName = white.fileName;
      if (wPath.isEmpty) {
        //path为'', 只匹配fileName
        if (wName.isNotEmpty && path.endsWith(wName)) {
          inWhite = true;
        }
      } else {
        //包含path
        if (path.contains(wPath)) {
          //fileName为'',包含path的都忽略
          if (wName.isEmpty) {
            inWhite = true;
          } else {
            //path和fileName都匹配
            if (path.endsWith(wName)) {
              inWhite = true;
            }
          }
        }
      }
    }
    if (inWhite) {
      print('int whitelist continue : $path');
      continue;
    }
    if (path.endsWith(".png") && !path.endsWith(".9.png")) {
      pngFiles.add(file as File);
      // print(path);
    }
  }
}

///压缩图片逻辑
Future<void> _compressPng(String srcName) async {
  List<String> args = [
    '--skip-if-larger',
    '--speed 1',
    '--nofs',
    '--strip',
    '--force',
    '--output "$srcName"',
    '-- "$srcName"',
  ];
  final shell = "./pngquant ${args.join(' ')}";
  print(shell);

  fileSh.writeAsStringSync(shell);
  final result = await Process.start('bash', [fileSh.path]);
  int exitCode = await result.exitCode;
  if (exitCode != 0) {
    //.Er 99 .
    // .It Fl Fl skip-if-larger
    // If conversion results in a file larger than the original,
    // the image won't be saved and pngquant will exit with status code
    // .Er 98 .
    // Additionally, file size gain must be greater than the amount of quality lost.
    // If quality drops by 50%, it will expect 50% file size reduction to consider it worthwhile.
    if (exitCode == 99) {
      print(
          'exitCode: $exitCode, result is larger than original, ignore result');
    } else if (exitCode == 98) {
      print(
          'exitCode: $exitCode, file size gain must be greater than the amount of quality lost, ignore result');
    } else {
      final ssOut = await utf8.decodeStream(result.stdout);
      final ssErr = await utf8.decodeStream(result.stderr);
      print('exitCode: $exitCode, stdout: $ssOut, stderr: $ssErr');
    }
  } else {
    compressedPngNum++;
    print('success');
  }
}

///是否PaletteAlpha类型
Future<bool> _isPaletteAlphaType(String srcName) async {
  bool isPaletteAlpha = false;
  final shell = 'identify -verbose $srcName | grep "Type"';
  fileSh.writeAsStringSync(shell);
  final result = await Process.start('bash', [fileSh.path]);
  //exitCode一直是0
  final ssOut = await utf8.decodeStream(result.stdout);
  List<String> outL = ssOut.trim().split(':');
  if (outL.length > 0) {
    var type = outL[outL.length - 1].trim();
    print(type);
    if (type.toUpperCase().contains(PALETTE_ALPHA.toUpperCase())) {
      isPaletteAlpha = true;
    }
  }

  final ssErr = await utf8.decodeStream(result.stderr);
  List<String> errL = ssErr.trim().split(':');
  if (errL.length > 0) {
    print(errL[errL.length - 1].trim());
  }

  return isPaletteAlpha;
}

Future<Config> _readConfig() async {
  File file = new File('config.json');
  String content = await file.readAsString();
  Config config = Config([], []);
  try {
    config = Config.fromJson(json.decode(content));
  } catch (e) {
    print(e);
  }
  return config;
}

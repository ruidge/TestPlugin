import 'dart:convert';
import 'dart:io';

import 'config.dart';

final fileSh = File("temp.sh");
final List<File> pngFiles = [];

int compressedPngNum = 0;

main() async {
  Config config = await _readConfig();
  print('config : ${json.encode(config)}');

  Directory dir = Directory(config.rootPath);

  await _listPic(dir, config);
  print('total png: ${pngFiles.length}');

  // var configFileLastModified = await _getConfigFile().lastModified();
  // int tsConfigFile = configFileLastModified.millisecondsSinceEpoch;
  int tsConfig = config.timestamp;

  compressedPngNum = 0;
  for (final file in pngFiles) {
    var lastModified = await file.lastModified();
    int oldTs = lastModified.millisecondsSinceEpoch;
    if (oldTs > tsConfig) {
      print('${file.path}, 修改时间晚于上次压缩执行时间, 进行压缩...');
      //不await 会同时触发
      await _compressPng(file.path);
    } else {
      print('${file.path}, 修改时间早于上次压缩执行时间,认为已经压过了,不压缩');
    }
  }
  print('total png: ${pngFiles.length}, compressed png: $compressedPngNum');

  config.timestamp = DateTime.now().millisecondsSinceEpoch;
  _writeConfig(config);

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
      log(path);
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
      log('exitCode: $exitCode, result is larger than original, ignore result');
    } else if (exitCode == 98) {
      log('exitCode: $exitCode, file size gain must be greater than the amount of quality lost, ignore result');
    } else {
      final ssOut = await utf8.decodeStream(result.stdout);
      final ssErr = await utf8.decodeStream(result.stderr);
      log('exitCode: $exitCode, stdout: $ssOut, stderr: $ssErr');
    }
  } else {
    compressedPngNum++;
    log('success');
  }
}

Future<Config> _readConfig() async {
  File file = _getConfigFile();
  String content = await file.readAsString();
  Config config = Config([], []);
  try {
    config = Config.fromJson(json.decode(content));
  } catch (e) {
    print(e);
  }
  return config;
}

File _getConfigFile() {
  return new File('config.json');
}

Future<void> _writeConfig(Config config) async {
  File file = new File('config.json');
  await file.writeAsString(json.encode(config));
}

bool showLog = false;

log(String log) {
  if (showLog) {
    print(log);
  }
}

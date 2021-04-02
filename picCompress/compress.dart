import 'dart:convert';
import 'dart:io';

import 'config.dart';

//512b
final SIZE_THRESHOLD = 512;

//临时sh文件
final fileTempSh = File("temp.sh");
//临时png文件
final fileTempPng = File("temp.png");
final List<File> pngFiles = [];

int compressedSuccessNum = 0;
int compressedFailNum = 0;
int ignoreSizeNum = 0;

main() async {
  Config config = await _readConfig();
  // print('config : ${json.encode(config)}');

  Directory dir = Directory(config.rootPath);

  await _listPic(dir, config);
  print('total png: ${pngFiles.length}');

  compressedSuccessNum = 0;
  compressedFailNum = 0;
  ignoreSizeNum = 0;
  for (final file in pngFiles) {
    await _compressPng(file.path);
  }
  print('png总数: ${pngFiles.length}, 压缩失败数: $compressedFailNum, ' +
      '压缩成功数: $compressedSuccessNum,其中压缩差值小于$SIZE_THRESHOLD,忽略数: $ignoreSizeNum ');
  if (await fileTempSh.exists()) {
    fileTempSh.delete();
  }
  if (await fileTempPng.exists()) {
    fileTempPng.delete();
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
  //exitCode: 4, stderr: --ext and --output options can't be used at the same time
  List<String> args = [
    '--quality 70-100',
    '--skip-if-larger',
    '--speed 1',
    '--nofs',
    '--strip',
    '--force',
    // '--ext _new.png',
    '--output "${fileTempPng.path}"',
    '-- "$srcName"',
  ];
  final shell = "./pngquant ${args.join(' ')}";
  print(shell);

  fileTempSh.writeAsStringSync(shell);
  final result = await Process.start('bash', [fileTempSh.path]);
  int exitCode = await result.exitCode;
  if (exitCode != 0) {
    compressedFailNum++;
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
    compressedSuccessNum++;
    print('compress success');
    await _writeOriginPngIfNeed(srcName);
  }
}

///生成图片写回原文件
Future<void> _writeOriginPngIfNeed(String srcName) async {
  File fileSrc = File(srcName);
  if (await fileSrc.exists() && await fileTempPng.exists()) {
    //源文件比压缩文件大才替换
    if (await _compareSize(fileTempPng, fileSrc)) {
      print('copy ${fileTempPng.path} -> $srcName');
      await fileTempPng.copy(srcName);
    } else {
      ignoreSizeNum++;
    }
  }
}

///比较文件超出阈值
Future<bool> _compareSize(File compressed, File origin) async {
  return (await origin.length() - await compressed.length()) > SIZE_THRESHOLD;
}

///读取配置文件
Future<Config> _readConfig() async {
  File file = File('config.json');
  String content = await file.readAsString();
  Config config = Config([], []);
  try {
    config = Config.fromJson(json.decode(content));
  } catch (e) {
    print(e);
  }
  return config;
}

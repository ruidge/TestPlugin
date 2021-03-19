import 'dart:convert';
import 'dart:io';

final SRC_MAIN_RES = 'src/main/res';
final SRC_MAIN_ASSETS = 'src/main/assets';

final fileSh = File("temp.sh");
final List<File> pngFiles = [];
final List<File> jpgFiles = [];
final List<File> webpFiles = [];

int compressedPngNum = 0;

main() async {
  Directory dir = Directory('../');
  await listPic(dir);
  print('total png: ${pngFiles.length}');
  print('total jpg: ${jpgFiles.length}');
  print('total webp: ${webpFiles.length}');

  compressedPngNum = 0;
  for (final file in pngFiles) {
    //不await 会同时触发
    await compressPng(file.path);
  }
  print('total png: ${pngFiles.length}, compressed png: $compressedPngNum');

  if (fileSh.existsSync()) {
    fileSh.delete();
  }
}

Future<void> listPic(Directory dirRoot) async {
  for (final file in dirRoot.listSync(recursive: true)) {
    String path = file.path;
    if (path.contains(SRC_MAIN_RES) || path.contains(SRC_MAIN_ASSETS)) {
      if (path.endsWith(".png") && !path.endsWith(".9.png")) {
        pngFiles.add(file as File);
        log(path);
      } else if (path.endsWith(".jpg")) {
        jpgFiles.add(file as File);
        log(path);
      } else if (path.endsWith(".webp")) {
        webpFiles.add(file as File);
        log(path);
      }
    }
  }
}

///压缩图片逻辑
Future<void> compressPng(String srcName) async {
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
  log(shell);

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

bool showLog = false;

log(String log) {
  if (showLog) {
    print(log);
  }
}

class Config {
  String rootPath = '';
  List<String> includePath = [];
  List<WhiteListItem> whiteList = [];

  Config(this.includePath, this.whiteList);

  Config.fromJson(Map<String, dynamic> json) {
    rootPath = json['rootPath'] ?? "";
    includePath = json['includePath'].cast<String>();
    if (json['whiteList'] != null) {
      json['whiteList'].forEach((v) {
        whiteList.add(new WhiteListItem.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['rootPath'] = this.rootPath;
    data['includePath'] = this.includePath;
    data['whiteList'] = this.whiteList.map((v) => v.toJson()).toList();
    return data;
  }
}

class WhiteListItem {
  String path = '';
  String fileName = '';

  WhiteListItem(this.path, this.fileName);

  WhiteListItem.fromJson(Map<String, dynamic> json) {
    path = json['path'] ?? "";
    fileName = json['fileName'] ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['path'] = this.path;
    data['fileName'] = this.fileName;
    return data;
  }
}

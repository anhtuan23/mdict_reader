import 'package:path/path.dart' as p;

abstract class MdictHelpers {
  static String getDictNameFromPath(String mdxPath) =>
      p.basenameWithoutExtension(mdxPath).toLowerCase();
}

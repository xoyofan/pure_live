// One-shot: point lib/core/sites.dart constants at lib/core/common/site_ids.dart.
import { readFileSync, writeFileSync } from 'node:fs';

const p = 'lib/core/sites.dart';
let src = readFileSync(p, 'utf8');

src = src.replace(
  /  static const String (\w+Site) = ['"][^'"]+['"];/g,
  (_m, name) => `  static const String ${name} = SiteIds.${name};`,
);

src = src.replace(
  /  static const Set<String> supportedSiteIds = \{[\s\S]*?\};/,
  '  static const Set<String> supportedSiteIds = SiteIds.supportedSiteIds;',
);

if (!src.includes("import 'common/site_ids.dart';")) {
  src = src.replace("import 'site/yy/yy_site.dart';", "import 'site/yy/yy_site.dart';\nimport 'common/site_ids.dart';");
}

writeFileSync(p, src);
console.log('constants now:', (src.match(/SiteIds\.\w+Site/g) ?? []).length, '| set replaced:', src.includes('SiteIds.supportedSiteIds'));

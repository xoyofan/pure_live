// 迭代18:i18n() zh.json 回落单测。
//
// zishu UI 不包 EasyLocalization,tr() 恒返回 key;pure_live 适配器里
// 111 处 i18n() 字段(分类名/画质名/公告)由此漏原始 key。启动时载入打包
// zh.json 回落,文案真源仍是 pure_live 自己的翻译文件。
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/utils/i18n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureZhTextFallback();
  });

  test('未初始化 EasyLocalization 时按 zh.json 直出中文', () {
    // niconico 分类名(用户报告漏 key 的场景)。
    expect(i18n('niconico_category_common'), '综合');
    expect(i18n('niconico_category_try'), '创作与挑战');
    // 17live 画质名/公告。
    expect(i18n('seventeen_quality_enhanced'), '增强高清');
    expect(i18n('seventeen_age_notice'), '17LIVE 要求观看者年满 18 周岁。');
  });

  test('带命名参数的文案做 {name} 替换', () {
    expect(
      i18n('http_error_default', args: {'statusCode': '400'}),
      '连接服务器失败，请稍后再试(400)',
    );
  });

  test('zh.json 也缺失的 key 保持原样返回', () {
    expect(i18n('definitely_not_a_real_key'), 'definitely_not_a_real_key');
  });
}

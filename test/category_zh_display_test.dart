// 迭代16:分类显示层中文映射(补充表 + web 真源 remap 表)单测。
//
// 覆盖:twitch 一级分组标签 / twitch 二级经 remapCategoryName /
// twitcasting cid 反查 + 标签兜底 / picarto·showroom 标签表 /
// 中文平台(douyu/douyin)不被补充表劫持。
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/src/shared/domain/category_display.dart';

void main() {
  group('displayCategoryName fork 补充表', () {
    test('twitch 一级分组标签中文化', () {
      expect(displayCategoryName('twitch', 'Adventure Game'), '冒险游戏');
      expect(displayCategoryName('twitch', 'Driving/Racing Game'), '竞速游戏');
      expect(displayCategoryName('twitch', "Shoot 'Em Up"), '弹幕射击');
      // 大小写/空白不敏感。
      expect(displayCategoryName('twitch', '  visual novel '), '视觉小说');
    });

    test('twitch 二级分类经 web 真源 remap 表', () {
      expect(displayCategoryName('twitch', 'Just Chatting', 'just-chatting'), '聊天');
      expect(displayCategoryName('twitch', 'IRL', 'irl'), '户外');
      // remap 未命中的长尾保持原名(与 web 真源回退口径一致)。
      expect(displayCategoryName('twitch', 'Some Obscure Game', 'some-obscure-game'), 'Some Obscure Game');
    });

    test('twitcasting 按稳定 cid 反查,标签兜底', () {
      expect(displayCategoryName('twitcasting', 'Popular', '_system_channel_popular'), '热门');
      expect(displayCategoryName('twitcasting', 'With live captions', '_system_transcription'), '字幕直播');
      // 上游改版换 key 时按小写标签兜底。
      expect(displayCategoryName('twitcasting', 'Girls', '_unknown_key'), '女生');
      // 双未命中保持原名。
      expect(displayCategoryName('twitcasting', 'Whatever', '_whatever'), 'Whatever');
    });

    test('picarto/showroom 标签表中文化', () {
      expect(displayCategoryName('picarto', 'Character Design', '2'), '角色设计');
      expect(displayCategoryName('picarto', 'Nature & Landscape', '53'), '自然风景');
      expect(displayCategoryName('picarto', 'Not A Category', '999'), 'Not A Category');
      expect(displayCategoryName('showroom', 'Voice Actor', '101'), '声优');
      expect(displayCategoryName('showroom', "MEN'S", '113'), '男生');
      expect(displayCategoryName('showroom', 'New7day', '118'), '新开7天');
    });

    test('soop:补充表 + remap 覆盖英文名,韩文原名回落', () {
      // remap 表(web 真源)覆盖。
      expect(displayCategoryName('soop', 'Talk/Cam', '00130000'), '聊天/秀场');
      expect(displayCategoryName('soop', 'PUBG: Battlegrounds', '00040066'), '绝地求生');
      // fork 补充表覆盖(remap 未收录)。
      expect(displayCategoryName('soop', 'Virtual', '00810000'), '虚拟主播');
      expect(displayCategoryName('soop', 'Lost Ark', '00040067'), '命运方舟');
      // 韩文原名(推荐流直出)经韩文键映射;未收录韩文名回落原名。
      expect(displayCategoryName('soop', '토크/캠방', '00130000'), '聊天/秀场');
      expect(displayCategoryName('soop', '안 어카테고리', ''), '안 어카테고리');
    });

    test('chzzk:slug/韩文名双键映射', () {
      // 分类树:cid=slug。
      expect(displayCategoryName('chzzk', '리그 오브 레전드', 'League_of_Legends'), '英雄联盟');
      // 房间徽标只带韩文名,无 cid。
      expect(displayCategoryName('chzzk', '로스트아크', ''), '命运方舟');
      // 双未命中保持原名(长尾韩文回落)。
      expect(displayCategoryName('chzzk', '어떤 게임', 'Some_Game'), '어떤 게임');
    });

    test('中文平台不被补充表劫持', () {
      // douyu/douyin/huya/bilibili 原生中文名恒等返回(既有口径)。
      expect(displayCategoryName('douyu', 'Party', ''), 'Party');
      expect(displayCategoryName('douyin', '聊天', ''), '聊天');
      expect(displayCategoryName('huya', '户外', ''), '户外');
    });

    test('跨平台 cid 映射仍然生效(twitch slug → canonical 中文名)', () {
      expect(displayCategoryName('twitch', 'World of Warcraft', 'world-of-warcraft'), '魔兽世界');
    });

    test('分组名展示:twitch 分组走补充表,四家保持原名', () {
      expect(displayCategoryGroupName('twitch', 'Stealth'), '潜行');
      expect(displayCategoryGroupName('douyu', '网游竞技'), '网游竞技');
    });
  });
}

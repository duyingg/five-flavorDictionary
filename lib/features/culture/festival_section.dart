import 'package:flutter/material.dart';
import 'ethnic_festivals.dart';
import 'festival_entry.dart';

/// Editorial summaries written for this app. References are named for context.
const festivalEntries = <FestivalEntry>[
  FestivalEntry(
    name: '春节',
    introduction: '农历新年的开端，也是从年前准备延续到正月的一段年节生活。',
    history: '古称岁首、元日等；近代公历元旦与农历新年分称后，“春节”成为通用名称。',
    customs: '除夕团年、守岁，正月拜年贺岁；各地还有贴春联、年画、逛庙会等活动。',
    meaning: '辞旧迎新、家人团聚，并向亲友表达祝福。',
    note: '年食和庆祝方式因地区而异，例如北方饺子与南方年糕，不能视为每户必备。',
    sourceTitle: '中国非物质文化遗产网：春节的传统与新变',
  ),
  FestivalEntry(
    name: '破五',
    introduction: '正月初五的年节节点，也称“破五”。',
    history: '旧俗认为过年初几的部分禁忌到初五可以解除，商铺也逐渐恢复营业。',
    customs: '有些地方送穷、迎财神、开市，或以打扫庭院表达除旧迎新。',
    meaning: '从年初的休息与拜贺逐步回到日常生活。',
    note: '迎财神、送穷的具体日期和方式存在地区差异。',
    sourceTitle: '中国非物质文化遗产网：春节礼俗之正月初五赶五穷',
  ),
  FestivalEntry(
    name: '人日',
    introduction: '正月初七的传统节俗，又称人胜节。',
    history: '古代岁首占候把正月初七称作“人日”；女娲造人的说法属于民间传说。',
    customs: '旧俗有戴人胜、占晴雨；部分地区吃七样羹或七色菜。',
    meaning: '借“人的生日”表达对生命与平安的祝愿。',
    note: '食俗和庆祝程度有明显地域差别。',
    sourceTitle: '中国非物质文化遗产网：正月初七是“人日”',
  ),
  FestivalEntry(
    name: '元宵节',
    introduction: '正月十五的新年第一个月圆夜，也称上元节、灯节。',
    history: '观灯活动在唐宋城市节庆中渐趋兴盛，后来成为年节的代表景象。',
    customs: '赏花灯、猜灯谜、吃元宵或汤圆；一些地方有舞龙、舞狮和社火。',
    meaning: '以灯火和团圆食物寄托新春团聚、欢乐的愿望。',
    note: '元宵和汤圆的做法、名称及节庆活动依地域而异。',
    sourceTitle: '北京市人民政府：春节古时称“元旦”',
  ),
  FestivalEntry(
    name: '填仓节',
    introduction: '正月廿五前后的祈丰收节俗，也写作“添仓节”。',
    history: '旧时农户借“填满粮仓”的意象，盼望新年粮食充足。',
    customs: '部分地区用灰画仓、置粮祭仓，或添置米面并制作仓形面食。',
    meaning: '表达重视粮食、期盼丰年的心愿。',
    note: '节期和做法有地方差异；此处日期采用常见的正月廿五。',
    sourceTitle: '北京市怀柔区人民政府：满族传统节日综述',
  ),
  FestivalEntry(
    name: '中和节',
    introduction: '农历二月初一、由唐代朝廷创设的春季节日。',
    history: '唐德宗在贞元年间设立中和节，以仲春万物萌发为背景，安排官员宴集和劝农活动。',
    customs: '历史上有献农书、酿宜春酒、祭春神等活动。',
    meaning: '强调顺应农时与天地和畅。',
    note: '这是历史节日，今天并非各地普遍延续的民俗。',
    sourceTitle: '中央纪委国家监委网站：中和节，一个鲜为人知的节日',
  ),
  FestivalEntry(
    name: '龙抬头',
    introduction: '农历二月初二的春季节俗，常称“二月二”。',
    history: '“龙抬头”联系东方苍龙星宿的季节性升起，也与春耕、祈雨观念结合。',
    customs: '民间有理发、吃带“龙”名的食物、踏青或祈求丰收等做法。',
    meaning: '象征春回大地、农事将兴。',
    note: '星象解释与龙王降雨传说应区分；各地习俗并不相同。',
    sourceTitle: '北京市人民政府：春节古时称“元旦”',
  ),
  FestivalEntry(
    name: '花朝节',
    introduction: '春季纪念百花、花神的节俗，又称百花生日。',
    history: '历代与各地节期并不一致，常见二月初二、十二、十五或廿五。',
    customs: '赏花、踏青、祭花神；有些地方为花木系彩笺。',
    meaning: '以花开迎春，表达对自然与生长的欣赏。',
    note: '没有全国统一的“花朝节当天”，列表只展示常见日期。',
    sourceTitle: '苏州市姑苏区人民政府：虎丘山下再现“赏红”习俗',
  ),
  FestivalEntry(
    name: '春社日',
    introduction: '春季祭祀土地神的社日，日期依干支纪日推定。',
    history: '传统算法取立春后的第五个戊日，约在春分前后，与秋社相对。',
    customs: '旧时乡里祭社、聚饮；部分地区制作社饭。',
    meaning: '向土地祈求农事顺利、五谷丰登。',
    note: '它不是固定的农历月日，也不是每年都与春分同日。',
    sourceTitle: '中国气象局：社日节与春祈秋报',
  ),
  FestivalEntry(
    name: '上巳节',
    introduction: '三月初三的春日节俗，古称“上巳”。',
    history: '早期以三月上旬的巳日为期，魏晋以后逐渐固定在三月初三。',
    customs: '古人临水祓禊、踏青游春；文人雅集还发展出曲水流觞。',
    meaning: '寄托祛除不祥、迎接春日的愿望，也留下文学艺术传统。',
    note: '古礼与今天的“三月三”地区庆典并非完全相同。',
    sourceTitle: '福州档案信息网：史话福州暮春上巳',
  ),
  FestivalEntry(
    name: '寒食节',
    introduction: '清明前后的旧节，以禁火、冷食得名。',
    history: '古代寒食与清明原有区别，后因日期相近，扫墓、踏青等节俗逐渐交融。',
    customs: '历史上有禁火吃冷食、祭扫、踏青等活动。',
    meaning: '关联慎终追远与春日生活。',
    note: '纪念介子推是流传广泛的传说，不能作为寒食起源的唯一结论；具体日期逐年变化。',
    sourceTitle: '承德市双桥区人民政府：清明节的来历',
  ),
  FestivalEntry(
    name: '清明节',
    introduction: '二十四节气之一，也逐渐成为重要的祭祖节日。',
    history: '清明的节气含义与寒食、春季祭扫习俗长期融合，形成今天的节日面貌。',
    customs: '祭扫先人、踏青郊游；各地还有插柳、放风筝等习俗。',
    meaning: '兼具追思亲人与感受春生的内涵。',
    note: '日期由节气时刻确定，不能固定写成每年公历4月5日。',
    sourceTitle: '承德市双桥区人民政府：清明节的来历',
  ),
  FestivalEntry(
    name: '佛诞节',
    introduction: '汉传佛教纪念释迦牟尼诞生的节日，又称浴佛节。',
    history: '佛教传入中国后，农历四月初八成为汉传佛教常见的纪念日期。',
    customs: '寺院举行浴佛、诵经等法会；部分地方节会也吸收戏曲和市集活动。',
    meaning: '体现佛教信众对佛陀的纪念与祈愿。',
    note: '这是宗教节日；不同佛教传统及地区的纪念日期、仪式未必一致。',
    sourceTitle: '苏州市民族宗教事务局：佛教有哪些主要节日',
  ),
  FestivalEntry(
    name: '端午节',
    introduction: '农历五月初五的传统节日，又称端五、重午。',
    history: '避疫禳灾、水上竞渡与纪念屈原等说法在不同地区、时期相互交织。',
    customs: '包粽子、赛龙舟；一些地区悬艾草、菖蒲或制作香囊。',
    meaning: '包含祈求安康、缅怀历史人物和社区协作等多重内涵。',
    note: '“端午只为纪念屈原”不足以概括各地的历史来源。',
    sourceTitle: '中国非物质文化遗产网：端午节（五常龙舟胜会）',
  ),
  FestivalEntry(
    name: '六月六',
    introduction: '农历六月初六前后的夏日节俗，常被称为晒书节、晒衣节。',
    history: '夏季翻晒书籍、衣物、谱牒有防潮防蛀的生活背景，各地也有不同传说。',
    customs: '部分地区晒书、晒衣、晒谱，也有尝新谷或地方祭祀活动。',
    meaning: '反映夏季物候与保存物品的生活经验。',
    note: '“六月六”并非单一全国性节日，各地名称、故事和节俗差异很大。',
    sourceTitle: '湖南省人民政府：六月六',
  ),
  FestivalEntry(
    name: '七夕节',
    introduction: '农历七月初七的节日，也称乞巧节、女儿节。',
    history: '牛郎织女传说与古代妇女乞巧习俗长期结合；爱情主题后来更加突出。',
    customs: '旧俗有拜织女、穿针乞巧、制作巧果等；不同地区保留形式各异。',
    meaning: '既寄托对巧艺的期望，也表达对美好情感的追求。',
    note: '把七夕仅称作“中国情人节”会遗漏乞巧传统。',
    sourceTitle: '中国非物质文化遗产网：七夕节',
  ),
  FestivalEntry(
    name: '中元节',
    introduction: '农历七月十五前后的祭祖节俗，民间也称“七月半”。',
    history: '秋季祭祖习惯与道教中元、佛教盂兰盆等传统相互影响。',
    customs: '一些地区祭祖、施食或放河灯，方式依地方与信仰而变。',
    meaning: '表达对先人的追思与对亲人的关怀。',
    note: '部分地区以七月十四为主要祭日，不能把十五视为全国唯一日期。',
    sourceTitle: '天门市人民政府：中元节习俗',
  ),
  FestivalEntry(
    name: '中秋节',
    introduction: '农历八月十五的秋季节日，以月圆为重要意象。',
    history: '赏月、祭月与秋收时令逐渐结合，宋代以八月十五为中秋的节俗日益明确。',
    customs: '家人团聚、赏月、分享月饼；闽南等地另有博饼。',
    meaning: '借圆月表达团圆、思念和丰收的愿望。',
    note: '博饼等活动具有鲜明地域性。',
    sourceTitle: '中国非物质文化遗产网：中秋节（中秋博饼）',
  ),
  FestivalEntry(
    name: '秋社日',
    introduction: '秋季祭祀土地神的社日，与春社相对。',
    history: '传统算法取立秋后的第五个戊日，约在秋分前后。',
    customs: '旧俗有祭社、设宴、分享社糕或社酒。',
    meaning: '在收获后酬谢土地、庆贺丰年，所谓“春祈秋报”。',
    note: '日期逐年变化；具体庆祝形式依时代和地区而不同。',
    sourceTitle: '中国气象局：社日节与春祈秋报',
  ),
  FestivalEntry(
    name: '重阳节',
    introduction: '农历九月初九的秋日节日，又称重九。',
    history: '“九”数重叠形成节名，登高、赏菊等做法见于历代节俗与诗文。',
    customs: '登高、赏菊、食重阳糕；现代也有敬老活动。',
    meaning: '兼有秋游、祈福和尊老的文化内涵。',
    note: '登高和菊花食俗并非各地都相同。',
    sourceTitle: '中国非物质文化遗产网：重阳节习俗知多少',
  ),
  FestivalEntry(
    name: '寒衣节',
    introduction: '农历十月初一的祭祖节俗，也称十月朔。',
    history: '入冬添衣的生活经验，与向逝者“送寒衣”的祭奠观念相结合。',
    customs: '部分地区祭扫先人，以纸制衣物寄托冬日关怀。',
    meaning: '在寒意初起时表达对故人的怀念。',
    note: '孟姜女送寒衣等故事属于民间传说；祭祀形式有地域差异。',
    sourceTitle: '黄石市住房和城市更新局：中国传统节日·寒衣节',
  ),
  FestivalEntry(
    name: '下元节',
    introduction: '农历十月十五的旧节，属于道教“三元”节期之一。',
    history: '与道教水官信仰相关，地方节俗也吸收祭祖、酬谢等活动。',
    customs: '旧俗有祭祖、祈福、供灯等；今天传承程度因地而异。',
    meaning: '体现秋冬之交的感恩与祈愿。',
    note: '下元节与十月初一寒衣节日期不同，历史上部分地方习俗会混合。',
    sourceTitle: '广东省政协文史广东：渐行渐远的“下元节”',
  ),
  FestivalEntry(
    name: '冬至节',
    introduction: '冬至既是二十四节气之一，也是传统岁时节日。',
    history: '冬至标志太阳周年运行的重要节点，历代又有祭祖、贺冬等礼俗。',
    customs: '家人相聚祭祖，饮食有北方饺子、南方汤圆或馄饨等不同做法。',
    meaning: '在人们迎接寒冬时寄托团聚与新一轮时序的希望。',
    note: '冬至以节气交接为准，公历日期和习俗都不能简单固定。',
    sourceTitle: '浙江省社会科学界联合会：寻味二十四节气·冬至',
  ),
  FestivalEntry(
    name: '腊八节',
    introduction: '农历十二月初八的节日，是年节准备的一环。',
    history: '古代岁末腊祭与佛教纪念释迦牟尼成道的日期相互影响，形成后来的腊八节。',
    customs: '熬腊八粥；一些地区还泡腊八蒜、吃腊八面。',
    meaning: '寄托感恩收成、迎接新年的心意。',
    note: '腊祭原本并非固定腊月初八，不能把两者完全等同。',
    sourceTitle: '湖北省非物质文化遗产网：腊八，年味渐浓',
  ),
  FestivalEntry(
    name: '小年',
    introduction: '春节前的忙年节点，常与祭灶相联系。',
    history: '送灶神的旧俗逐渐成为扫尘、置办年货等春节准备的开端。',
    customs: '祭灶、扫尘、备年货；一些地区制作灶糖。',
    meaning: '提醒人们整理家居、准备迎新。',
    note: '北方常在腊月廿三，南方一些地方在廿四；也有其他日期。',
    sourceTitle: '北京市人民政府：春节古时称“元旦”',
  ),
  FestivalEntry(
    name: '除夕',
    introduction: '农历一年的最后一夜，与新年正月初一相接。',
    history: '岁末辞旧与新年迎新相连，形成守岁、团年等一系列年俗。',
    customs: '年夜饭、家人团聚、守岁；部分地区祭祖、贴春联。',
    meaning: '回望旧岁，与亲友共同迎接新年。',
    note: '农历十二月可能是廿九日或三十日结束，除夕并非总是“年三十”。',
    sourceTitle: '中央纪委国家监委网站：欢欢喜喜过春节·年历',
  ),
];

class FestivalSection extends StatelessWidget {
  const FestivalSection({required this.content, super.key});

  final String content;

  @override
  Widget build(BuildContext context) {
    final details = {for (final item in festivalEntries) item.name: item};
    final rows = content
        .split('\n')
        .where((line) => line.contains('|'))
        .map((line) => line.split('|'))
        .toList();
    const seasonStarts = {
      '春节': '岁首与春日',
      '佛诞节': '暮春与夏日',
      '七夕节': '秋日与团圆',
      '寒衣节': '入冬与岁末',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('传统节日 · 共 ${rows.length + ethnicFestivalEntries.length} 项',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('岁时节日按大致年内时序排列；民族节庆标明对应历法与社区。',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 18),
        Text('岁时节日 · ${rows.length} 项',
            style: Theme.of(context).textTheme.titleLarge),
        for (final row in rows) ...[
          if (seasonStarts[row.first] case final heading?) ...[
            const SizedBox(height: 20),
            Text(heading, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
          ],
          _FestivalCard(
            title: row.first,
            date: row.last,
            entry: details[row.first],
          ),
        ],
        const Divider(height: 48),
        Text('少数民族与跨民族节庆 · ${ethnicFestivalEntries.length} 项',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('以下是代表性节庆；同一民族内部也可能有不同日期与做法。宗教节日按信仰群体标示。',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        for (final entry in ethnicFestivalEntries)
          _FestivalCard(
            title: entry.name,
            date: entry.date,
            community: entry.community,
            entry: entry,
          ),
      ],
    );
  }
}

class _FestivalCard extends StatelessWidget {
  const _FestivalCard({
    required this.title,
    required this.date,
    required this.entry,
    this.community,
  });

  final String title;
  final String date;
  final String? community;
  final FestivalEntry? entry;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          key: ValueKey('festival-$title'),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date),
              if (community case final value?) Text(value),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry case final value?) ...[
              Text(value.introduction),
              const SizedBox(height: 12),
              _FestivalField(label: '历史脉络', text: value.history),
              _FestivalField(label: '常见习俗', text: value.customs),
              _FestivalField(label: '文化含义', text: value.meaning),
              _FestivalField(label: '地区与日期', text: value.note),
              Text('资料参考：${value.sourceTitle}',
                  style: Theme.of(context).textTheme.bodySmall),
            ] else
              const Text('详细资料暂缺'),
          ],
        ),
      );
}

class _FestivalField extends StatelessWidget {
  const _FestivalField({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(TextSpan(children: [
          TextSpan(
            text: '$label：',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: text),
        ])),
      );
}

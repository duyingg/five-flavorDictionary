/// Imported books associated with each school. All appear in the classics
/// collection; these IDs also create links from the school detail pages.
const schoolBookIds = <String, List<String>>{
  'school-ru': [
    'classic-lunyu',
    'classic-mengzi',
    'classic-xunzi',
    'classic-daxue',
    'classic-zhongyong',
    'classic-liji',
    'classic-yizhuan',
    'classic-zhouli',
    'classic-shangshu',
  ],
  'school-dao': [
    'classic-laozi',
    'classic-zhuangzi',
    'classic-liezi',
    'classic-baopuzi',
  ],
  'school-mo': ['classic-mozi'],
  'school-fa': ['classic-hanfeizi'],
  'school-zongheng': ['classic-guiguzi'],
  'school-bing': ['classic-sunzi-bingfa', 'classic-sunbin-bingfa'],
};

final schoolBookIdSet = schoolBookIds.values.expand((ids) => ids).toSet();

/// Primer texts stay with other introductory culture resources.
const primerBookIds = <String>{
  'classic-sanzijing',
  'classic-qianziwen',
  'classic-dizigui',
};

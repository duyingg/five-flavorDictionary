/// Imported books associated with each school. All appear in the classics
/// collection; these IDs also create links from the school detail pages.
const schoolBookIds = <String, List<String>>{
  'school-ru': [
    'classic-lunyu',
    'classic-daxue',
    'classic-zhongyong',
    'classic-yizhuan',
  ],
  'school-dao': ['classic-laozi'],
  'school-zongheng': ['classic-guiguzi'],
  'school-bing': ['classic-sunzi-bingfa'],
};

final schoolBookIdSet = schoolBookIds.values.expand((ids) => ids).toSet();

/// Primer texts stay with other introductory culture resources.
const primerBookIds = <String>{
  'classic-sanzijing',
  'classic-qianziwen',
  'classic-dizigui',
};

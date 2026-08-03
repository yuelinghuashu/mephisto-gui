/// 本地模拟叙事回复
///
/// 当 LLM 不可用（网络失败/未配置 API Key）时的兜底回复。
/// 根据用户输入关键词生成对应的叙事文本，保证应用始终可用。
library;

/// 本地模拟叙事（LLM 不可用时的兜底）。
///
/// 参数：
///   - userInput: 用户输入（命运的指引）
///   - roleName: 当前角色名（用于占位符替换）
///
/// 返回值：浮士德主题的叙事回复文本。
String localReply(String userInput, {String roleName = '浮士德'}) {
  if (userInput.contains('为什么') || userInput.contains('为何')) {
    return '烛火在$roleName眼中跳动。他凝视着跳动的焰光，喃喃自语：'
        '"知识就像这火焰——越靠近，越能感受它的灼热，却永远无法触及它的本质。'
        '我们追问\'为什么\'，得到的只是更多的\'为什么\'。"';
  } else if (userInput.contains('够了') || userInput.contains('停下')) {
    return '$roleName沉默片刻，将目光投向窗外的夜色。月光爬上他苍白的脸颊，'
        '他低声道："你说得对，我该停下了。但这月光，这寂静——它们不也在追问着什么吗？"';
  } else if (userInput.contains('契约') || userInput.contains('灵魂')) {
    return '书斋的阴影中传来一个低沉的声音："契约已经签下，$roleName。你的灵魂——它正在燃烧。"'
        '$roleName猛地转身，烛火剧烈摇晃，书斋中却空无一人。';
  } else if (userInput.contains('求索') || userInput.contains('真理')) {
    return '$roleName猛地站起身，眼中燃起与烛火同色的光：'
        '"求索！这就是我存在的全部意义！'
        '哪怕在绝望中，哪怕在黑暗中——我依然要追问，要探索，要抵达那不可抵达的彼岸！"';
  }
  return '$roleName抬起眼，指尖无意识地划过桌角的契约书，陷入了沉思。'
      '片刻后他缓缓开口："$userInput……有趣。这世上的一切，都值得被追问。"';
}
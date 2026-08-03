import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/domain/narrative_state.dart';

/// NarrativeState 纯逻辑测试
///
/// 覆盖 branchName 提取、copyWith、便捷访问器等不依赖外部状态的部分。
/// 运行时动态数据（内存/历史映射）与 provider 组装由 integration 侧覆盖。
void main() {
  group('NarrativeState.branchName', () {
    NarrativeState state(String sourceFileName, {String roleName = '浮士德'}) {
      return NarrativeState(
        contract: Contract(
          roleName: roleName,
        ),
        sourceFileName: sourceFileName,
      );
    }

    test('母版文件返回空字符串', () {
      expect(state('faust.meph').branchName, '');
      expect(state('dantes.meph').branchName, '');
    });

    test('默认子版返回「存档」', () {
      expect(state('faust.child.meph').branchName, '存档');
      expect(state('dantes.child.meph').branchName, '存档');
    });

    test('自定义分支返回分支名', () {
      expect(state('faust.dark.meph').branchName, 'dark');
      expect(state('faust.审判线.meph').branchName, '审判线');
    });

    test('无扩展名/非 .meph 后缀的回退', () {
      // 无点（视为母版）
      expect(state('faust').branchName, '');
      // 只有母版名 + 结尾有点（无分支名）
      expect(state('faust..meph').branchName, '');
    });
  });

  group('NarrativeState.copyWith', () {
    test('全部字段可独立更新', () {
      const contract = Contract(roleName: '浮士德');
      const original = NarrativeState(contract: contract);
      final updated = original.copyWith(
        sourceFileName: 'faust.child.meph',
        isGenerating: true,
        streamingContent: '想',
      );
      expect(updated.sourceFileName, 'faust.child.meph');
      expect(updated.isGenerating, isTrue);
      expect(updated.streamingContent, '想');
      // 未更新的字段保持原值
      expect(updated.contract, same(contract));
      expect(updated.messages, isEmpty);
      expect(updated.memories, isEmpty);
    });

    test('null 参数不覆盖原值', () {
      const contract = Contract(roleName: '浮士德');
      const original = NarrativeState(
        contract: contract,
        sourceFileName: 'faust.child.meph',
      );
      final updated = original.copyWith();
      expect(updated.sourceFileName, 'faust.child.meph');
    });
  });

  group('NarrativeState 便捷访问器', () {
    test('roleName 来自契约', () {
      const contract = Contract(roleName: '埃德蒙·唐泰斯');
      const state = NarrativeState(contract: contract);
      expect(state.roleName, '埃德蒙·唐泰斯');
    });

    test('roleName 缺省时默认浮士德', () {
      const state = NarrativeState(contract: Contract(roleName: '浮士德'));
      expect(state.roleName, '浮士德');
    });

    test('count 访问器', () {
      const contract = Contract(
        roleName: '浮士德',
        rules: [
          Rule(name: 'r1', condition: '包含 "x"', action: 'y', line: 1),
        ],
      );
      const state = NarrativeState(contract: contract);
      expect(state.ruleCount, 1);
      expect(state.memoryCount, 0);
      expect(state.historyCount, 0);
      expect(state.messageCount, 0);
    });
  });
}
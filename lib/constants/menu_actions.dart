/// 菜单操作键 - 统一常量
///
/// 首页契约卡 / 舞台卡 ⋮ 菜单与叙事页存档菜单使用字符串回调传递操作名。
/// 此前散落在各文件中以裸字符串形式出现（'enter'、'delete' 等），
/// 统一收敛至此常量文件，消除拼写错误与维护成本。
library;

/// 进入（单角色契约 / 舞台 / 角色行）
const String menuActionEnter = 'enter';

/// 预览契约内容
const String menuActionPreview = 'preview';

/// 编辑契约源文本
const String menuActionEdit = 'edit';

/// 重命名
const String menuActionRename = 'rename';

/// 删除
const String menuActionDelete = 'delete';

/// 另存为分支（叙事页存档菜单）
const String menuActionSaveBranch = 'save_branch';

/// 重新开始（舞台卡菜单）
const String menuActionRestart = 'restart';

/// 导出（契约树 / 舞台）
const String menuActionExport = 'export';

/// 删除舞台内单个角色卡（母版 .meph）
const String menuActionDeleteRole = 'delete_role';

/// 删除舞台内单个角色的 .child.meph 存档
const String menuActionDeleteChild = 'delete_child';
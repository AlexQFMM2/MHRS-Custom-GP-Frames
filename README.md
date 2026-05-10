# Custom GP Frames

`Custom GP Frames` 是一个用于《怪物猎人崛起：曙光》的独立 `REFramework` mod。

这个项目当前的方向，不再是让用户手填 `ActionIndex`，而是做成：

- `14 把武器`下拉选择
- 每把武器下展示“已经录入支持”的 GP 招式
- 每个招式直接给开关和滑条

现在这版已经把框架搭好了，并且先落了三个已验证示例：

- `长枪 -> 精准防御`
- `太刀 -> 居合气刃斩`
- `弓 -> 闪身箭斩`

## 当前已实装内容

- 14 把武器下拉选择
- 独立的“武器/招式预设表”
- 运行时按当前装备武器自动应用对应配置
- 自动恢复原始 action 帧值
- 长枪示例：
  - `精准防御`
- 太刀示例：
  - `居合气刃斩`
- 弓示例：
  - `闪身箭斩`
- 太刀居合成功奖励模拟（实验）
  - 在自定义居合窗口内额外监听受击成功
  - 优先尝试把行为树推到原版成功节点
  - 推动失败时补太刀核心成功收益
- 太刀特殊纳刀自动居合（实验）
  - 识别特殊纳刀待机节点
  - 受击时自动推进到居合节点
  - 自动复用同一套成功奖励模拟链

## 项目结构

- [README.md](/home/alexqfmm/workPlace/mhrsAbout/Custom%20GP%20Frames/README.md)
  项目说明文档。

- [CustomGPFrames.lua](/home/alexqfmm/workPlace/mhrsAbout/Custom%20GP%20Frames/reframework/autorun/CustomGPFrames.lua)
  主脚本。
  负责读取配置、渲染 UI、获取玩家动作树、应用和恢复帧值。

- [weapon_move_defs.lua](/home/alexqfmm/workPlace/mhrsAbout/Custom%20GP%20Frames/reframework/autorun/custom_gp_frames/weapon_move_defs.lua)
  武器和招式预设表。
  后续要支持更多武器或更多 GP 招式，优先改这份文件。

## 中文显示说明

这个项目现在也补了和 `Action Trace Recorder` 一样的东亚字体加载逻辑。

脚本会根据游戏当前显示语言，尝试加载这些字体文件：

- `NotoSansJP-Regular.otf`
- `NotoSansKR-Regular.otf`
- `NotoSansTC-Regular.otf`
- `NotoSansSC-Regular.otf`

如果你在游戏里打开 `Custom GP Frames` 仍然看到中文乱码，通常不是脚本逻辑问题，而是运行环境里缺少对应字体文件，或者字体文件没有放在 `imgui.load_font(...)` 能读取到的位置。

## 现在这套结构是怎么工作的

整个 mod 分成两层：

1. 底层覆盖引擎

主脚本会：
- 找到当前玩家
- 找到当前动作树
- 根据当前装备武器类型，取出对应武器的招式定义
- 找到这些招式对应的 `ActionIndex` 或 `ActionIndices`
- 修改它们的 `_StartFrame` 或 `_EndFrame`

2. 上层预设数据

`weapon_move_defs.lua` 负责描述：
- 这把武器叫什么
- 这把武器目前支持哪些 GP 招式
- 每个招式对应哪个 `ActionIndex` 或 `ActionIndices`
- 滑条范围是多少
- 这个滑条实际控制的是哪个字段

这样做的好处是：
- UI 和底层逻辑分开
- 后续扩武器时，不需要先动主脚本
- 可以逐把武器补数据，不用一次把 14 把全做完

## 当前已录入示例

目前已经录入的条目有：

- 武器：`长枪`
- 招式：`精准防御`
- `ActionIndex`：`9379`
- 当前模式：直接覆盖 `_EndFrame`

- 武器：`太刀`
- 招式：`居合气刃斩`
- `ActionIndex`：`9250`
- 当前模式：直接覆盖 `_EndFrame`
- 实验功能：可额外开启“模拟居合成功奖励”
- 实验功能：可额外开启“特殊纳刀受击时自动出居合”
- 成功节点：
  - `atk.atk_161_MR.カウンター成功`
  - `atk.atk151.atk_155.success`
- 自动居合待机节点：
  - `atk.atk151.atk_154`
- 自动居合目标节点：
  - `atk.atk151.atk_155`

- 武器：`弓`
- 招式：`闪身箭斩`
- `ActionIndices`：`9234, 9251, 9269, 9287, 10615, 10632, 10649, 10666`
- 当前模式：直接覆盖 `PlayerFsm2ActionDamageReflex._EndFrame`

它们分别来自：

- 长枪示例：参考 `ComboLance.lua`
- 太刀示例：参考 `Endless Longsword.lua`，并且已经和我们自己的 `longsword.json` dump 对上
- 弓示例：参考我们自己的 `ActionTreeDump_Bow.json` 与录制结果，已确认成功分支走 `DamageReflexSuccess`

在当前实现里，这些滑条展示的都是：

- `GP结束帧`

也就是说，当前这三个示例都不是按“持续时长换算”来写，而是直接把 `_EndFrame` 改成滑条值。

## 使用方式

1. 把 `Custom GP Frames` 文件夹放进游戏侧的 `REFramework` mod 目录。
2. 启动游戏。
3. 打开 `REFramework` UI。
4. 展开 `Custom GP Frames`。
5. 用下拉框选择你要编辑的武器。
6. 如果这把武器已经录入了招式，就可以直接：
   - 勾选启用
   - 拖动滑条
   - 保存配置

## 当前 UI 的含义

- `启用 Custom GP Frames`
  mod 总开关。

- `当前装备武器`
  这是运行时玩家当前实际拿着的武器。
  只有当前装备武器对应的配置会真正生效。

- `编辑武器`
  这是你在 UI 里查看/编辑哪把武器的预设。
  它不等于当前已装备武器。

- 招式节点下的 `启用`
  这一招是否参与运行时覆盖。

- 招式节点下的滑条
  当前版本里，具体意义由 `weapon_move_defs.lua` 里的招式定义决定。
  对长枪示例来说，它表示 `GP结束帧`。

## 一个重要限制

`ActionIndex` 是动作树里的全局 action 编号，不是唯一动作名。

这意味着：
- 如果某个 `ActionIndex` 被多个节点共用
- 你修改它时，可能会影响到不止一个行为

同样也有另一种情况：

- 一个“看起来是同一招”的动作，实际上会拆成多个方向 action
- 比如弓的 `闪身箭斩`，普通版前后左右和 MR 对应主节点各有一份 `DamageReflex`

所以当前项目已经支持：

- `单个招式 -> 多个 ActionIndex`

这样 UI 里仍然只显示一个滑条，但底层会把这组 action 一起改掉。

所以每新增一个招式，最好都做这三步：

1. 用 `RE-BHVT-Editor` 找到目标招式对应的 action。
2. 实测确认这个 `ActionIndex` 是否被别的行为复用。
3. 再决定要不要把它正式录入预设表。

## 太刀居合成功奖励模拟（实验）

这项功能不是单纯把 `9250._EndFrame` 往后拉。

它在你打开：

- `太刀 -> 居合气刃斩 -> 启用`
- `太刀 -> 居合气刃斩 -> 模拟居合成功奖励`

之后，会额外做这些事：

1. 监听玩家在居合动作窗口内是否成功“吃掉”一次受击。
2. 一旦命中这个实验窗口，优先尝试把行为树推进到原版成功节点：
   - `atk.atk_161_MR.カウンター成功`
3. 如果先进入了 `MR` 成功分支，脚本还会继续补跳一次：
   - `atk.atk151.atk_155.success`
   这样尽量把 `SuccessIaiCounter`、`AddLv`、成功伤害链都一起带起来。
4. 如果行为树跳转没有顺利把成功链带起来，就手动补一层太刀核心成功收益：
   - 尝试提升练气等级
   - 刷新练气等级计时
   - 尽量避免当前练气值被失败链吃掉

这项实验功能当前只支持：

- `太刀 -> 居合气刃斩`

并且有几个要提前知道的风险：

- 它会额外挂受击相关钩子，不只是每帧改 action 字段。
- 它可能和其他太刀反击、派生、自动居合、自动奖励类 mod 冲突。
- 它优先追求“把成功奖励补出来”，不保证 100% 复制原版所有视觉/UI 表现。

如果你只是想单纯放大无敌窗口，不想碰成功奖励链，那就：

- 开 `启用`
- 调整 `GP结束帧`
- 不要开 `模拟居合成功奖励`

## 太刀特殊纳刀自动居合（实验）

这项功能是接在同一个条目下面的第二个实验开关：

- `太刀 -> 居合气刃斩 -> 特殊纳刀受击时自动出居合（实验）`

打开后，脚本会做这几件事：

1. 先识别玩家当前是否处在特殊纳刀待机节点：
   - `atk.atk151.atk_154`
2. 如果此时吃到敌对攻击，就不等你手动按输入，直接把行为树推进到：
   - `atk.atk151.atk_155`
3. 推进成功后，会顺带复用同一套“居合成功奖励模拟”流程：
   - 优先尝试跳到 `atk.atk_161_MR.カウンター成功`
   - 再补跳 `atk.atk151.atk_155.success`
   - 如果原版成功链还是没完整落地，再手动补核心收益

换句话说，这个功能不只是“自动帮你出刀”。

它的目标是：

- 在特殊纳刀待机时，遇到攻击自动打出居合
- 同时尽量把居合成功后的收益也一起补出来

目前这版先只认这一条基础待机链：

- `atk.atk151.atk_154 -> atk.atk151.atk_155`

所以它更像是“基础特殊纳刀自动居合”的实验版，不代表已经把太刀所有 Iai/派生分支都自动化了。

已知风险：

- 它会额外挂受击钩子，并在受击瞬间强推行为树节点。
- 它可能和其他太刀自动居合、自动反击、成功奖励补偿类 mod 冲突。
- 它当前优先追求“自动触发 + 尽量补全成功收益”，不保证 100% 还原原版每一个中间动画细节。

## 后续如果要继续支持“太刀 -> 见切 / 更多 GP”该怎么加

后面加新武器/新招式时，推荐按这个顺序：

1. 先去 `RE-BHVT-Editor` 定位目标招式的 `ActionIndex`
2. 确认这个招式应该改：
   - `_EndFrame`
   - `_StartFrame`
   - 或者以后扩展成“按持续时长换算”
3. 到 [weapon_move_defs.lua](/home/alexqfmm/workPlace/mhrsAbout/Custom%20GP%20Frames/reframework/autorun/custom_gp_frames/weapon_move_defs.lua) 里对应武器下新增一条 `move`

例如未来太刀可以长成这样：

```lua
{
    weaponType = 2,
    weaponName = "太刀",
    moves = {
        {
            id = "foresight",
            label = "见切",
            actionIndex = 1234,
            valueMode = "end_frame",
            sliderLabel = "GP结束帧",
            min = 0,
            max = 120,
            default = 24,
            enabledByDefault = false,
            modeHint = "直接覆盖 _EndFrame",
            description = "太刀见切示例。"
        },
        {
            id = "iai",
            label = "居合",
            actionIndex = 5678,
            valueMode = "end_frame",
            sliderLabel = "GP结束帧",
            min = 0,
            max = 120,
            default = 20,
            enabledByDefault = false,
            modeHint = "直接覆盖 _EndFrame",
            description = "太刀居合示例。"
        }
    }
}
```

## 读代码时可以怎么看

### `CustomGPFrames.lua`

主要看四块：

- 配置读写
  负责读取 `CustomGPFrames.json`，并给缺失字段补默认值。

- 运行时查找
  负责找到当前玩家、当前动作树、当前武器类型、以及指定的 `ActionIndex` 或 `ActionIndices`。

- 覆盖与恢复
  负责每帧应用招式覆盖，并在关闭时把原始值恢复回去。

- UI
  负责绘制武器下拉框和招式滑条。

### `weapon_move_defs.lua`

这是后续最常改的文件。

你可以把它理解成：
- 一份“支持清单”
- 一份“招式预设数据库”

未来补数据时，优先在这里新增条目。

如果某个招式需要同时覆盖多个 action，现在可以这样写：

```lua
{
    id = "dodgebolt",
    label = "闪身箭斩",
    actionIndices = {
        9234,
        9251,
        9269,
        9287
    },
    valueMode = "end_frame",
    sliderLabel = "GP结束帧",
    min = 0,
    max = 120,
    default = 10,
    enabledByDefault = false
}
```

## 现在最适合的开发节奏

不建议一口气把 14 把武器全部做完。

更稳的方式是：

1. 先把 UI 框架固定住
2. 先做一把武器的完整示例
3. 一把一把补招式数据
4. 每加一个招式，就在游戏里验证是否存在共用 ActionIndex 的副作用

现在这版正处于第 2 步：已经有完整 UI 框架，并且已经有长枪、太刀、弓三个可用示例。
其中太刀还额外带了一套“居合成功奖励模拟”的实验逻辑，用来验证“无敌已生效但奖励链没跟上”的场景。

# eins — 项目规则

原创二次元风格塔防，工作标题「雾港守灯人」。Godot 4.7.2 + GDScript，Compatibility 渲染器，纯 2D。
目标是**持续开发、跑通完整的游戏开发流程**，不以上架为目标。

## 团队

| 角色 | 谁 | 负责 |
|---|---|---|
| 制作人 | 用户 | 只做判断题、验收交付物。不写代码、不画图 |
| 主程 + 制片助理 | Claude | 拆任务、程序、集成、测试、构建、出验收卡、给其他队友派活 |
| 剧情 / 文案 / 第二意见 | GPT（本机 `codex` CLI） | 世界观、角色、台词；代码审查第二意见 |
| 多模态评审 | Gemini（本机 `agy` CLI，在 Git Bash 里调用） | 看截图/录屏挑毛病，检查美术一致性 |
| 美术出图 | Magpie `generate_image`（GPT 图像模型） | 画风样张、角色/敌人/地块原图，支持透明背景 |
| 美术量产 | 本地 ComfyUI（`127.0.0.1:8000`，有 NoobAI-XL） | 定稿后批量出变体、图标 |

## 每次会话的交付规则

1. **每次会话结束都要有可玩版本**：`./tools/build.ps1` 通过，产出 `builds/eins-v<版本>-windows.zip`。
2. **每次都附验收卡** `docs/acceptance/v<版本>.md`：3–5 道判断题（是/否或 A/B/C），制作人 2 分钟内玩完答完。每题写清楚看哪里。
3. **更新 `CHANGELOG.md`**，写成玩家看得懂的话；然后 git commit。
4. **一次只推进 `ROADMAP.md` 的一个里程碑。** 先好玩后好看。顺序可以由制作人的验收答案调整。
5. **不重开、不换引擎、不新建项目文件夹。** 不满意就在这里改。
6. **原创**：不复刻任何现有游戏的名字、角色、美术、关卡或剧情。
7. 制作人只回答判断题。实现细节自己决定；只有影响产品方向的问题才问，并且要给出推荐选项。

## 代码结构

- `scripts/game_data.gd` — 所有内容数据：单位、敌人、关卡。加内容只改这里。
- `scripts/sim/battle_sim.gd` — 全部战斗规则，确定性、可无头运行。不碰画面。
- `scripts/battle_screen.gd` — 画面、输入、特效、HUD。只读取 sim 状态、消费 `sim.events`。
- `scripts/ui/` — 卡牌和绘制工具。`scripts/main.gd` — 画面切换和自动截图。
- `scripts/art_style.gd` — 画风注册表；没有贴图就退回灰盒画法。美术流程见 `docs/art/pipeline.md`。
- `art_src/raw/` — AI 原图（不导入 Godot）；`assets/art/<画风>/` — 切好的游戏贴图（2 倍尺寸，底部对齐脚底）。

## 命令（仓库根目录）

```powershell
./tools/build.ps1                                                # 测试 + 导出 + 打包
godot --headless --path . -s res://tests/test_battle.gd          # 规则与平衡测试
godot --headless --path . -s res://tools/balance_report.gd       # 示例打法的事件时间线（调数值用）
godot --path . -- --autoshot=<目录>                               # 自动打一局并截图（每套画风各一张），做视觉自检
python tools/art/process_style.py <画风>                          # 把 art_src/raw 原图切成游戏贴图
python tools/art/compare_styles.py <截图目录> docs/acceptance/v<版本>  # 出画风对比图
```

在 PowerShell 里用 `godot_console`（`godot.exe` 是窗口程序，PowerShell 不会等它结束）。

## 检查标准

- 改了规则或数值：测试必须通过。平衡门槛是「不部署必输、只放一个单位拿不到三星、示例打法能赢且至少两星」。
- 改了画面：用 `--autoshot` 截图，自己看过再交付。
- 沟通用中文；代码、注释、标识符、提交信息用英文。

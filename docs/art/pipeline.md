# 美术管线

## 流程

1. **出图**：在 Claude 会话里调用 Magpie 的 `generate_image`（默认模型 `codex/gpt-image-2`）。原图存到 `art_src/raw/<画风>/`。
   - `units.png`：5 名角色一排，透明背景，1536×1024，顺序是 剑士、盾卫、弓手、术士、医师。
   - `enemies.png`：一排 5 个，透明背景，1536×1024，顺序是 雾团、雾犬、雾甲、雾门、灯塔。
   - `tiles.png`：2×2 四宫格，1024×1024，顺序是 地面（左上）、高台（右上）、海面（左下）、墙面（右下）。
2. **切图**：`python tools/art/process_style.py <画风>`。脚本做这几件事：
   - 按列切开每个物件，去掉旁边物件漏进来的碎片和边缘杂色。
   - 角色统一缩放到 88 像素高，按 2 倍尺寸存进 `assets/art/<画风>/`。
   - 像素画风会重新对齐到真实的像素网格。
   - 按 `STYLE_FX` 处理可读性（v0.2.1 起）：
     - 我方加墨线 + 琥珀色灯光描边，雾兽加深紫墨线。
     - 地块降饱和、降对比，好让角色比背景突出。
   - `keyart.png`（标题主视觉）和 `paper.png`（HUD 纸张纹理）存成 `ui/*.jpg`。
   - 主视觉出图时，把 `units.png`、`enemies.png` 作为参考图传进去，人物就能和游戏里一致。
3. **导入并自检**：
   - `godot_console --headless --path . --import`
   - `godot_console --path . -- --autoshot=<目录>`：同一帧会给每套画风各截一张图。
4. **出对比图**：`python tools/art/compare_styles.py <截图目录> docs/acceptance/v<版本>`
5. **评审**：用 agy 请 Gemini 看对比图。要在 Git Bash 里运行，PowerShell 5.1 传参会把引号弄坏。
   ```bash
   agy --model gemini-4-neon-medium --mode plan --print-timeout 300s -p "<评审提示词>"
   ```

游戏里的接入点：
- `scripts/art_style.gd`：画风列表；找不到贴图时自动退回灰盒画法。
- `battle_screen.gd`：绘制地块、角色、敌人、道具。
- `unit_card.gd`：卡片上的头像。

## 提示词（v0.2.0）

三套画风共用同一组内容描述，只替换开头的**画风句**。

**画风句**
- A 赛璐璐：`Clean modern anime cel-shaded illustration, crisp dark outlines, flat colors with one hard shadow tone, bright saturated palette, polished mobile game unit sprite art.`
- B 水彩：`Soft hand-painted watercolor and gouache storybook illustration, gentle colored-pencil linework, muted misty teal and warm amber palette, painterly texture only inside the shapes, clean edges.`
- C 像素：`Hi-bit pixel art sprites, chunky clean square pixels on a coarse grid, limited 32-color palette, no anti-aliasing, no blur, no gradients, retro 16-bit console tactics RPG look.`

**角色**：一排 5 个 Q 版全身角色，约 2.5 头身，3/4 侧面朝右，脚底对齐，透明背景，无文字。
- 统一元素：深海军蓝外套、黄铜扣、琥珀色小灯笼徽记，外加各自的强调色。
- 剑士：银色短发，橙色围巾 `#e07b4f`，弯刀。
- 盾卫：黄铜铠甲，蓝边 `#4f8fd8`，灯塔透镜样式的大圆盾。
- 弓手：水手贝雷帽，长辫子，绿斗篷 `#6cbf5a`，长弓。
- 术士：兜帽长外套，紫色内衬 `#a46ee0`，杖头挂着装紫焰的笼灯。
- 医师：白围裙，金黄腰带 `#f2d16b`，绿光小提灯，挎包上有叶子徽记。

**敌人和道具**：一排 5 个，透明背景，生物朝右。
- 雾团：淡紫雾气凝成的圆团，青色发光眼睛。
- 雾犬：灰紫雾气组成的瘦狼，拖着雾尾。
- 雾甲：裹着生锈、长满藤壶的船壳铁甲的巨大雾怪。
- 雾门：残破的石砌港口拱门，门里是猩红偏紫的雾漩涡。
- 灯塔：白色塔身配海军蓝环带，塔顶亮着琥珀色的灯。

**地块**：2×2 四宫格，俯视正交视角，可无缝平铺。
- 左上：港口石板。
- 右上：带黄铜铆钉的木栈道。
- 左下：起雾的深色海面。
- 右下：长青苔的码头石墙。

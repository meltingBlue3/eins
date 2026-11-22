# 雾港守灯人（工作标题）· eins

原创二次元风格塔防。浓雾里的雾兽沿航道涌向灯塔，你把守灯人部署在地面和高台上守住它。

当前版本 **v0.1.0 · 灰盒原型**：一关完整可玩，画面是临时图形。

## 试玩

解压 `builds/eins-v0.1.0-windows.zip`，双击 `eins.exe`。不需要安装任何东西。

| 操作 | 方式 |
|---|---|
| 部署 | 点击卡片后点击发光格子，或者直接把卡片拖过去；数字键 1–5 选卡 |
| 撤退 | 点击场上单位 → 撤退（返还一半费用） |
| 暂停 / 倍速 | 空格 / F，或右上角按钮 |
| 取消 | 右键或 Esc |

## 开发

Godot 4.7.2。规则见 `CLAUDE.md`，路线见 `ROADMAP.md`，变化见 `CHANGELOG.md`，验收卡在 `docs/acceptance/`。

```powershell
./tools/build.ps1   # 测试 + 导出 + 打包
```

字体：Noto Sans CJK SC（SIL OFL 1.1，见 `assets/fonts/OFL.txt`）。

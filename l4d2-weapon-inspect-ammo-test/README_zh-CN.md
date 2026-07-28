# [TEST] 武器检视弹药查看

当前版本：`1.7.0`。**这是一个测试性质的项目。**

一个独立的《求生之路 2》**VScript 插件（VPK）**。**按住 Shift 再按 E**（或在聊天栏输入 `!ammo`），即可“检视”手中的武器：

- 武器播放它自己的**换弹 / 检视动作**；
- **剩余弹药量**同时输出到聊天栏和屏幕正中；
- **不会真的换弹** —— 弹匣和备用弹药都保持原样。

不需要 MetaMod，不需要 SourceMod，不需要 `-insecure`。只要把一个 `.vpk` 放进
addons 文件夹即可。

> 英文版：[README.md](README.md) ·
> 技术要点与排查说明：[TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)

---

## 安装

### 方式 A —— 在 Windows 上一键打包（推荐）

1. 下载或克隆本文件夹。
2. 双击 **`build_vpk.bat`**。
   脚本会自动在你的《求生之路 2》安装目录里找到 `vpk.exe`，打包源文件夹，
   生成 `test_ammo_inspect.vpk`。
3. 把生成的文件复制到：

   ```text
   ...\Steam\steamapps\common\Left 4 Dead 2\left4dead2\addons\
   ```

4. 启动游戏，插件会出现在游戏内的**附加内容（Add-ons）**列表里。

### 方式 B —— 手动打包

把 **`test_ammo_inspect`** 文件夹直接拖到 `Left 4 Dead 2\bin\vpk.exe` 上即可。
`vpk.exe` 会在被拖文件夹的**同级目录**生成 `test_ammo_inspect.vpk`，复制到
`left4dead2\addons\` 就行。

**只需要打包这一个源文件夹。** `README`、`TECHNICAL_NOTES.md`、`LICENSE`、
`build_vpk.bat` 和 `reference/` 都不要放进 VPK —— 它们是仓库文档，不是游戏内容。

> VPK 内部结构必须是下面这样，`scripts` 位于根目录：
>
> ```text
> addoninfo.txt
> scripts/vscripts/mapspawn_addon.nut
> scripts/vscripts/ebf_inspect_ammo.nut
> ```
>
> 如果误把**上一级**文件夹（也就是 `l4d2-weapon-inspect-ammo-test` 本身）拖上去，
> 游戏将找不到脚本。

#### 关于给文件夹改名

**可以随便改。** VPK 的文件名就取自被拖的文件夹名，而脚本内部完全不依赖这个名字，
只依赖内部的 `scripts/vscripts/...` 结构。`build_vpk.bat` 也做了自动识别（它会找
同级目录里含 `addoninfo.txt` 的那个文件夹），改名后照样能用。

需要注意：游戏内**附加内容列表里显示的名称**来自 `addoninfo.txt` 里的
`addontitle` 字段，不是文件名。如果希望列表里显示的名字也跟着变，请一并修改
`addontitle`。

### 方式 C —— 散装文件（不打包，快速测试用）

把两个 `.nut` 文件复制到：

```text
...\Left 4 Dead 2\left4dead2\scripts\vscripts\
```

注意 `mapspawn_addon.nut` 是公共文件名，如果已有其他散装脚本占用了它，请合并
内容而不要直接覆盖。

---

## 使用

**开箱即用，不需要绑定任何按键。**

游戏中**按住 Shift 再按 E**（约 0.3 秒）即可检视。

检视过程中**随时可以打断**：按 R 直接换弹（一次就生效）、开火或右键推人都会立刻
取消检视，武器立即恢复可用。

或者在聊天栏输入：

```text
!ammo
```

> **为什么是 Shift+E？**
> `+alt1`/`+alt2` 这类"空闲"输入位，在重度脚本玩家手上基本都被占了。Shift 和 E
> 是既有操作，**不占用任何可绑定键位**，左手姿势自然，画面上也不会出现"先蹲一下"
> 这种反直觉动作。单独按 Shift（静步）或单独按 E（开门/急救）都不会触发，必须
> **按住 Shift 的同时按 E** 并保持 `hold_time` 才触发。

如果你觉得 Ctrl+Shift 不顺手，可以在配置里改成任意组合，例如：

```text
combo duck+zoom          // Ctrl + 右键瞄准
combo speed+attack2      // Shift + 鼠标右键
```

也可以改回单键模式（如果你确实有空闲键）：

```text
trigger key
key alt1
```

## 确认脚本已生效

打开开发者控制台，正常加载时应当能看到：

```text
[InspectAmmo] Loaded N setting(s) from ems/ebf_inspect_ammo/settings.txt
[InspectAmmo] Manager entity active (index NN).
[InspectAmmo] Version 1.7.0 ready. Hold E and tap R to inspect.
```

诊断命令：

| 命令 | 作用 |
|---|---|
| `script EBFInspectAmmo.Status()` | 输出全部设置、当前武器、弹药、视角模型路径，以及**该模型实际拥有哪些动作序列**。 |
| `script EBFInspectAmmo.TestFire()` | 直接对自己执行一次检视并打印详细过程，可在不按组合键的情况下验证脚本是否正常。 |
| `script EBFInspectAmmo.Reload()` | 不换地图直接重新读取设置文件。 |

---

## 配置

首次运行时自动生成：

```text
left4dead2\ems\ebf_inspect_ammo\settings.txt
```

仓库内另附一份参考副本：`reference/ems/ebf_inspect_ammo/settings.txt`。

| 键名 | 有效范围 | 默认值 | 说明 |
|---|---|---|---|
| `enable` | 0/1 | 1 | 总开关。 |
| `trigger` | combo/key/chat | combo | 触发方式。combo=组合键（无需绑定），key=单键，chat=仅聊天。 |
| `combo` | 见下 | speed+use | 组合键。可用名：duck(Ctrl)、speed(Shift 静步)、zoom、use(E)、reload(R)、jump、attack2(右键)、alt1、alt2，用 `+` 连接。 |
| `hold_time` | 0.0–3.0 | 0.30 | 组合键需按住多久才触发，防止误触。 |
| `chat_command` | 任意文本 | !ammo | 聊天命令，**任何模式下都有效**，绝不冲突。 |
| `key` | alt1/alt2/zoom/reload | alt1 | 仅 trigger=key 时使用。 |
| `modifier` | none/use/duck/speed | none | 仅 trigger=key 时的额外按键。 |
| `require_use` | 0/1 | 0 | 旧版兼容：设为 1 可恢复 E+R（不推荐，快速点按仍可能真换弹）。 |
| `output_chat` | 0/1 | 1 | 在聊天栏输出弹药量。 |
| `output_center` | 0/1 | 1 | 在屏幕正中输出弹药量。 |
| `play_animation` | 0/1 | 1 | 播放换弹/检视动作。 |
| `anim_source` | auto/pickup/deploy/idle/reload | auto | 播放哪个动画。auto=有专用检视动画就用，否则用**物品拾取待机动作**（就是盯着可拾取物品时举枪端详的那个）。 |
| `block_reload` | 0/1 | 1 | 按住 E 时把弹匣临时报告为满，使引擎拒绝换弹；松开 E 立即还原真实弹数。 |
| `spoof_time` | 0.5–10.0 | 2.50 | 每次检视后，弹匣被报告为"满"的秒数，用于覆盖动画时长。 |
| `cancel_grace` | 0.0–2.0 | 0.35 | 仅当 R 本身是触发键时生效的宽限期。开火/推人始终能立刻取消检视。 |
| `cooldown` | 0.0–10.0 | 1.20 | 两次检视之间的冷却秒数。 |
| `melee_ok` | 0/1 | 1 | 允许检视近战等无弹匣物品。 |
| `debug` | 0/1 | 0 | 输出详细调试信息。 |

非法数值会被**逐项**拒绝并在控制台给出对应警告，同时保留默认值 —— 单个笔误不会
让整个插件失效。修改后执行 `script EBFInspectAmmo.Reload()` 或切换地图生效。

---

## 多人游戏说明

VScript 运行在**服务端**：

- **自己当房主（本地/监听服务器）**：你和所有连入的玩家都能正常使用。
- **加入别人的服务器**：需要该服务器安装本插件。客户端单方面装 VPK 无法给服务器
  添加行为，这是所有 VScript 插件的共同限制。
- **专用服务器**：把 VPK 放到服务器的 `left4dead2/addons/` 目录。

---

## 兼容性

通过 `mapspawn_addon.nut` 加载 —— 这是官方提供的自动运行入口，它与原版脚本
**并存**而非替换。本插件**不会**替换 `scriptedmode.nut`、`mapspawn.nut` 或
`director_base.nut`，因此可以和地图修复、社区更新以及其他脚本插件共存。

如果你同时还装了别的检视类插件，请关闭其中一个，否则同一次按键会被两边同时响应。

---

## 卸载

删除 `left4dead2\addons\` 里的 `.vpk` 即可，另可一并删除
`left4dead2\ems\ebf_inspect_ammo\`。

---

## 故障排查

| 现象 | 处理 |
|---|---|
| 控制台完全没有 `[InspectAmmo]` 字样 | VPK 没被加载。确认它直接放在 `left4dead2\addons\` 下，并在附加内容列表中已启用。 |
| 出现 `FAILED to include ebf_inspect_ammo.nut` | 打包目录错了，`scripts/` 必须位于 VPK 根目录。 |
| 弹药能显示但没有动作 | 该模型没有检视/换弹序列，用 `Status()` 确认。 |
| 组合键没反应 | 先在聊天栏试 `!ammo`：若聊天能用说明脚本正常，是组合键被占用或按得不够久。执行 `Status()` 查看 `combo now`。也可能是在别人的服务器上。 |
| 真的换弹了 | 执行 `Status()` 查看 `trigger mode`。若检视动画很长被中途打断，调大 `spoof_time`。 |

更详细的说明见 [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md) 第 8 节。

---

## 目录结构

```text
test_ammo_inspect/                       <- 只有这个文件夹会被打包进 VPK
  addoninfo.txt                          创意工坊 / 附加内容列表信息
  scripts/vscripts/mapspawn_addon.nut    加载器（每张地图运行）
  scripts/vscripts/ebf_inspect_ammo.nut  全部逻辑

build_vpk.bat                            Windows 一键打包脚本
reference/ems/ebf_inspect_ammo/settings.txt   生成的设置文件副本
TECHNICAL_NOTES.md                       设计思路与排查记录
README.md / README_zh-CN.md
LICENSE
```

空行以下的内容都是仓库文档，**不会**进入 VPK。

## 许可

GNU 通用公共许可证第 3 版或更新版本（`GPL-3.0-or-later`），与本仓库中另一个项目
保持一致。

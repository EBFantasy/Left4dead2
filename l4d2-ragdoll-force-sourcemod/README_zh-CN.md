# L4D2 特感击退 — SourceMod 版

当前版本：`0.3.4`。

这是《求生之路 2》特感死亡布娃娃击退的服务端 SourceMod 版本。Windows 一键安装包已经包含测试过的 MetaMod:Source、SourceMod 运行环境、编译完成的插件、CFG 和 EMS。无需另外下载编译器，也不需要自己编译 `.sp` 源码。

## 一键包内置版本

- MetaMod:Source `1.12.0-dev+1224`
- SourceMod `1.12.0.7239`
- 特感击退 SourceMod 插件 `0.3.4`
- SourceMod 自带的 SDKHooks

该一键运行环境面向 Windows，Linux用户请前往Github源码仓库自行下载配置。

## 一键安装

1. 完全关闭《求生之路 2》。
2. 在 Steam 库中右键《求生之路 2》，选择“属性”，在“通用”的“启动选项”中填写：

   ```text
   -insecure
   ```

3. 下载 `L4D2_Ragdoll_Force_SourceMod_0.3.4_Windows.zip`。
4. 打开游戏目录并进入：

   ```text
   ...\Steam\steamapps\common\Left 4 Dead 2\left4dead2\
   ```

5. 将压缩包中的**addons**、**ems**和**cfg**文件夹依次**解压到 `left4dead2` 目录下**，允许合并文件夹和覆盖同名框架文件。
6. 启动游戏并打开开发者控制台。
7. 依次输入：

   ```text
   meta list
   sm version
   sm plugins list
   ```

   MetaMod 和 SourceMod 应正常显示，插件列表中应出现无错误状态的 `L4D2 Ragdoll Force`。

不要只解压到 `left4dead2\addons`。一键包还包含必须放在 `left4dead2` 根目录下的 `cfg` 和 `ems` 文件夹。

### 关于 `-insecure`

本地加载 SourceMod 时需要使用 `-insecure` 启动游戏。该参数会在本次游戏进程中关闭 VAC，因此无法加入启用 VAC 的公共服务器。准备恢复普通 VAC 联机时，应先确保完全移除或无效化（例如在文件格式后加入.bk这样的后缀名）sourcemod以及该脚本相关组件，移除-insecure启动项后再进入游戏。

## 参数配置

普通用户建议编辑：

```text
left4dead2\ems\ragdoll_force\settings.txt
```

文件内提供完整说明与参数，已写明有效范围和建议范围。EMS 在普通 CFG 之后加载，为最终覆盖层。

修改后大退游戏重进，或在游戏大厅控制台执行：

```text
sm_ragdoll_force_reload_ems
```

传统 SourceMod CFG 仍位于（若无需求，请不要擅自修改该文件）：

```text
left4dead2\cfg\sourcemod\l4d2_death_ragdoll_force.cfg
```

## 临时关闭特感击退插件

仅在当前游戏进程中关闭，可在控制台输入：

```text
sm plugins unload l4d2_death_ragdoll_force
```

重新启动游戏或服务器后它会再次加载。

若要跨重启保持关闭，先退出游戏，再把：

```text
left4dead2\addons\sourcemod\plugins\l4d2_death_ragdoll_force.smx
```

移动到：

```text
left4dead2\addons\sourcemod\plugins\disabled\l4d2_death_ragdoll_force.smx
```

移回原处即可重新启用。

## 永久卸载特感击退插件

关闭游戏后删除：

```text
left4dead2\addons\sourcemod\plugins\l4d2_death_ragdoll_force.smx
left4dead2\cfg\sourcemod\l4d2_death_ragdoll_force.cfg
left4dead2\ems\ragdoll_force\
```

如果安装包中保留了可选源码，也可删除：

```text
left4dead2\addons\sourcemod\scripting\l4d2_death_ragdoll_force.sp
```

这样只会删除特感击退，不会删除 MetaMod、SourceMod 或其他 SourceMod 插件。

## 临时关闭整个 MetaMod/SourceMod

关闭游戏后重命名：

```text
left4dead2\addons\metamod.vdf
left4dead2\addons\metamod_x64.vdf
```

例如改成：

```text
metamod.vdf.disabled
metamod_x64.vdf.disabled
```

不再使用 SourceMod 时即可移除 Steam 启动项中的 `-insecure`。同理恢复时只需删除两个 VDF 文件的.disabled后缀名并重新添加 `-insecure` 即可重启框架。

## 永久删除 MetaMod 和 SourceMod

只有确认其他 SourceMod 插件也不再需要时才进行。关闭游戏、备份自定义配置后删除：

```text
left4dead2\addons\metamod\
left4dead2\addons\sourcemod\
left4dead2\addons\metamod.vdf
left4dead2\addons\metamod_x64.vdf
left4dead2\cfg\sourcemod\
```

最后移除 Steam 启动项中的 `-insecure`。该操作会删除整个框架以及全部 SourceMod 插件，而不仅是特感击退。

## 更新 MetaMod 和 SourceMod（如有必要）

1. 关闭游戏或服务器。
2. 备份自定义内容，尤其是：
   - `addons\sourcemod\plugins\`
   - `addons\sourcemod\configs\`
   - `cfg\sourcemod\`
   - `ems\`
3. 从 MetaMod:Source 和 SourceMod 官方下载页获取最新 Windows 版本：
   - <https://www.sourcemm.net/downloads.php>
   - <https://www.sourcemod.net/downloads.php>
4. 先把 MetaMod:Source 解压到 `left4dead2`，再把 SourceMod 解压到同一位置，并允许覆盖旧框架文件。
5. 确认特感击退的 SMX、CFG 和 EMS 仍在上述位置；缺失时从本项目重新复制。
6. 使用 `-insecure` 启动，再次检查 `meta list`、`sm version` 和 `sm plugins list`。

更新后不要把旧版框架 DLL 覆盖回去；只按需要恢复自己的插件和配置文件。

## 重要兼容说明

- 不要同时启用特感击退的 SourceMod 版与 VScript/VPK 版，否则击退会叠加。
- 插件只处理受支持武器造成的相应特感的致死击杀，声明的武器和特感之外的一律不生效。
- 这是服务端插件；加入他人服务器的普通客户端无法自行让它生效，必须由房主或服务器安装。
- `debug 1` 只用于排查，正常使用请恢复为 `0`。

## 常见问题排查

- `meta list` 无法使用：检查 `metamod.vdf`、`metamod_x64.vdf`、`addons\metamod` 和 `-insecure`。
- `sm version` 无法使用：检查 `addons\sourcemod` 和 `addons\metamod\sourcemod.vdf`。
- 插件显示错误：查看 `left4dead2\addons\sourcemod\logs\errors_*.log`。
- 插件已加载但参数不变化：执行 `sm_ragdoll_force_reload_ems`，并检查 EMS 是否含有非法值或越界值。

## 源码与许可证

SourcePawn 源码位于：

```text
addons\sourcemod\scripting\l4d2_death_ragdoll_force.sp
```

特感击退采用 GNU 通用公共许可证第 3 版或任何更高版本（`GPL-3.0-or-later`）授权。完整许可证文本见 `LICENSE`。

完整 Windows 运行包仅作为 GitHub Release 附件发布，不存放在本源码目录中。第三方运行环境信息记录在 `THIRD_PARTY_NOTICES.txt`。

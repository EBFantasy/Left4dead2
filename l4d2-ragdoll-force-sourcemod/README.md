# L4D2 Ragdoll Force — SourceMod

Current release: `0.3.4`.

This is the server-side SourceMod edition of Ragdoll Force for Left 4 Dead 2. The Windows one-click package already contains the tested MetaMod:Source and SourceMod runtime, the compiled plugin, CFG, and EMS settings. There is no need to download a compiler separately or compile the `.sp` source yourself.

## Included runtime

- MetaMod:Source `1.12.0-dev+1224`
- SourceMod `1.12.0.7239`
- Ragdoll Force SourceMod plugin `0.3.4`
- SDKHooks from the bundled SourceMod runtime

This one-click runtime is intended for Windows. Linux users should visit the GitHub source repository to download and configure the required files themselves.

## One-click installation

1. Fully close Left 4 Dead 2.
2. In Steam, right-click **Left 4 Dead 2**, select **Properties**, open **General**, and enter this in **Launch Options**:

   ```text
   -insecure
   ```

3. Download `L4D2_Ragdoll_Force_SourceMod_0.3.4_Windows.zip`.
4. Open the game directory, then enter:

   ```text
   ...\Steam\steamapps\common\Left 4 Dead 2\left4dead2\
   ```

5. Extract the **`addons`**, **`ems`**, and **`cfg`** folders from the ZIP into the **`left4dead2` folder**, allowing folder merging and replacement of framework files with the same names.
6. Start the game and open the developer console.
7. Run:

   ```text
   meta list
   sm version
   sm plugins list
   ```

   MetaMod and SourceMod should report normally, and `L4D2 Ragdoll Force` should appear without an error state.

Do not extract only into `left4dead2\addons`. The package also contains required `cfg` and `ems` folders that belong directly under `left4dead2`.

### About `-insecure`

The local SourceMod setup requires the game to be started with `-insecure`. While this option is active, VAC is disabled for that game session and VAC-secured public servers cannot be joined. Before returning to normal VAC-secured online play, make sure SourceMod and this plugin's related components have been completely removed or disabled—for example, by appending a suffix such as `.bk` to their filenames—then remove `-insecure` from the launch options before starting the game.

## Configuration

For typical users, the recommended configuration file to edit is:

```text
left4dead2\ems\ragdoll_force\settings.txt
```

It contains complete instructions and parameter descriptions, including valid and recommended ranges. It loads after the regular CFG and therefore acts as the final override layer.

After making changes, fully exit and restart the game, or run the following command from the developer console while in the game lobby:

```text
sm_ragdoll_force_reload_ems
```

The traditional SourceMod CFG remains at the following location. Do not modify this file unless you specifically need to:

```text
left4dead2\cfg\sourcemod\l4d2_death_ragdoll_force.cfg
```

## Temporarily disable only Ragdoll Force

For the current game session, run:

```text
sm plugins unload l4d2_death_ragdoll_force
```

It will load again after restarting the game or server.

To keep it disabled across restarts, close the game and move:

```text
left4dead2\addons\sourcemod\plugins\l4d2_death_ragdoll_force.smx
```

to:

```text
left4dead2\addons\sourcemod\plugins\disabled\l4d2_death_ragdoll_force.smx
```

Move it back to re-enable it.

## Permanently uninstall only Ragdoll Force

Close the game and delete:

```text
left4dead2\addons\sourcemod\plugins\l4d2_death_ragdoll_force.smx
left4dead2\cfg\sourcemod\l4d2_death_ragdoll_force.cfg
left4dead2\ems\ragdoll_force\
```

If the optional source file was installed, it can also be removed:

```text
left4dead2\addons\sourcemod\scripting\l4d2_death_ragdoll_force.sp
```

This leaves MetaMod, SourceMod, and other SourceMod plugins intact.

## Temporarily disable all MetaMod/SourceMod plugins

Close the game and rename both loader files:

```text
left4dead2\addons\metamod.vdf
left4dead2\addons\metamod_x64.vdf
```

for example to:

```text
metamod.vdf.disabled
metamod_x64.vdf.disabled
```

Remove `-insecure` from Steam Launch Options if SourceMod is no longer needed. To enable the framework again, remove the `.disabled` suffix from both VDF filenames and add `-insecure` back to the launch options.

## Permanently remove MetaMod and SourceMod

Only do this when no other SourceMod plugins are needed. Close the game, back up any custom configuration, then delete:

```text
left4dead2\addons\metamod\
left4dead2\addons\sourcemod\
left4dead2\addons\metamod.vdf
left4dead2\addons\metamod_x64.vdf
left4dead2\cfg\sourcemod\
```

Also remove `-insecure` from Steam Launch Options. This removes the entire framework and every installed SourceMod plugin, not only Ragdoll Force.

## Updating MetaMod and SourceMod (if necessary)

1. Close the game or server.
2. Back up custom files, especially:
   - `addons\sourcemod\plugins\`
   - `addons\sourcemod\configs\`
   - `cfg\sourcemod\`
   - `ems\`
3. Download the current Windows packages from the official MetaMod:Source and SourceMod download pages:
   - <https://www.sourcemm.net/downloads.php>
   - <https://www.sourcemod.net/downloads.php>
4. Extract MetaMod:Source into `left4dead2`, then extract SourceMod into the same folder and allow replacement of old framework files.
5. Keep or restore the Ragdoll Force SMX, CFG, and EMS files listed above.
6. Start with `-insecure` and verify `meta list`, `sm version`, and `sm plugins list` again.

Do not restore old framework DLLs after updating. Restore only your custom plugins and configuration files when needed.

## Important compatibility notes

- Do not enable this SourceMod edition together with the Ragdoll Force VScript/VPK edition; their effects will stack.
- The plugin only affects lethal kills of the specified Special Infected caused by supported weapons. It has no effect on any weapon or Special Infected not explicitly listed as supported.
- A client cannot activate this server-side plugin on somebody else's server; the host or server owner must install it.
- Set `debug 1` in EMS only while diagnosing, then return it to `0`.

## Troubleshooting

- `meta list` fails: check `metamod.vdf`, `metamod_x64.vdf`, the `addons\metamod` directory, and the `-insecure` launch option.
- `sm version` fails: check `addons\sourcemod` and `addons\metamod\sourcemod.vdf`.
- The plugin shows an error: inspect `left4dead2\addons\sourcemod\logs\errors_*.log`.
- The plugin is loaded but settings do not change: run `sm_ragdoll_force_reload_ems` and check the EMS file for invalid or out-of-range values.

## Source code and license

The SourcePawn source is located at:

```text
addons\sourcemod\scripting\l4d2_death_ragdoll_force.sp
```

Ragdoll Force is licensed under the GNU General Public License, version 3 or any later version (`GPL-3.0-or-later`). See `LICENSE` for the full license text.

Complete Windows runtime packages are distributed as GitHub Release assets and are not stored in this source directory. Third-party runtime information is recorded in `THIRD_PARTY_NOTICES.txt`.

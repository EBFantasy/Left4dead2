// =========================================================
// bot_spitter_response - bot_spitter_events.nut
//
// 事件处理脚本. 通过 g_spitter_event_carrier 实体的 vscripts 属性加载.
// 引擎对实体绑定的脚本会自动扫描其中的 function OnGameEvent_X 全局函数.
//
// 这是工坊 mod (3154395822 acid_evasion_and_autopick) 验证可行的唯一
// 可靠事件注册方式. 根作用域的 ::OnGameEvent_X + __CollectGameEventCallbacks
// 在 L4D2 director_base_addon 环境下不工作.
// =========================================================

function OnGameEvent_spit_burst(event)
{
    if ("HandleSpitBurstEvent" in getroottable())
        ::HandleSpitBurstEvent(event);
}

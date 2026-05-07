-- 这里是“武器 -> 已支持招式”的预设表。
-- 主脚本只负责读这份定义，然后自动生成 UI 和运行时覆盖逻辑。
-- 后续要支持更多武器时，优先在这里补数据，不要先改主逻辑。

local ordered_weapons = {
    {
        weaponType = 0,
        weaponName = "大剑",
        moves = {}
    },
    {
        weaponType = 1,
        weaponName = "斩斧",
        moves = {}
    },
    {
        weaponType = 2,
        weaponName = "太刀",
        moves = {
            {
                id = "iai_spirit_slash_counter",
                label = "居合气刃斩",
                actionIndex = 9250,
                valueMode = "end_frame",
                sliderLabel = "GP结束帧",
                min = 0,
                max = 60,
                default = 18,
                enabledByDefault = false,
                modeHint = "直接覆盖 PlayerFsm2ActionSeeThroughAttack 的 _EndFrame",
                description = "当前已确认条目：来自 longsword dump 与 Endless Longsword 参考实现，对应居合气刃斩成功窗口。默认原值为 18。"
            }
        }
    },
    {
        weaponType = 3,
        weaponName = "轻弩",
        moves = {}
    },
    {
        weaponType = 4,
        weaponName = "重弩",
        moves = {}
    },
    {
        weaponType = 5,
        weaponName = "大锤",
        moves = {}
    },
    {
        weaponType = 6,
        weaponName = "铳枪",
        moves = {}
    },
    {
        weaponType = 7,
        weaponName = "长枪",
        moves = {
            {
                id = "instant_block",
                label = "精准防御",
                actionIndex = 9379,
                valueMode = "end_frame",
                sliderLabel = "GP结束帧",
                min = 0,
                max = 60,
                default = 32,
                enabledByDefault = false,
                modeHint = "直接覆盖 _EndFrame",
                description = "当前示例来自参考项目 ComboLance：这里把长枪精准防御的 action 结束帧暴露成滑条。"
            }
        }
    },
    {
        weaponType = 8,
        weaponName = "片手剑",
        moves = {}
    },
    {
        weaponType = 9,
        weaponName = "双刀",
        moves = {}
    },
    {
        weaponType = 10,
        weaponName = "狩猎笛",
        moves = {}
    },
    {
        weaponType = 11,
        weaponName = "盾斧",
        moves = {}
    },
    {
        weaponType = 12,
        weaponName = "操虫棍",
        moves = {}
    },
    {
        weaponType = 13,
        weaponName = "弓",
        moves = {}
    }
}

local weapon_by_type = {}
local weapon_combo_labels = {}

for _, weapon_def in ipairs(ordered_weapons) do
    weapon_by_type[weapon_def.weaponType] = weapon_def
    table.insert(weapon_combo_labels, weapon_def.weaponName)
end

return {
    ordered_weapons = ordered_weapons,
    weapon_by_type = weapon_by_type,
    weapon_combo_labels = weapon_combo_labels
}

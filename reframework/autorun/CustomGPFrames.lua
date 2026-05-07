-- 这是 Custom GP Frames 的主入口脚本。
-- 目标是把“底层按 ActionIndex 改帧”的能力，包装成更适合直接使用的 UI：
-- 1. 在 REFramework 里下拉选择武器。
-- 2. 展示该武器已经录入的 GP 招式。
-- 3. 用勾选框和滑条直接调整这些招式的判定窗口。

local glyph_ranges = {
    0x0020, 0x00FF,
    0x2000, 0x206F,
    0x3000, 0x30FF,
    0x31F0, 0x31FF,
    0x4e00, 0x9FFF,
    0xFF00, 0xFFEF,
    0,
}

local language_font = {}
language_font[0] = "NotoSansJP-Regular.otf"
language_font[11] = "NotoSansKR-Regular.otf"
language_font[12] = "NotoSansTC-Regular.otf"
language_font[13] = "NotoSansSC-Regular.otf"

for language, font_name in pairs(language_font) do
    language_font[language] = imgui.load_font(font_name, 19, glyph_ranges)
end

local defs = require("custom_gp_frames/weapon_move_defs")

local config_path = "CustomGPFrames.json"
local ordered_weapons = defs.ordered_weapons
local weapon_by_type = defs.weapon_by_type
local weapon_combo_labels = defs.weapon_combo_labels
local default_selected_weapon = 7

-- 默认配置现在不再暴露 ActionIndex 给用户，而是按“武器 -> 招式”组织。
local default_settings = {
    modEnabled = true,
    selectedWeaponType = default_selected_weapon,
    weapons = {}
}

local settings = json.load_file(config_path) or default_settings

-- 记录本次会话里被改过的 action 原始值，方便在关闭时恢复。
local original_frames = {}

local function get_display_language()
    local option_manager = sdk.get_managed_singleton("snow.gui.OptionManager")
    if not option_manager then
        return nil
    end

    return option_manager:call("getDisplayLanguage()")
end

-- 读取当前玩家对象。
local function get_master_player()
    local player_manager = sdk.get_managed_singleton("snow.player.PlayerManager")
    if not player_manager then
        return nil
    end

    return player_manager:call("findMasterPlayer")
end

-- 从玩家对象一路拿到当前正在使用的动作树。
local function get_tree_object()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    local player_game_object = master_player:call("get_GameObject")
    if not player_game_object then
        return nil
    end

    local motion_fsm2 = player_game_object:call("getComponent(System.Type)", sdk.typeof("via.motion.MotionFsm2"))
    if not motion_fsm2 then
        return nil
    end

    local layer = motion_fsm2:call("getLayer", 0)
    if not layer then
        return nil
    end

    return layer:get_tree_object()
end

-- 读取当前装备武器类型。
local function get_player_weapon_type()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    return master_player:get_field("_playerWeaponType")
end

-- 按 ActionIndex 从全局 action 数组中取对象。
local function get_action(action_index)
    local tree = get_tree_object()
    if not tree then
        return nil
    end

    local actions = tree:get_actions()
    if not actions or action_index < 0 or action_index >= actions:size() then
        return nil
    end

    return actions[action_index]
end

-- 取某把武器在配置文件里的状态表，没有的话就创建。
local function get_weapon_settings(weapon_type)
    local key = tostring(weapon_type)

    if type(settings.weapons[key]) ~= "table" then
        settings.weapons[key] = {}
    end

    return settings.weapons[key]
end

-- 给某个招式补默认配置。
local function ensure_move_state(weapon_type, move_def)
    local weapon_settings = get_weapon_settings(weapon_type)

    if type(weapon_settings[move_def.id]) ~= "table" then
        weapon_settings[move_def.id] = {}
    end

    local move_state = weapon_settings[move_def.id]

    if move_state.enabled == nil then
        move_state.enabled = move_def.enabledByDefault or false
    end

    if move_state.value == nil then
        move_state.value = move_def.default
    end

    return move_state
end

-- 配置结构兼容处理。
-- 这样即使后面我们继续扩充武器和招式，旧 json 也能自动补字段。
local function ensure_settings_shape()
    if type(settings) ~= "table" then
        settings = default_settings
    end

    if settings.modEnabled == nil then
        settings.modEnabled = true
    end

    if weapon_by_type[settings.selectedWeaponType] == nil then
        settings.selectedWeaponType = default_selected_weapon
    end

    if type(settings.weapons) ~= "table" then
        settings.weapons = {}
    end

    for _, weapon_def in ipairs(ordered_weapons) do
        local weapon_settings = get_weapon_settings(weapon_def.weaponType)

        for _, move_def in ipairs(weapon_def.moves) do
            ensure_move_state(weapon_def.weaponType, move_def)
        end

        -- 留空没问题，但保证这个武器类型对应的表存在，后续扩展时更稳。
        if weapon_settings == nil then
            settings.weapons[tostring(weapon_def.weaponType)] = {}
        end
    end
end

-- 把当前设置写回 json。
local function save_settings()
    json.dump_file(config_path, settings)
end

ensure_settings_shape()
save_settings()

-- 只在第一次改某个 action 时记录原始帧值，避免把修改后的值再次当作“原始值”。
local function snapshot_original(action_index, action_obj)
    if action_index == nil or action_obj == nil or original_frames[action_index] ~= nil then
        return
    end

    original_frames[action_index] = {
        startFrame = action_obj:get_field("_StartFrame"),
        endFrame = action_obj:get_field("_EndFrame")
    }
end

-- 恢复单个 action 的原始帧值。
local function restore_action(action_index)
    local original = original_frames[action_index]
    if original == nil then
        return
    end

    local action_obj = get_action(action_index)
    if action_obj == nil then
        return
    end

    action_obj:set_field("_StartFrame", original.startFrame)
    action_obj:set_field("_EndFrame", original.endFrame)
end

-- 恢复所有被改过的 action。
local function restore_all_actions()
    for action_index, _ in pairs(original_frames) do
        restore_action(action_index)
    end
end

-- 把 UI 里的“单个数值”真正写到 action 上。
-- 这里先支持一种最常见模式：直接覆盖 _EndFrame。
-- 后面如果某些武器需要改成“按时长换算”或者同时改起始帧，可以在这里继续扩展。
local function apply_move_override(action_obj, move_def, move_state)
    if move_def.valueMode == "end_frame" then
        action_obj:set_field("_EndFrame", move_state.value * 1.0)
        return
    end

    if move_def.valueMode == "start_frame" then
        action_obj:set_field("_StartFrame", move_state.value * 1.0)
        return
    end
end

-- 收集当前装备武器应该生效的招式配置。
local function collect_active_overrides(active_weapon_type)
    local desired = {}
    local weapon_def = weapon_by_type[active_weapon_type]
    if weapon_def == nil then
        return desired
    end

    local weapon_settings = get_weapon_settings(active_weapon_type)

    for _, move_def in ipairs(weapon_def.moves) do
        local move_state = weapon_settings[move_def.id]
        if move_state and move_state.enabled then
            desired[move_def.actionIndex] = {
                moveDef = move_def,
                moveState = move_state
            }
        end
    end

    return desired
end

-- 把单个招式配置恢复到预设表里的默认值。
local function reset_move_state(move_def, move_state)
    move_state.enabled = move_def.enabledByDefault or false
    move_state.value = move_def.default
end

-- 每帧应用一次当前武器对应的覆盖配置。
-- 这样切场景、换武器、动作树刷新后都能重新套回去。
local function apply_custom_gp_frames()
    if not settings.modEnabled then
        restore_all_actions()
        return
    end

    local active_weapon_type = get_player_weapon_type()
    if active_weapon_type == nil then
        restore_all_actions()
        return
    end

    local desired = collect_active_overrides(active_weapon_type)

    for action_index, payload in pairs(desired) do
        local action_obj = get_action(action_index)
        if action_obj ~= nil then
            snapshot_original(action_index, action_obj)
            apply_move_override(action_obj, payload.moveDef, payload.moveState)
        end
    end

    for action_index, _ in pairs(original_frames) do
        if desired[action_index] == nil then
            restore_action(action_index)
        end
    end
end

re.on_frame(function()
    apply_custom_gp_frames()
end)

-- 把武器类型转成 combo 需要的下标。
local function get_weapon_combo_index(weapon_type)
    for index, weapon_def in ipairs(ordered_weapons) do
        if weapon_def.weaponType == weapon_type then
            return index
        end
    end

    return 1
end

-- 绘制某把武器下的招式配置。
local function draw_weapon_moves(weapon_def)
    local changed = false
    local toggle = false
    local weapon_settings = get_weapon_settings(weapon_def.weaponType)

    if #weapon_def.moves == 0 then
        imgui.text("这把武器的 GP 招式预设还没有录入。")
        imgui.text("后续只需要在 weapon_move_defs.lua 里补充数据即可。")
        return false
    end

    for _, move_def in ipairs(weapon_def.moves) do
        local move_state = ensure_move_state(weapon_def.weaponType, move_def)
        local node_name = move_def.label .. "##move_node_" .. weapon_def.weaponType .. "_" .. move_def.id

        if imgui.tree_node(node_name) then
            toggle, move_state.enabled = imgui.checkbox("启用##move_enabled_" .. weapon_def.weaponType .. "_" .. move_def.id, move_state.enabled)
            changed = changed or toggle

            toggle, move_state.value = imgui.slider_int(
                (move_def.sliderLabel or "数值") .. "##move_value_" .. weapon_def.weaponType .. "_" .. move_def.id,
                move_state.value,
                move_def.min,
                move_def.max
            )
            changed = changed or toggle

            if imgui.button("恢复默认##move_reset_" .. weapon_def.weaponType .. "_" .. move_def.id) then
                reset_move_state(move_def, move_state)
                changed = true
            end

            imgui.text("Action Index: " .. tostring(move_def.actionIndex))

            imgui.tree_pop()
        end
    end

    return changed
end

-- 顶层 UI：
-- 1. 总开关
-- 2. 当前装备武器提示
-- 3. 14 把武器下拉选择
-- 4. 该武器下已录入招式的滑条
re.on_draw_ui(function()
    local changed = false
    local toggle = false

    if imgui.tree_node("Custom GP Frames") then
        local language = get_display_language()
        local has_custom_font = language ~= nil and language_font[language] ~= nil

        if has_custom_font then
            imgui.push_font(language_font[language])
        end

        toggle, settings.modEnabled = imgui.checkbox("启用 Custom GP Frames", settings.modEnabled)
        changed = changed or toggle

        local active_weapon_type = get_player_weapon_type()
        if active_weapon_type ~= nil and weapon_by_type[active_weapon_type] ~= nil then
            imgui.text("当前装备武器: " .. weapon_by_type[active_weapon_type].weaponName)
        else
            imgui.text("当前装备武器: 未知")
        end

        local weapon_combo_index = get_weapon_combo_index(settings.selectedWeaponType)
        local combo_changed
        combo_changed, weapon_combo_index = imgui.combo("编辑武器", weapon_combo_index, weapon_combo_labels)
        if combo_changed then
            settings.selectedWeaponType = ordered_weapons[weapon_combo_index].weaponType
            changed = true
        end

        local selected_weapon_def = weapon_by_type[settings.selectedWeaponType]
        if selected_weapon_def ~= nil then
            imgui.text("当前编辑: " .. selected_weapon_def.weaponName)
            changed = draw_weapon_moves(selected_weapon_def) or changed
        end

        if imgui.button("保存配置") then
            save_settings()
        end

        if has_custom_font then
            imgui.pop_font()
        end

        imgui.tree_pop()
    end

    if changed then
        save_settings()
    end
end)

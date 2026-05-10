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
local general_weapon_type = "general"
local default_selected_weapon = general_weapon_type

-- 默认配置现在不再暴露 ActionIndex 给用户，而是按“武器 -> 招式”组织。
local default_settings = {
    modEnabled = true,
    selectedWeaponType = default_selected_weapon,
    weapons = {}
}

local settings = json.load_file(config_path) or default_settings

-- 记录本次会话里被改过的 action 原始值，方便在关闭时恢复。
local original_frames = {}

-- 太刀居合成功奖励模拟的运行时状态。
-- 这里不做全武器泛化，只服务当前的太刀居合实验功能。
local runtime_state = {
    activeLongSwordIaiAttempt = nil,
    pendingLongSwordIaiReward = nil,
    lastProcessedDamageTick = nil,
    lastForcedSuccessAt = nil,
    lastJumpTargetNodeId = nil,
    lastKnownMotionId = nil,
    lastKnownMotionFrame = nil,
    lastKnownWeaponType = nil,
    nextAttemptId = 1
}

local longsword_iai_reward_action_types = {
    ["snow.player.fsm.PlayerFsm2ActionLongSwordSuccessIaiCounter"] = true,
    ["snow.player.fsm.PlayerFsm2ActionLongSwordSetCounterSuccessMotionSpeed"] = true,
    ["snow.player.fsm.PlayerFsm2ActionLongSwordSubGauge"] = true,
    ["snow.player.fsm.PlayerFsm2ActionLongSwordAddLv"] = true
}

local longsword_max_gauge_level = 3

local function safe_call(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end

    return nil
end

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

local function get_master_player_game_object()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    return master_player:call("get_GameObject")
end

local function get_behavior_tree()
    local player_game_object = get_master_player_game_object()
    if not player_game_object then
        return nil
    end

    return player_game_object:call("getComponent(System.Type)", sdk.typeof("via.behaviortree.BehaviorTree"))
end

-- 从玩家对象一路拿到当前正在使用的动作树。
local function get_tree_object()
    local player_game_object = get_master_player_game_object()
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

local function get_motion_id()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    return safe_call(function()
        return master_player:call("getMotionID_Layer(System.Int32)", 0)
    end)
end

local function get_motion_frame()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    return safe_call(function()
        return math.floor(master_player:call("getMotionNowFrame_Layer(System.Int32)", 0))
    end)
end

local function get_current_node_id()
    local behavior_tree = get_behavior_tree()
    if not behavior_tree then
        return nil
    end

    return safe_call(function()
        return behavior_tree:call("getCurrentNodeID", 0)
    end)
end

local function get_node_name_by_id(node_id)
    local tree = get_tree_object()
    if not tree or not node_id then
        return nil
    end

    local node = safe_call(function()
        return tree:get_node_by_id(node_id)
    end)
    if not node then
        return nil
    end

    return safe_call(function()
        return node:get_full_name()
    end)
end

local function get_current_node_name()
    return get_node_name_by_id(get_current_node_id())
end

local function get_current_node_action_type_names()
    local tree = get_tree_object()
    local node_id = get_current_node_id()
    if not tree or not node_id then
        return {}
    end

    local node = safe_call(function()
        return tree:get_node_by_id(node_id)
    end)
    if not node then
        return {}
    end

    local node_data = safe_call(function()
        return node:get_data()
    end)
    if not node_data then
        return {}
    end

    local node_actions = safe_call(function()
        return node_data:get_actions()
    end)
    if not node_actions then
        return {}
    end

    local actions = safe_call(function()
        return tree:get_actions()
    end)
    if not actions then
        return {}
    end

    local result = {}
    for i = 0, node_actions:size() - 1 do
        local action_index = tonumber(node_actions[i])
        local action_obj = actions[action_index]
        if action_obj then
            local type_name = safe_call(function()
                return action_obj:get_type_definition():get_full_name()
            end)
            if type_name then
                table.insert(result, type_name)
            end
        end
    end

    return result
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

-- 某些招式在动作树里会拆成多个方向、多个派生版本。
-- 例如弓的闪身箭斩，会分别挂在前后左右以及 MR 对应节点上。
-- 这里统一把它们整理成 actionIndex 列表，方便 UI 只展示成一个招式。
local function get_move_action_indices(move_def)
    if type(move_def.actionIndices) == "table" then
        return move_def.actionIndices
    end

    if move_def.actionIndex ~= nil then
        return { move_def.actionIndex }
    end

    return {}
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

    if move_def.rewardSimulationMode ~= nil and move_state.rewardSimulationEnabled == nil then
        move_state.rewardSimulationEnabled = move_def.rewardSimulationEnabledByDefault or false
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
    local function collect_from_scope(scope_weapon_type)
        local weapon_def = weapon_by_type[scope_weapon_type]
        if weapon_def == nil then
            return
        end

        local weapon_settings = get_weapon_settings(scope_weapon_type)

        for _, move_def in ipairs(weapon_def.moves) do
            local move_state = weapon_settings[move_def.id]
            if move_state and move_state.enabled then
                for _, action_index in ipairs(get_move_action_indices(move_def)) do
                    desired[action_index] = {
                        moveDef = move_def,
                        moveState = move_state
                    }
                end
            end
        end
    end

    collect_from_scope(general_weapon_type)
    collect_from_scope(active_weapon_type)

    return desired
end

-- 把单个招式配置恢复到预设表里的默认值。
local function reset_move_state(move_def, move_state)
    move_state.enabled = move_def.enabledByDefault or false
    move_state.value = move_def.default

    if move_def.rewardSimulationMode ~= nil then
        move_state.rewardSimulationEnabled = move_def.rewardSimulationEnabledByDefault or false
    end
end

local function find_move_definition(weapon_type, move_id)
    local weapon_def = weapon_by_type[weapon_type]
    if not weapon_def then
        return nil
    end

    for _, move_def in ipairs(weapon_def.moves) do
        if move_def.id == move_id then
            return move_def
        end
    end

    return nil
end

local function get_longsword_iai_reward_config()
    local move_def = find_move_definition(2, "iai_spirit_slash_counter")
    if not move_def then
        return nil
    end

    local move_state = ensure_move_state(2, move_def)
    if not settings.modEnabled or not move_state.enabled or not move_state.rewardSimulationEnabled then
        return nil
    end

    return {
        moveDef = move_def,
        moveState = move_state
    }
end

local function get_longsword_gauge_level()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    return safe_call(function()
        return master_player:call("get_LongSwordGaugeLv")
    end)
end

local function set_longsword_gauge_level(value)
    local master_player = get_master_player()
    if not master_player then
        return false
    end

    local result = safe_call(function()
        return master_player:call("set_LongSwordGaugeLv", value)
    end)

    return result ~= nil
end

local function get_longsword_gauge()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    return safe_call(function()
        return master_player:get_field("_LongSwordGauge")
    end)
end

local function set_longsword_gauge(value)
    local master_player = get_master_player()
    if not master_player then
        return false
    end

    local ok = safe_call(function()
        master_player:set_field("_LongSwordGauge", value)
        return true
    end)

    return ok == true
end

local function get_longsword_gauge_level_timer()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    return safe_call(function()
        return master_player:get_field("_LongSwordGaugeLvTimer")
    end)
end

local function set_longsword_gauge_level_timer(value)
    local master_player = get_master_player()
    if not master_player then
        return false
    end

    local ok = safe_call(function()
        master_player:set_field("_LongSwordGaugeLvTimer", value)
        return true
    end)

    return ok == true
end

local function get_longsword_gauge_level_time()
    local master_player = get_master_player()
    if not master_player then
        return nil
    end

    return safe_call(function()
        return master_player:get_field("_LongSwordGaugeLvTime")
    end)
end

local function clear_longsword_iai_runtime()
    runtime_state.activeLongSwordIaiAttempt = nil
    runtime_state.pendingLongSwordIaiReward = nil
    runtime_state.lastProcessedDamageTick = nil
    runtime_state.lastForcedSuccessAt = nil
    runtime_state.lastJumpTargetNodeId = nil
end

local function begin_longsword_iai_attempt(move_def, move_state, motion_frame)
    runtime_state.activeLongSwordIaiAttempt = {
        attemptId = runtime_state.nextAttemptId,
        motionId = move_def.resultMotionId,
        resultWeaponType = move_def.resultWeaponType,
        successNodeId = move_def.successNodeId,
        mrSuccessNodeId = move_def.mrSuccessNodeId,
        windowStart = 0,
        windowEnd = move_state.value,
        consumed = false,
        rewardResolved = false,
        manualFallbackReward = false,
        lastMotionFrame = motion_frame,
        createdMotionFrame = motion_frame,
        startedNodeId = get_current_node_id(),
        startedNodeName = get_current_node_name()
    }
    runtime_state.nextAttemptId = runtime_state.nextAttemptId + 1
end

local function is_hostile_damage_owner_type(owner_type)
    return owner_type == 0 or owner_type == 1 or owner_type == 2
end

local function try_jump_to_node(node_id)
    local behavior_tree = get_behavior_tree()
    if not behavior_tree or not node_id then
        return false
    end

    local ok = safe_call(function()
        behavior_tree:call(
            "setCurrentNode(System.UInt64, System.UInt32, via.behaviortree.SetNodeInfo)",
            node_id,
            nil,
            nil
        )
        return true
    end)

    return ok == true
end

local function queue_longsword_iai_reward(owner_type)
    local attempt = runtime_state.activeLongSwordIaiAttempt
    if not attempt or attempt.consumed then
        return false
    end

    attempt.consumed = true

    local motion_frame = get_motion_frame() or -1
    runtime_state.lastProcessedDamageTick = tostring(attempt.attemptId) .. ":" .. tostring(motion_frame) .. ":" .. tostring(owner_type)
    runtime_state.pendingLongSwordIaiReward = {
        attemptId = attempt.attemptId,
        ownerType = owner_type,
        gaugeLvBefore = get_longsword_gauge_level(),
        gaugeBefore = get_longsword_gauge(),
        validationFramesRemaining = 2,
        jumpAttempted = false,
        jumpTargetNodeId = nil,
        stagedBaseRewardJumpAttempted = false,
        stagedBaseRewardJumpSucceeded = false,
        attackSideObserved = false,
        attackSideNodeId = nil,
        attackSideMotionId = nil,
        successSignalSeen = false,
        manualFallbackReward = false
    }

    return true
end

local function mark_longsword_iai_reward_resolved(manual_fallback)
    local pending = runtime_state.pendingLongSwordIaiReward
    if pending then
        pending.successSignalSeen = true
        pending.manualFallbackReward = manual_fallback == true
    end

    local attempt = runtime_state.activeLongSwordIaiAttempt
    if attempt and pending and attempt.attemptId == pending.attemptId then
        attempt.rewardResolved = true
        attempt.manualFallbackReward = manual_fallback == true
    end

    runtime_state.pendingLongSwordIaiReward = nil
end

local function apply_manual_longsword_iai_reward(pending)
    if not pending then
        return false
    end

    local gauge_level_before = get_longsword_gauge_level()
    if gauge_level_before ~= nil and gauge_level_before < longsword_max_gauge_level then
        set_longsword_gauge_level(gauge_level_before + 1)
    end

    local current_timer = get_longsword_gauge_level_timer()
    local base_timer = get_longsword_gauge_level_time()
    local target_timer = base_timer or current_timer or 300.0
    if type(target_timer) ~= "number" or target_timer < 1.0 then
        target_timer = 300.0
    end
    set_longsword_gauge_level_timer(target_timer)

    local current_gauge = get_longsword_gauge()
    local gauge_floor = pending.gaugeBefore
    if type(current_gauge) == "number" and type(gauge_floor) == "number" and current_gauge < gauge_floor then
        set_longsword_gauge(gauge_floor)
    end

    mark_longsword_iai_reward_resolved(true)
    return true
end

local function has_longsword_iai_success_signal(pending, move_def)
    local current_node_id = get_current_node_id()
    if current_node_id == move_def.successNodeId then
        return true
    end

    for _, type_name in ipairs(get_current_node_action_type_names()) do
        if longsword_iai_reward_action_types[type_name] then
            return true
        end
    end

    local current_gauge_lv = get_longsword_gauge_level()
    if pending.gaugeLvBefore ~= nil and current_gauge_lv ~= nil and current_gauge_lv > pending.gaugeLvBefore then
        return true
    end

    return false
end

local function process_pending_longsword_iai_reward()
    local pending = runtime_state.pendingLongSwordIaiReward
    if not pending then
        return
    end

    local config = get_longsword_iai_reward_config()
    if not config then
        clear_longsword_iai_runtime()
        return
    end

    if not pending.jumpAttempted then
        local jumped = false

        if try_jump_to_node(config.moveDef.mrSuccessNodeId) then
            pending.jumpTargetNodeId = config.moveDef.mrSuccessNodeId
            jumped = true
        elseif try_jump_to_node(config.moveDef.successNodeId) then
            pending.jumpTargetNodeId = config.moveDef.successNodeId
            jumped = true
        end

        pending.jumpAttempted = true
        runtime_state.lastForcedSuccessAt = os.clock()
        runtime_state.lastJumpTargetNodeId = pending.jumpTargetNodeId

        if not jumped then
            apply_manual_longsword_iai_reward(pending)
        end

        return
    end

    local current_node_id = get_current_node_id()

    -- MR 成功分支里有 SuccessIaiCounter，但升刃和成功伤害挂在基础 success 节点。
    -- 所以这里补做第二段跳转，把奖励链尽量补完整。
    if not pending.stagedBaseRewardJumpAttempted and current_node_id == config.moveDef.mrSuccessNodeId then
        pending.stagedBaseRewardJumpAttempted = true

        if try_jump_to_node(config.moveDef.successNodeId) then
            pending.stagedBaseRewardJumpSucceeded = true
            pending.jumpTargetNodeId = config.moveDef.successNodeId
            runtime_state.lastJumpTargetNodeId = config.moveDef.successNodeId
            pending.validationFramesRemaining = math.max(pending.validationFramesRemaining, 2)
            return
        end
    end

    if has_longsword_iai_success_signal(pending, config.moveDef) then
        mark_longsword_iai_reward_resolved(false)
        return
    end

    pending.validationFramesRemaining = pending.validationFramesRemaining - 1
    if pending.validationFramesRemaining <= 0 then
        apply_manual_longsword_iai_reward(pending)
    end
end

local function refresh_longsword_iai_runtime()
    local weapon_type = get_player_weapon_type()
    local motion_id = get_motion_id()
    local motion_frame = get_motion_frame()

    runtime_state.lastKnownWeaponType = weapon_type
    runtime_state.lastKnownMotionId = motion_id
    runtime_state.lastKnownMotionFrame = motion_frame

    local config = get_longsword_iai_reward_config()
    if not config or weapon_type ~= config.moveDef.resultWeaponType then
        clear_longsword_iai_runtime()
        return
    end

    if motion_id == nil or motion_frame == nil then
        clear_longsword_iai_runtime()
        return
    end

    local attempt = runtime_state.activeLongSwordIaiAttempt

    if motion_id == config.moveDef.resultMotionId then
        local should_begin_new_attempt = attempt == nil
            or attempt.motionId ~= motion_id
            or motion_frame < (attempt.lastMotionFrame or 0)

        if should_begin_new_attempt then
            begin_longsword_iai_attempt(config.moveDef, config.moveState, motion_frame)
            attempt = runtime_state.activeLongSwordIaiAttempt
        end

        attempt.windowEnd = config.moveState.value
        attempt.lastMotionFrame = motion_frame
    else
        runtime_state.activeLongSwordIaiAttempt = nil
    end
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
    refresh_longsword_iai_runtime()
    process_pending_longsword_iai_reward()
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

            if move_def.rewardSimulationMode ~= nil then
                toggle, move_state.rewardSimulationEnabled = imgui.checkbox(
                    "模拟居合成功奖励##move_reward_enabled_" .. weapon_def.weaponType .. "_" .. move_def.id,
                    move_state.rewardSimulationEnabled
                )
                changed = changed or toggle

                imgui.text("强制走成功分支（实验）")
                imgui.text("风险提示：可能与其他太刀反击/派生 mod 冲突。")
                imgui.text("当前只对太刀居合气刃斩生效。")
            end

            if imgui.button("恢复默认##move_reset_" .. weapon_def.weaponType .. "_" .. move_def.id) then
                reset_move_state(move_def, move_state)
                changed = true
            end

            local action_indices = get_move_action_indices(move_def)
            imgui.text("Action Indices: " .. table.concat(action_indices, ", "))

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

sdk.hook(
    sdk.find_type_definition("snow.player.PlayerQuestBase"):get_method("checkCalcDamage_DamageSide"),
    function(args)
        local storage = thread.get_hook_storage()
        storage["customGpFramesPlayer"] = sdk.to_managed_object(args[2])

        local hit_info = sdk.to_managed_object(args[3])
        storage["customGpFramesHitInfo"] = hit_info
        storage["customGpFramesDamageData"] = hit_info and hit_info:get_AttackData() or nil
    end,
    function(retval)
        local storage = thread.get_hook_storage()
        local player = storage["customGpFramesPlayer"]
        if not player or not player:isMasterPlayer() then
            return retval
        end

        local config = get_longsword_iai_reward_config()
        local attempt = runtime_state.activeLongSwordIaiAttempt
        if not config or not attempt or attempt.consumed or runtime_state.pendingLongSwordIaiReward ~= nil then
            return retval
        end

        local owner_type = safe_call(function()
            return storage["customGpFramesDamageData"]:get_OwnerType()
        end)
        if owner_type == nil or not is_hostile_damage_owner_type(owner_type) then
            return retval
        end

        local weapon_type = get_player_weapon_type()
        local motion_id = get_motion_id()
        local motion_frame = get_motion_frame()
        if weapon_type ~= config.moveDef.resultWeaponType or motion_id ~= config.moveDef.resultMotionId or motion_frame == nil then
            return retval
        end

        if motion_frame < 0 or motion_frame > config.moveState.value then
            return retval
        end

        if queue_longsword_iai_reward(owner_type) then
            return sdk.to_ptr(2)
        end

        return retval
    end
)

sdk.hook(
    sdk.find_type_definition("snow.player.PlayerQuestBase"):get_method("afterCalcDamage_AttackSide"),
    function(args)
        local player = sdk.to_managed_object(args[2])
        if not player or not player:isMasterPlayer() then
            return
        end

        local pending = runtime_state.pendingLongSwordIaiReward
        if not pending then
            return
        end

        pending.attackSideObserved = true
        pending.attackSideNodeId = get_current_node_id()
        pending.attackSideMotionId = get_motion_id()
    end
)

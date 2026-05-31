-- 这里是“武器 -> 已支持招式”的预设表。
-- 主脚本只负责读这份定义，然后自动生成 UI 和运行时覆盖逻辑。
-- 后续要支持更多武器时，优先在这里补数据，不要先改主逻辑。

local ordered_weapons = {
    {
        weaponType = 2,
        weaponName = "太刀",
        moves = {
            {
                id = "iai_spirit_slash_counter",
                label = "居合气刃斩",
                actionIndex = 9250,
                valueMode = "end_frame",
                rewardSimulationMode = "longsword_iai_full",
                rewardSimulationEnabledByDefault = true,
                rewardSimulationAlwaysOn = true,
                successNodeId = 2004603551,
                mrSuccessNodeId = 3569005589,
                resultMotionId = 155,
                resultWeaponType = 2,
                sliderLabel = "GP结束帧",
                min = 0,
                max = 120,
                default = 18,
                enabledByDefault = false,
                modeHint = "直接覆盖 PlayerFsm2ActionSeeThroughAttack 的 _EndFrame",
                description = "当前已确认条目：来自 longsword dump 与 Endless Longsword 参考实现，对应居合气刃斩成功窗口。默认原值为 18。启用后会额外开启居合成功奖励模拟。"
            },
            {
                id = "special_sheathe_auto_iai",
                label = "特殊纳刀自动居合",
                featureOnly = true,
                successNodeId = 2004603551,
                mrSuccessNodeId = 3569005589,
                specialSheatheReadyNodeId = 1498247531,
                specialSheatheReadyNodeName = "atk.atk151.atk_152",
                autoIaiTargetNodeId = 3716128725,
                autoIaiTargetNodeName = "atk.atk151.atk_155",
                autoIaiTargetMotionId = 155,
                resultMotionId = 155,
                resultWeaponType = 2,
                default = 18,
                enabledByDefault = false,
                modeHint = "在特殊纳刀待机节点受击时自动跳到居合气刃斩",
                description = "独立于居合气刃斩 GP 改帧。开启后，在 atk.atk151.atk_152 待机时受击会自动推进到 atk.atk151.atk_155，并复用居合成功奖励模拟链。"
            },
            {
                id = "free_state_auto_foresight",
                label = "自由态自动见切",
                featureOnly = true,
                autoForesightMode = "longsword_free_state_auto_foresight",
                autoForesightTargetNodeId = 532382550,
                autoForesightTargetNodeName = "atk.atk_147.atk_147",
                autoForesightSuccessRouteNodeId = 2839200054,
                autoForesightSuccessRouteNodeName = "atk.atk_147.atk_147_end",
                autoForesightSuccessRouteStartFrame = 38,
                autoForesightSuccessRouteEndFrame = 52,
                autoForesightSuccessRouteFallbackFrames = 24,
                triggerModeLabel = "触发范围",
                triggerModeDefault = "free_state",
                triggerModeOptions = {
                    {
                        id = "free_state",
                        label = "自由态"
                    },
                    {
                        id = "aggressive",
                        label = "全动作"
                    }
                },
                resultWeaponType = 2,
                enabledByDefault = false,
                modeHint = "自由态受击时自动跳到见切斩",
                description = "默认只在自由态触发；也可切到全动作模式，在普通动作受击时更激进地自动见切，但会保护居合、神威居合、水月、刚气刃斩和手动见切链。触发后会尝试进入原版见切成功路线，不手动补数值奖励。"
            },
            {
                id = "harvest_moon_custom_params",
                label = "圆月参数 [测试中]",
                featureOnly = true,
                shellParamMode = "longsword_harvest_moon",
                shellTypeName = "snow.shell.LongSwordShell010",
                shellMainUserDataField = "_userData",
                shellMoveParamField = "_moveParam",
                debugPrintOption = true,
                debugPrintLabel = "调试打印",
                debugPrintEnabledByDefault = false,
                launchNodeId = 3736120076,
                launchNodeName = "atk.WireReplaceF_MR.plw_LongSword_100_160",
                visualScaleActionIndex = 9531,
                visualScaleMultiplierParamId = "rangeMultiplier",
                visualScaleFields = {
                    "_BaseScale",
                    "_CurrentScale"
                },
                shellParamValues = {
                    {
                        id = "lifeTimeMultiplier",
                        label = "持续时间倍率",
                        field = "_lifeTime",
                        target = "move_param",
                        default = 1.0,
                        min = 0.1,
                        max = 5.0,
                        format = "%.2f"
                    },
                    {
                        id = "rangeMultiplier",
                        label = "水平范围倍率",
                        field = "_Range",
                        target = "move_param",
                        default = 1.0,
                        min = 0.1,
                        max = 5.0,
                        format = "%.2f"
                    },
                    {
                        id = "rangeYMultiplier",
                        label = "垂直范围倍率",
                        field = "_RangeY",
                        target = "move_param",
                        default = 1.0,
                        min = 0.1,
                        max = 5.0,
                        format = "%.2f"
                    },
                    {
                        id = "warningRangeMultiplier",
                        label = "警告圈范围倍率",
                        field = "_WarningRange",
                        target = "move_param",
                        default = 1.0,
                        min = 0.1,
                        max = 5.0,
                        format = "%.2f"
                    },
                    {
                        id = "shellLifeTimeMultiplier",
                        label = "实例存活时间倍率",
                        field = "_lifeTime",
                        target = "shell",
                        default = 1.0,
                        min = 0.1,
                        max = 5.0,
                        format = "%.2f"
                    }
                },
                enabledByDefault = false,
                modeHint = "修改圆月 LongSwordShell010 的持续时间和范围倍率",
                description = "测试中：运行时捕获圆月本体 LongSwordShell010，并按倍率修改 _lifeTime、_Range、_RangeY、_WarningRange。视觉圆圈同步仍在验证中；可开启调试打印查看圆月启动、action 和 shell 参数快照。默认倍率 1.00，不直接写死原版数值。"
            }
        }
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
                autoGuardMode = "lance_auto_instant_block",
                autoGuardEnabledByDefault = false,
                autoGuardTargetNodeId = 349958783,
                autoOptionLabel = "自动精准防御",
                sliderLabel = "GP结束帧",
                min = 0,
                max = 120,
                default = 32,
                enabledByDefault = false,
                modeHint = "直接覆盖 _EndFrame",
                description = "当前示例来自参考项目 ComboLance：这里把长枪精准防御的 action 结束帧暴露成滑条。"
            }
        }
    },
    {
        weaponType = 13,
        weaponName = "弓",
        moves = {
            {
                id = "dodgebolt",
                label = "闪身箭斩",
                actionIndices = {
                    9234,
                    9251,
                    9269,
                    9287,
                    10615,
                    10632,
                    10649,
                    10666
                },
                valueMode = "end_frame",
                autoDodgeMode = "bow_auto_dodgebolt",
                autoDodgeEnabledByDefault = false,
                autoDodgeDirectionDefault = "back",
                autoDodgeDirections = {
                    {
                        id = "back",
                        label = "后",
                        nodeId = 3858837153
                    },
                    {
                        id = "front",
                        label = "前",
                        nodeId = 1762771780
                    },
                    {
                        id = "left",
                        label = "左",
                        nodeId = 481533731
                    },
                    {
                        id = "right",
                        label = "右",
                        nodeId = 1336556275
                    }
                },
                autoDodgeTargetNodeId = 3858837153,
                autoOptionLabel = "自动闪身",
                sliderLabel = "GP结束帧",
                min = 0,
                max = 120,
                default = 10,
                enabledByDefault = false,
                modeHint = "直接覆盖 PlayerFsm2ActionDamageReflex 的 _EndFrame",
                description = "弓的闪身箭斩成功判定当前确认走 DamageReflexSuccess 分支。这里统一覆盖普通版前后左右，以及 MR 的 ESA 对应主节点里的 DamageReflex 结束帧。默认原值为 10。"
            }
        }
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

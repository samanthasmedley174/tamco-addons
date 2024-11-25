-- -----------------------------------------------------------------------------
--  LuiExtended                                                               --
--  Distributed under The MIT License (MIT) (see LICENSE file)                --
-- -----------------------------------------------------------------------------

--- @class (partial) LuiExtended
local LUIE = LUIE

-- Unit Frames namespace
--- @class (partial) UnitFrames
local UnitFrames = LUIE.UnitFrames

-- Update format for labels on CustomFrames
---
--- @param menu boolean
function UnitFrames.CustomFramesFormatLabels(menu)
    -- Format Player Labels
    if UnitFrames.CustomFrames["player"] then
        for _, powerType in pairs(
            {
                COMBAT_MECHANIC_FLAGS_HEALTH,
                COMBAT_MECHANIC_FLAGS_MAGICKA,
                COMBAT_MECHANIC_FLAGS_STAMINA,
            }) do
            if UnitFrames.CustomFrames["player"][powerType] then
                local frame = UnitFrames.CustomFrames["player"][powerType]
                local isCenter = UnitFrames.SV.BarAlignCenterLabelPlayer

                if frame.labelOne then
                    UnitFrames.FormatLabelAlignment(
                        frame.labelOne,
                        isCenter,
                        UnitFrames.SV.CustomFormatCenterLabel,
                        UnitFrames.SV.CustomFormatOnePT,
                        frame.backdrop
                    )
                end

                if frame.labelTwo then
                    UnitFrames.FormatSecondaryLabel(
                        frame.labelTwo,
                        isCenter,
                        UnitFrames.SV.CustomFormatTwoPT
                    )
                end
            end
        end
    end
    if menu and DoesUnitExist("player") then
        UnitFrames.ReloadValues("player")
    end

    -- Format Target Labels
    if UnitFrames.CustomFrames["reticleover"] and UnitFrames.CustomFrames["reticleover"][COMBAT_MECHANIC_FLAGS_HEALTH] then
        local frame = UnitFrames.CustomFrames["reticleover"][COMBAT_MECHANIC_FLAGS_HEALTH]
        local isCenter = UnitFrames.SV.BarAlignCenterLabelTarget

        if frame.labelOne then
            UnitFrames.FormatLabelAlignment(
                frame.labelOne,
                isCenter,
                UnitFrames.SV.CustomFormatCenterLabel,
                UnitFrames.SV.CustomFormatOnePT,
                frame.backdrop
            )
        end

        if frame.labelTwo then
            UnitFrames.FormatSecondaryLabel(
                frame.labelTwo,
                isCenter,
                UnitFrames.SV.CustomFormatTwoPT
            )
        end
    end
    if menu and DoesUnitExist("reticleover") then
        UnitFrames.ReloadValues("reticleover")
    end
    -- Format Companion Labels
    if UnitFrames.CustomFrames["companion"] and
    UnitFrames.CustomFrames["companion"][COMBAT_MECHANIC_FLAGS_HEALTH] and
    UnitFrames.CustomFrames["companion"][COMBAT_MECHANIC_FLAGS_HEALTH].label then
        UnitFrames.FormatSimpleLabel(
            UnitFrames.CustomFrames["companion"][COMBAT_MECHANIC_FLAGS_HEALTH].label,
            UnitFrames.SV.CustomFormatCompanion
        )
    end
    if menu and DoesUnitExist("companion") then
        UnitFrames.ReloadValues("companion")
    end
    -- Format Small Group Labels
    for i = 1, 4 do
        local unitTag = "SmallGroup" .. i
        if UnitFrames.CustomFrames[unitTag] and
        UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH] then
            local frame = UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH]

            if frame.labelOne then
                UnitFrames.FormatSimpleLabel(frame.labelOne, UnitFrames.SV.CustomFormatOneGroup)
            end

            if frame.labelTwo then
                UnitFrames.FormatSimpleLabel(frame.labelTwo, UnitFrames.SV.CustomFormatTwoGroup)
            end
        end
        if menu and DoesUnitExist(unitTag) then
            UnitFrames.ReloadValues(unitTag)
        end
    end

    -- Format Raid Labels
    for i = 1, 12 do
        local unitTag = "RaidGroup" .. i
        if UnitFrames.CustomFrames[unitTag] and
        UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH] and
        UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH].label then
            UnitFrames.FormatSimpleLabel(
                UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH].label,
                UnitFrames.SV.CustomFormatRaid
            )
        end
        local baseTag = GetGroupUnitTagByIndex(i)
        if menu and DoesUnitExist(baseTag) then
            UnitFrames.ReloadValues(baseTag)
        end
    end

    -- Format Boss Labels
    for i = BOSS_RANK_ITERATION_BEGIN, BOSS_RANK_ITERATION_END do
        local unitTag = "boss" .. i
        if UnitFrames.CustomFrames[unitTag] and
        UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH] and
        UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH].label then
            UnitFrames.FormatSimpleLabel(
                UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH].label,
                UnitFrames.SV.CustomFormatBoss
            )
        end
        if menu and DoesUnitExist(unitTag) then
            UnitFrames.ReloadValues(unitTag)
        end
    end

    -- Format Pet Labels
    for i = 1, 7 do
        local unitTag = "PetGroup" .. i
        if UnitFrames.CustomFrames[unitTag] and
        UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH] and
        UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH].label then
            UnitFrames.FormatSimpleLabel(
                UnitFrames.CustomFrames[unitTag][COMBAT_MECHANIC_FLAGS_HEALTH].label,
                UnitFrames.SV.CustomFormatPet
            )
        end
        local baseTag = "playerpet" .. i
        if menu and DoesUnitExist(baseTag) then
            UnitFrames.ReloadValues(baseTag)
        end
    end
end

-- ArcTech_Data.lua
local ArcTech = ArcTech

ArcTech.house_owner = "@Scribe Rob"
ArcTech.guild_id = 381665

ArcTech.houses = {
	main = { label = "|cffff00Main - Kthendral Deep Mines|r", owner = ArcTech.house_owner, id = 113 },
	pvp = { label = "|cffff00PvP - Elinhir Arena|r", owner =ArcTech.house_owner, id = 66 },
	auction = { label = "|cffff00Auction - Theatre of the Ancestors|r", owner = ArcTech.house_owner, id = 119 },
}

ArcTech.Status_Colours = {
    standard = '|cc7cdbf',
    active = '|c568203',
    disabled = '|cff0000'
}

ArcTech.QR = { data = "https://discord.gg/hj2eWtra66", size = 240 }

ArcTech.Events = {
    monday = {},
    tuesday = {
        host = 'Scribe Rob',
        datetime = '1771934400',
        title = 'Necrom Dailies',
        description = 'Come on down and join us for a delve, world boss and bastion nymic, all out of the backgarden of Necrom :)'
    },
    wednesday = {},
    thursday = {
        host = 'Scribe Rob',
        datetime = '1772136000',
        title = 'Defender of Skyrim',
        description = 'We are Arcanists and what do we do best? Beam! So lets go beam some world bosses in Western Skyrim & Blackreach caverns, members who attend the full event in tabard will be eligible to play the random number game at the end of the event for a chance to win 25,000 gold'
    },
    friday = {},
    saturday = {},
    sunday = {},
}

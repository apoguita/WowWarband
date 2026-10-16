/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef ACORE_DBCSTORES_H
#define ACORE_DBCSTORES_H

#include "Common.h"
#include "DBCStore.h"
#include "DBCStructure.h"
#include <list>
#include <unordered_map>
#include <unordered_set>

typedef std::list<uint32> SimpleFactionsList;

SimpleFactionsList const* GetFactionTeamList(uint32 faction);

char const* GetPetName(uint32 petfamily, uint32 dbclang);
uint32 GetTalentSpellCost(uint32 spellId);
TalentSpellPos const* GetTalentSpellPos(uint32 spellId);

WMOAreaTableEntry const* GetWMOAreaTableEntryByTripple(int32 rootid, int32 adtid, int32 groupid);

uint32 GetVirtualMapForMapAndZone(uint32 mapid, uint32 zoneId);

enum ContentLevels : uint8
{
    CONTENT_1_60 = 0,
    CONTENT_61_70,
    CONTENT_71_80
};
ContentLevels GetContentLevelsForMapAndZone(uint32 mapid, uint32 zoneId);

void Zone2MapCoordinates(float& x, float& y, uint32 zone);
void Map2ZoneCoordinates(float& x, float& y, uint32 zone);

typedef std::map<uint32/*pair32(map, diff)*/, MapDifficulty> MapDifficultyMap;
MapDifficulty const* GetMapDifficultyData(uint32 mapId, Difficulty difficulty);
MapDifficulty const* GetDownscaledMapDifficultyData(uint32 mapId, Difficulty& difficulty);

bool IsSharedDifficultyMap(uint32 mapid);

uint32 const* /*[MAX_TALENT_TABS]*/ GetTalentTabPages(uint8 cls);

uint32 GetLiquidFlags(uint32 liquidType);

PvPDifficultyEntry const* GetBattlegroundBracketByLevel(uint32 mapid, uint32 level);
PvPDifficultyEntry const* GetBattlegroundBracketById(uint32 mapid, BattlegroundBracketId id);

CharStartOutfitEntry const* GetCharStartOutfitEntry(uint8 race, uint8 class_, uint8 gender);

LFGDungeonEntry const* GetLFGDungeon(uint32 mapId, Difficulty difficulty);
LFGDungeonEntry const* GetZoneLFGDungeonEntry(std::string const& zoneName, LocaleConstant locale);

uint32 GetDefaultMapLight(uint32 mapId);

typedef std::unordered_multimap<uint32, SkillRaceClassInfoEntry const*> SkillRaceClassInfoMap;
typedef std::pair<SkillRaceClassInfoMap::iterator, SkillRaceClassInfoMap::iterator> SkillRaceClassInfoBounds;
SkillRaceClassInfoEntry const* GetSkillRaceClassInfo(uint32 skill, uint8 race, uint8 class_);

EmotesTextSoundEntry const* FindTextSoundEmoteFor(uint32 emote, uint32 race, uint32 gender);
typedef std::unordered_map<uint32 /* SkillLine */, std::vector<SkillLineAbilityEntry const*> > SkillLineAbilityIndexBySkillLine;
std::vector<SkillLineAbilityEntry const*> const& GetSkillLineAbilitiesBySkillLine(uint32 skillLine);

extern AC_GAME_API DBCStorage <AchievementEntry>             sAchievementStore;
extern AC_GAME_API DBCStorage <AchievementCriteriaEntry>     sAchievementCriteriaStore;
extern AC_GAME_API DBCStorage <AchievementCategoryEntry>     sAchievementCategoryStore;
extern AC_GAME_API DBCStorage <AreaTableEntry>               sAreaTableStore;
extern AC_GAME_API DBCStorage <AreaGroupEntry>               sAreaGroupStore;
extern AC_GAME_API DBCStorage <AreaPOIEntry>                 sAreaPOIStore;
extern AC_GAME_API DBCStorage <AuctionHouseEntry>            sAuctionHouseStore;
extern AC_GAME_API DBCStorage <BankBagSlotPricesEntry>       sBankBagSlotPricesStore;
extern AC_GAME_API DBCStorage <BarberShopStyleEntry>         sBarberShopStyleStore;
extern AC_GAME_API DBCStorage <BattlemasterListEntry>        sBattlemasterListStore;
extern AC_GAME_API DBCStorage <ChatChannelsEntry>            sChatChannelsStore;
extern AC_GAME_API DBCStorage <CharStartOutfitEntry>         sCharStartOutfitStore;
extern AC_GAME_API DBCStorage <CharSectionsEntry>            sCharSectionsStore;
extern AC_GAME_API DBCStorage <CharTitlesEntry>              sCharTitlesStore;
extern AC_GAME_API DBCStorage <ChrClassesEntry>              sChrClassesStore;
extern AC_GAME_API DBCStorage <ChrRacesEntry>                sChrRacesStore;
extern AC_GAME_API DBCStorage <CinematicCameraEntry>         sCinematicCameraStore;
extern AC_GAME_API DBCStorage <CinematicSequencesEntry>      sCinematicSequencesStore;
extern AC_GAME_API DBCStorage <CreatureDisplayInfoEntry>     sCreatureDisplayInfoStore;
extern AC_GAME_API DBCStorage <CreatureDisplayInfoExtraEntry> sCreatureDisplayInfoExtraStore;
extern AC_GAME_API DBCStorage <CreatureFamilyEntry>          sCreatureFamilyStore;
extern AC_GAME_API DBCStorage <CreatureModelDataEntry>       sCreatureModelDataStore;
extern AC_GAME_API DBCStorage <CreatureSpellDataEntry>       sCreatureSpellDataStore;
extern AC_GAME_API DBCStorage <CreatureTypeEntry>            sCreatureTypeStore;
extern AC_GAME_API DBCStorage <CurrencyTypesEntry>           sCurrencyTypesStore;
extern AC_GAME_API DBCStorage <DestructibleModelDataEntry>   sDestructibleModelDataStore;
extern AC_GAME_API DBCStorage <DungeonEncounterEntry>        sDungeonEncounterStore;
extern AC_GAME_API DBCStorage <DurabilityCostsEntry>         sDurabilityCostsStore;
extern AC_GAME_API DBCStorage <DurabilityQualityEntry>       sDurabilityQualityStore;
extern AC_GAME_API DBCStorage <EmotesEntry>                  sEmotesStore;
extern AC_GAME_API DBCStorage <EmotesTextEntry>              sEmotesTextStore;
extern AC_GAME_API DBCStorage <EmotesTextSoundEntry>         sEmotesTextSoundStore;
extern AC_GAME_API DBCStorage <FactionEntry>                 sFactionStore;
extern AC_GAME_API DBCStorage <FactionTemplateEntry>         sFactionTemplateStore;
extern AC_GAME_API DBCStorage <GameObjectArtKitEntry>        sGameObjectArtKitStore;
extern AC_GAME_API DBCStorage <GameObjectDisplayInfoEntry>   sGameObjectDisplayInfoStore;
extern AC_GAME_API DBCStorage <GemPropertiesEntry>           sGemPropertiesStore;
extern AC_GAME_API DBCStorage <GlyphPropertiesEntry>         sGlyphPropertiesStore;
extern AC_GAME_API DBCStorage <GlyphSlotEntry>               sGlyphSlotStore;

extern AC_GAME_API DBCStorage <GtBarberShopCostBaseEntry>    sGtBarberShopCostBaseStore;
extern AC_GAME_API DBCStorage <GtCombatRatingsEntry>         sGtCombatRatingsStore;
extern AC_GAME_API DBCStorage <GtChanceToMeleeCritBaseEntry> sGtChanceToMeleeCritBaseStore;
extern AC_GAME_API DBCStorage <GtChanceToMeleeCritEntry>     sGtChanceToMeleeCritStore;
extern AC_GAME_API DBCStorage <GtChanceToSpellCritBaseEntry> sGtChanceToSpellCritBaseStore;
extern AC_GAME_API DBCStorage <GtChanceToSpellCritEntry>     sGtChanceToSpellCritStore;
extern AC_GAME_API DBCStorage <GtNPCManaCostScalerEntry>     sGtNPCManaCostScalerStore;
extern AC_GAME_API DBCStorage <GtOCTClassCombatRatingScalarEntry> sGtOCTClassCombatRatingScalarStore;
extern AC_GAME_API DBCStorage <GtOCTRegenHPEntry>            sGtOCTRegenHPStore;
//extern DBCStorage <GtOCTRegenMPEntry>            sGtOCTRegenMPStore; -- not used currently
extern AC_GAME_API DBCStorage <GtRegenHPPerSptEntry>         sGtRegenHPPerSptStore;
extern AC_GAME_API DBCStorage <GtRegenMPPerSptEntry>         sGtRegenMPPerSptStore;
extern AC_GAME_API DBCStorage <HolidaysEntry>                sHolidaysStore;
extern AC_GAME_API DBCStorage <ItemBagFamilyEntry>           sItemBagFamilyStore;
extern AC_GAME_API DBCStorage <ItemEntry>                    sItemStore;
extern AC_GAME_API DBCStorage <ItemDisplayInfoEntry>         sItemDisplayInfoStore;
extern AC_GAME_API DBCStorage <ItemExtendedCostEntry>        sItemExtendedCostStore;
extern AC_GAME_API DBCStorage <ItemLimitCategoryEntry>       sItemLimitCategoryStore;
extern AC_GAME_API DBCStorage <ItemRandomPropertiesEntry>    sItemRandomPropertiesStore;
extern AC_GAME_API DBCStorage <ItemRandomSuffixEntry>        sItemRandomSuffixStore;
extern AC_GAME_API DBCStorage <ItemSetEntry>                 sItemSetStore;
extern AC_GAME_API DBCStorage <LFGDungeonEntry>              sLFGDungeonStore;
extern AC_GAME_API DBCStorage <LiquidTypeEntry>              sLiquidTypeStore;
extern AC_GAME_API DBCStorage <LockEntry>                    sLockStore;
extern AC_GAME_API DBCStorage <MailTemplateEntry>            sMailTemplateStore;
extern AC_GAME_API DBCStorage <MapEntry>                     sMapStore;
//extern DBCStorage <MapDifficultyEntry>           sMapDifficultyStore; -- use GetMapDifficultyData insteed
extern AC_GAME_API MapDifficultyMap                          sMapDifficultyMap;
extern AC_GAME_API DBCStorage <MovieEntry>                   sMovieStore;
extern AC_GAME_API DBCStorage <NamesReservedEntry>           sNamesReservedStore;
extern AC_GAME_API DBCStorage <NamesProfanityEntry>          sNamesProfanityStore;
extern AC_GAME_API DBCStorage <OverrideSpellDataEntry>       sOverrideSpellDataStore;
extern AC_GAME_API DBCStorage <PowerDisplayEntry>            sPowerDisplayStore;
extern AC_GAME_API DBCStorage <QuestSortEntry>               sQuestSortStore;
extern AC_GAME_API DBCStorage <QuestXPEntry>                 sQuestXPStore;
extern AC_GAME_API DBCStorage <QuestFactionRewEntry>         sQuestFactionRewardStore;
extern AC_GAME_API DBCStorage <RandomPropertiesPointsEntry>  sRandomPropertiesPointsStore;
extern AC_GAME_API DBCStorage <ScalingStatDistributionEntry> sScalingStatDistributionStore;
extern AC_GAME_API DBCStorage <ScalingStatValuesEntry>       sScalingStatValuesStore;
extern AC_GAME_API DBCStorage <SkillLineEntry>               sSkillLineStore;
extern AC_GAME_API DBCStorage <SkillLineAbilityEntry>        sSkillLineAbilityStore;
extern AC_GAME_API SkillLineAbilityIndexBySkillLine          sSkillLineAbilityIndexBySkillLine;
extern AC_GAME_API DBCStorage <SkillTiersEntry>              sSkillTiersStore;
extern AC_GAME_API DBCStorage <SoundEntriesEntry>            sSoundEntriesStore;
extern AC_GAME_API DBCStorage <SpellCastTimesEntry>          sSpellCastTimesStore;
extern AC_GAME_API DBCStorage <SpellCategoryEntry>           sSpellCategoryStore;
extern AC_GAME_API DBCStorage <SpellDifficultyEntry>         sSpellDifficultyStore;
extern AC_GAME_API DBCStorage <SpellDurationEntry>           sSpellDurationStore;
extern AC_GAME_API DBCStorage <SpellFocusObjectEntry>        sSpellFocusObjectStore;
extern AC_GAME_API DBCStorage <SpellItemEnchantmentEntry>    sSpellItemEnchantmentStore;
extern AC_GAME_API DBCStorage <SpellItemEnchantmentConditionEntry> sSpellItemEnchantmentConditionStore;
extern AC_GAME_API SpellCategoryStore                        sSpellsByCategoryStore;
extern AC_GAME_API PetFamilySpellsStore                      sPetFamilySpellsStore;
extern AC_GAME_API std::unordered_set<uint32>                sPetTalentSpells;
extern AC_GAME_API DBCStorage <SpellRadiusEntry>             sSpellRadiusStore;
extern AC_GAME_API DBCStorage <SpellRangeEntry>              sSpellRangeStore;
extern AC_GAME_API DBCStorage <SpellRuneCostEntry>           sSpellRuneCostStore;
extern AC_GAME_API DBCStorage <SpellShapeshiftFormEntry>     sSpellShapeshiftFormStore;
extern AC_GAME_API DBCStorage <SpellEntry>                   sSpellStore;
extern AC_GAME_API DBCStorage <SpellVisualEntry>             sSpellVisualStore;
extern AC_GAME_API DBCStorage <StableSlotPricesEntry>        sStableSlotPricesStore;
extern AC_GAME_API DBCStorage <SummonPropertiesEntry>        sSummonPropertiesStore;
extern AC_GAME_API DBCStorage <TalentEntry>                  sTalentStore;
extern AC_GAME_API DBCStorage <TalentTabEntry>               sTalentTabStore;
extern AC_GAME_API DBCStorage <TaxiNodesEntry>               sTaxiNodesStore;
extern AC_GAME_API DBCStorage <TaxiPathEntry>                sTaxiPathStore;
extern AC_GAME_API TaxiMask                                  sTaxiNodesMask;
extern AC_GAME_API TaxiMask                                  sOldContinentsNodesMask;
extern AC_GAME_API TaxiMask                                  sHordeTaxiNodesMask;
extern AC_GAME_API TaxiMask                                  sAllianceTaxiNodesMask;
extern AC_GAME_API TaxiMask                                  sDeathKnightTaxiNodesMask;
extern AC_GAME_API TaxiPathSetBySource                       sTaxiPathSetBySource;
extern AC_GAME_API TaxiPathNodesByPath                       sTaxiPathNodesByPath;
extern AC_GAME_API DBCStorage <TeamContributionPointsEntry>  sTeamContributionPointsStore;
extern AC_GAME_API DBCStorage <TotemCategoryEntry>           sTotemCategoryStore;
extern AC_GAME_API DBCStorage <VehicleEntry>                 sVehicleStore;
extern AC_GAME_API DBCStorage <VehicleSeatEntry>             sVehicleSeatStore;
extern AC_GAME_API DBCStorage <WMOAreaTableEntry>            sWMOAreaTableStore;
//extern DBCStorage <WorldMapAreaEntry>           sWorldMapAreaStore; -- use Zone2MapCoordinates and Map2ZoneCoordinates
extern AC_GAME_API DBCStorage <WorldMapOverlayEntry>         sWorldMapOverlayStore;

void LoadDBCStores(std::string const& dataPath);

#endif

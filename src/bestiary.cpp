// Copyright 2023 The Forgotten Server Authors. All rights reserved.
// Use of this source code is governed by the GPL-2.0 License that can be found in the LICENSE file.

#include "otpch.h"

#include "bestiary.h"
#include "monsters.h"

extern Monsters g_monsters;

void Bestiary::addMonsterType(const std::string& className, uint16_t raceId, std::string_view monsterName)
{
    if (bestiary.contains(className) && bestiary.at(className).contains(raceId)) {
        std::cout << "[Warning - Bestiary::addMonsterrType] raceId " << raceId << " already exists for class " << className << std::endl;
        return;
    }

    bestiary[className][raceId] = monsterName;
    ++monsterCount;
}

MonsterType* Bestiary::getMonsterType(const std::string& className, uint16_t raceId) const
{
    if (!bestiary.contains(className) || !bestiary.at(className).contains(raceId)) {
        return nullptr;
    }

    return g_monsters.getMonsterType(bestiary.at(className).at(raceId));
}

bool Bestiary::isValid(const BestiaryInfo& info) const
{
    if (info.raceId == 0) {
        std::cout << "[Warning - Bestiary::isValid] race id can't be 0." << std::endl;
        return false;
    }

    if (info.className.empty()) {
        std::cout << "[Warning - Bestiary::isValid] class name can't be empty." << std::endl;
        return false;
    }

    if (info.prowess == 0 || info.expertise == 0 || info.mastery == 0) {
        std::cout << "[Warning - Bestiary::isValid] prowess, expertise and mastery can't be 0." << std::endl;
        return false;
    }

    if (info.prowess >= info.expertise || info.expertise >= info.mastery) {
        std::cout << "[Warning - Bestiary::isValid] prowess must be lower than expertise and expertise must be lower than mastery." << std::endl;
        return false;
    }

    if (info.stars > BESTIARY_MAX_STARS) {
        std::cout << "[Warning - Bestiary::isValid] stars can't be higher than " << BESTIARY_MAX_STARS << '.' << std::endl;
        return false;
    }

    if (info.occurrence > BESTIARY_MAX_OCCURRENCE) {
        std::cout << "[Warning - Bestiary::isValid] occurrence can't be higher than " << BESTIARY_MAX_OCCURRENCE << '.' << std::endl;
        return false;
    }

    return true;
}

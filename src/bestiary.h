// Copyright 2023 The Forgotten Server Authors. All rights reserved.
// Use of this source code is governed by the GPL-2.0 License that can be found in the LICENSE file.

#ifndef FS_BESTIARY_H
#define FS_BESTIARY_H

class MonsterType;
struct BestiaryInfo;

static constexpr int32_t BESTIARY_MAX_STARS = 5;
static constexpr int32_t BESTIARY_MAX_OCCURRENCE = 4;

using RaceMap = std::map<uint16_t, std::string>;
using BestiaryMap = std::map<std::string, RaceMap>;

class Bestiary
{
public:
	Bestiary() = default;
	// non-copyable
	Bestiary(const Bestiary&) = delete;
	Bestiary& operator=(const Bestiary&) = delete;

	void addMonsterType(const std::string& className, uint16_t raceId, std::string_view monsterName);
	MonsterType* getMonsterType(const std::string& className, uint16_t raceId) const;
    const BestiaryMap& getBestiary() const { return bestiary; }
	size_t getMonsterCount() const { return monsterCount; }
	bool isValid(const BestiaryInfo& bestiaryInfo) const;

	void clear() { bestiary.clear(); }

private:
	BestiaryMap bestiary;
	size_t monsterCount = 0;
};

#endif // FS_BESTIARY_H

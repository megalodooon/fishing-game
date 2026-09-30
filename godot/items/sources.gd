extends RefCounted
class_name Sources

# Where every item comes from, worked out once from the content itself: the
# junk each fishing ground brings up, sea creature drops, treasure chest loot,
# crops, recipes and events, plus the item's own foundAt text for shops. The
# recipe book shows it for every ingredient, so nothing is a mystery.

static var index : Dictionary = {}
static var built : bool = false


static func of(item : Item) -> PackedStringArray:
	if not item:
		return PackedStringArray()
	build()
	var key : Item = item.original()
	var list : PackedStringArray = index.get(key, PackedStringArray()).duplicate()
	if not key.foundAt.is_empty():
		list.insert(0, key.foundAt)
	return list

static func add(item : Item, text : String) -> void:
	if not item:
		return
	var key : Item = item.original()
	if not index.has(key):
		index[key] = PackedStringArray()
	if not index[key].has(text):
		index[key].append(text)

static func build() -> void:
	if built:
		return
	built = true
	for biome in Catalog.biomes():
		for junk in biome.junk:
			add(junk, "Fished up at %s" % biome.displayName)
	for creature in Catalog.creatures():
		for i in creature.drops.size():
			var chance : float = creature.dropChances[i] if i < creature.dropChances.size() else 1.0
			add(creature.drops[i], "Dropped by the %s%s" % [creature.displayName, "" if chance >= 1.0 else " (%s%%)" % String.num(chance * 100.0, 1)])
	for item in Catalog.items():
		if item is TreasureChest:
			for loot in (item as TreasureChest).loot:
				add(loot, "Inside a %s" % item.displayName)
		elif item is Seed and (item as Seed).crop:
			add((item as Seed).crop, "Grown from %s" % item.displayName)
	for recipe in Catalog.recipes():
		if recipe.result():
			add(recipe.result(), "Crafted (%s)" % Recipes.station_name(Recipes.station_of(recipe)))
	for drop in RareDrops.all():
		add(drop.item, "Rare catch at %s (1 in %d)" % [drop.where(), roundi(1.0 / maxf(drop.chance, 0.0001))])
	for event in GameEvent.all():
		for item in event.drops:
			add(item, "During %s" % event.displayName)
		for offer in event.shop:
			if offer and offer.item:
				add(offer.item, "%s event shop" % event.displayName)

# The fish an ingredient means, when it's a species or any fish of a rarity.
static func fish_text(ingredient : Resource, journal : Journal) -> PackedStringArray:
	if ingredient is FishData:
		var places : PackedStringArray = journal.biome_names(ingredient) if journal else PackedStringArray()
		var list : PackedStringArray = PackedStringArray()
		for place in places:
			list.append("Caught at %s" % place)
		return list if not list.is_empty() else PackedStringArray(["Caught while fishing"])
	if ingredient is Rarity:
		return PackedStringArray(["Any %s fish you catch" % (ingredient as Rarity).displayName.to_lower()])
	return PackedStringArray()

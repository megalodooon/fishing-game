extends RefCounted
class_name Bank

# The Harbor Bank (like SkyBlock's): a coin account and an item vault.
# Coins in the account earn interest at the start of every season, up to the
# account tier's cap (kept modest, so interest is a bonus that never
# out-earns fishing); the vault keeps items safe, a page of slots per vault
# tier. Both tiers are raised at the bank for coins and materials (see
# ACCOUNTS and VAULTS). Saved in Progress.bank ({coins, account, vault,
# paid season}) and Progress.vault (the stored stacks).

const PAGE_SLOTS : int = 24
# Account tiers: name, interest per season, the most of the balance that
# earns it, what the upgrade costs ([coins, [item path, amount]...]).
const ACCOUNTS : Array = [
	["Starter Account", 0.015, 30000, [0]],
	["Silver Account", 0.02, 120000, [12000, ["res://items/materials/iron_ingot.tres", 10], ["res://items/materials/pearl_dust.tres", 5]]],
	["Gold Account", 0.025, 400000, [60000, ["res://items/enchanted/enchanted_pearl_oyster.tres", 4], ["res://items/rare/pirate_doubloon.tres", 1]]],
	["Premier Account", 0.03, 1000000, [250000, ["res://items/materials/storm_core.tres", 3], ["res://items/enchanted/enchanted_deep_coral.tres", 4]]],
]
# Vault tiers: name, pages, upgrade cost.
const VAULTS : Array = [
	["Lockbox", 1, [0]],
	["Strongbox", 2, [4000, ["res://items/materials/iron_ingot.tres", 4]]],
	["Safe", 3, [20000, ["res://items/materials/treated_plank.tres", 12], ["res://items/materials/iron_ingot.tres", 12]]],
	["Vault", 4, [80000, ["res://items/materials/obsidian_plate.tres", 4]]],
	["Grand Vault", 6, [300000, ["res://items/materials/storm_core.tres", 2], ["res://items/materials/abyss_lens.tres", 1]]],
]


static func data(progress : Progress) -> Dictionary:
	if progress.bank.is_empty():
		progress.bank = {"coins": 0, "account": 0, "vault": 0, "paid": -1}
	return progress.bank

static func is_open(progress : Progress) -> bool:
	return progress.has_flag("bank/open")

static func coins(progress : Progress) -> int:
	return int(data(progress).coins) if not progress.bank.is_empty() else 0

static func account_tier(progress : Progress) -> int:
	return int(data(progress).account)

static func vault_tier(progress : Progress) -> int:
	return int(data(progress).vault)

static func account(progress : Progress) -> Array:
	return ACCOUNTS[account_tier(progress)]

static func slots(progress : Progress) -> int:
	return VAULTS[vault_tier(progress)][1] * PAGE_SLOTS

# The vault stacks, padded to the vault's size.
static func vault(progress : Progress) -> Array:
	while progress.vault.size() < slots(progress):
		progress.vault.append(null)
	return progress.vault

static func deposit(player : Player, amount : int) -> int:
	var moved : int = mini(amount, player.wallet.coins)
	if moved <= 0:
		return 0
	player.wallet.spend(moved)
	data(player.progress).coins = coins(player.progress) + moved
	player.progress.emit_changed()
	return moved

static func withdraw(player : Player, amount : int) -> int:
	var moved : int = mini(amount, coins(player.progress))
	if moved <= 0:
		return 0
	data(player.progress).coins = coins(player.progress) - moved
	player.wallet.add(moved)
	player.progress.emit_changed()
	return moved

# Interest for the season that just started, once. Returns what was paid.
static func pay_interest(player : Player, day : int) -> int:
	if not is_open(player.progress):
		return 0
	var season_index : int = floori((day - 1) / float(Calendar.SEASON_DAYS))
	var bank : Dictionary = data(player.progress)
	if int(bank.paid) >= season_index:
		return 0
	var first : bool = int(bank.paid) < 0
	bank.paid = season_index
	if first:
		return 0
	var tier : Array = account(player.progress)
	var interest : int = floori(mini(coins(player.progress), tier[2]) * tier[1])
	if interest <= 0:
		return 0
	bank.coins = coins(player.progress) + interest
	player.progress.count("interest", interest)
	var board : NoticeBoard = NoticeBoard.find(player.get_tree())
	if board:
		board.post("Bank interest: +$%s" % UiKit.coins_text(interest), "%s pays %s%% a season on up to $%s." % [tier[0], String.num(tier[1] * 100.0, 1), UiKit.coins_text(tier[2])], Color(1.0, 0.9, 0.4))
	return interest

# What an upgrade still needs, as text lines, or [] when it can be paid.
static func missing(player : Player, cost : Array) -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	if player.wallet.coins + coins(player.progress) < int(cost[0]):
		lines.append("$%s" % UiKit.coins_text(int(cost[0])))
	for i in range(1, cost.size()):
		var thing : Item = load(cost[i][0]) as Item
		if thing and player.inventory.count(thing) < int(cost[i][1]):
			lines.append("%d %s" % [cost[i][1], thing.displayName])
	return lines

# Pays for an upgrade: coins from the wallet first, then the account.
static func pay(player : Player, cost : Array) -> bool:
	if not missing(player, cost).is_empty():
		return false
	var price : int = int(cost[0])
	var fromWallet : int = mini(price, player.wallet.coins)
	player.wallet.spend(fromWallet)
	data(player.progress).coins = coins(player.progress) - (price - fromWallet)
	for i in range(1, cost.size()):
		player.inventory.take(load(cost[i][0]) as Item, int(cost[i][1]))
	return true

static func upgrade_account(player : Player) -> bool:
	var next : int = account_tier(player.progress) + 1
	if next >= ACCOUNTS.size() or not pay(player, ACCOUNTS[next][3]):
		return false
	data(player.progress).account = next
	player.progress.emit_changed()
	return true

static func upgrade_vault(player : Player) -> bool:
	var next : int = vault_tier(player.progress) + 1
	if next >= VAULTS.size() or not pay(player, VAULTS[next][2]):
		return false
	data(player.progress).vault = next
	if next == VAULTS.size() - 1:
		player.progress.set_flag("bank/vault_max")
	vault(player.progress)
	player.progress.emit_changed()
	return true

# Moves a bag slot's stack into the vault, merging with stacks already there.
# Returns how many moved.
static func store(player : Player, slot : int) -> int:
	var stack : Item = player.inventory.get_item(slot)
	if not stack or stack.category == "Key Item":
		return 0
	var room : Array = vault(player.progress)
	var left : int = stack.amount
	if stack.stacks():
		for i in room.size():
			var there : Item = room[i]
			if there and there.same_kind(stack) and there.amount < there.maxStack:
				var fits : int = mini(left, there.maxStack - there.amount)
				there.amount += fits
				left -= fits
				if left <= 0:
					break
	if left > 0:
		var free : int = room.find(null)
		if free < 0:
			var moved_partly : int = stack.amount - left
			stack.amount = left
			player.inventory.emit_changed()
			return moved_partly
		var copy : Item = stack.unique() if stack.stacks() else stack
		copy.amount = left
		room[free] = copy
	var moved : int = stack.amount
	player.inventory.items[slot] = null
	player.inventory.emit_changed()
	player.progress.emit_changed()
	return moved

# Moves a vault slot's stack back into the bag, as much as fits.
static func take(player : Player, index : int) -> int:
	var room : Array = vault(player.progress)
	var stack : Item = room[index] if index < room.size() else null
	if not stack:
		return 0
	var fits : int = mini(stack.amount, player.inventory.room_for(stack))
	if fits <= 0:
		return 0
	if stack.stacks():
		player.inventory.give(stack.original(), fits)
		stack.amount -= fits
		if stack.amount <= 0:
			room[index] = null
	else:
		player.inventory.add(stack)
		room[index] = null
	player.progress.emit_changed()
	return fits

# Every material-like stack in the bag goes into the vault.
static func store_materials(player : Player) -> int:
	var moved : int = 0
	for slot in player.inventory.trashSlot:
		var stack : Item = player.inventory.get_item(slot)
		if stack and stack.stacks() and ["Material", "Forage", "Refined", "Enchanted Material", "Crop", "Creature Drop", "Fish Product", "Upgrade Material", "Junk"].has(stack.type_name()):
			moved += store(player, slot)
	return moved

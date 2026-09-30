@tool
extends Counter
class_name BankCounter

# Barnaby's counter at the Harbor Bank (see Bank). The Account tab moves
# coins in and out and upgrades the account; the Vault tab shows what's kept
# there (click to take it back) and upgrades the vault; the Store tab lists
# the bag (click to put a stack away) with a button for all materials at once.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const DIM : Color = Color(0.58, 0.67, 0.78)
const PRICE : Color = Color(1.0, 0.9, 0.4)
const AMOUNTS : Array[int] = [1000, 10000, 100000]

enum Tab { ACCOUNT, VAULT, STORE }


func theme_name() -> String:
	return "leather_blue"

func searchable() -> bool:
	return tab != Tab.ACCOUNT

func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray(["Account", "Vault", "Store"])

func subtitle(player : Player) -> String:
	var account : Array = Bank.account(player.progress)
	return "%s: $%s. %s%% interest a season on up to $%s" % [account[0], UiKit.coins_text(Bank.coins(player.progress)), String.num(account[1] * 100.0, 1), UiKit.coins_text(account[2])]

func opened(player : Player) -> void:
	# The first visit opens the account; interest starts from the next season.
	if not Bank.is_open(player.progress):
		player.progress.set_flag("bank/open")
		var cycle : DayNightCycle = DayNightCycle.find(get_tree())
		Bank.data(player.progress).paid = floori(((cycle.day if cycle else 1) - 1) / float(Calendar.SEASON_DAYS))
	Bank.vault(player.progress)

func pinned_rows(player : Player) -> Array[Dictionary]:
	match tab:
		Tab.VAULT:
			var used : int = 0
			for stack in Bank.vault(player.progress):
				if stack:
					used += 1
			return [{"value": &"upgrade_vault", "text": "%s: %d/%d slots" % [Bank.VAULTS[Bank.vault_tier(player.progress)][0], used, Bank.slots(player.progress)], "detail": "Upgrade" if Bank.vault_tier(player.progress) < Bank.VAULTS.size() - 1 else "Max", "detailColor": PRICE, "marked": true, "markColor": GOOD}]
		Tab.STORE:
			return [{"value": &"store_materials", "text": "Store all materials", "detail": "", "marked": true, "markColor": GOOD}]
	return []

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	match tab:
		Tab.ACCOUNT:
			list.append({"header": true, "text": "Deposit"})
			for amount in AMOUNTS:
				list.append({"value": ["in", amount], "text": "Deposit $%s" % UiKit.coins_text(amount), "detail": "", "dim": player.wallet.coins < amount})
			list.append({"value": ["in", -1], "text": "Deposit everything", "detail": "$%s" % UiKit.coins_text(player.wallet.coins), "detailColor": PRICE, "dim": player.wallet.coins <= 0})
			list.append({"header": true, "text": "Withdraw"})
			for amount in AMOUNTS:
				list.append({"value": ["out", amount], "text": "Withdraw $%s" % UiKit.coins_text(amount), "detail": "", "dim": Bank.coins(player.progress) < amount})
			list.append({"value": ["out", -1], "text": "Withdraw everything", "detail": "$%s" % UiKit.coins_text(Bank.coins(player.progress)), "detailColor": PRICE, "dim": Bank.coins(player.progress) <= 0})
			if Bank.account_tier(player.progress) < Bank.ACCOUNTS.size() - 1:
				list.append({"header": true, "text": "Account"})
				list.append({"value": &"upgrade_account", "text": "Upgrade to %s" % Bank.ACCOUNTS[Bank.account_tier(player.progress) + 1][0], "detail": "", "marked": true, "markColor": GOOD})
		Tab.VAULT:
			var room : Array = Bank.vault(player.progress)
			for i in room.size():
				var stack : Item = room[i]
				if stack:
					list.append({"value": i, "icon": stack.icon, "text": stack.displayName if stack.amount <= 1 else "%s x%d" % [stack.displayName, stack.amount], "detail": "Take", "detailColor": DIM})
		Tab.STORE:
			for slot in player.inventory.trashSlot:
				var stack : Item = player.inventory.get_item(slot)
				if stack and stack.category != "Key Item":
					list.append({"value": slot, "icon": stack.icon, "text": stack.displayName if stack.amount <= 1 else "%s x%d" % [stack.displayName, stack.amount], "detail": "Store", "detailColor": DIM})
	return list

func cost_lines(player : Player, cost : Array) -> Array:
	var lines : Array = [["Coins", "$%s" % UiKit.coins_text(int(cost[0])), GOOD if player.wallet.coins + Bank.coins(player.progress) >= int(cost[0]) else Color(0.95, 0.38, 0.34)]]
	for i in range(1, cost.size()):
		var thing : Item = load(cost[i][0]) as Item
		if thing:
			var have : int = player.inventory.count(thing)
			lines.append([thing.displayName, "%d/%d" % [mini(have, cost[i][1]), cost[i][1]], GOOD if have >= int(cost[i][1]) else Color(0.95, 0.38, 0.34)])
	return lines

func info(player : Player, value : Variant) -> Dictionary:
	if value is StringName:
		match value:
			&"upgrade_account":
				var next : Array = Bank.ACCOUNTS[Bank.account_tier(player.progress) + 1]
				var lines : Array = [["Interest", "%s%% a season" % String.num(next[1] * 100.0, 1), GOOD], ["Earns on up to", "$%s" % UiKit.coins_text(next[2]), GOOD]]
				lines.append_array(cost_lines(player, next[3]))
				return {"title": next[0], "text": "A better account earns interest on more of your savings.", "lines": lines, "action": "Upgrade", "enabled": Bank.missing(player, next[3]).is_empty()}
			&"upgrade_vault":
				var tier : int = Bank.vault_tier(player.progress)
				if tier >= Bank.VAULTS.size() - 1:
					return {"title": Bank.VAULTS[tier][0], "text": "The biggest vault in the harbor. Barnaby is very proud of it.", "lines": [["Slots", "%d" % Bank.slots(player.progress)]]}
				var next_vault : Array = Bank.VAULTS[tier + 1]
				var vault_lines : Array = [["Slots", "%d -> %d" % [Bank.slots(player.progress), next_vault[1] * Bank.PAGE_SLOTS], GOOD]]
				vault_lines.append_array(cost_lines(player, next_vault[2]))
				return {"title": "Upgrade to " + next_vault[0], "text": "More room for everything you don't want to carry around.", "lines": vault_lines, "action": "Upgrade", "enabled": Bank.missing(player, next_vault[2]).is_empty()}
			&"store_materials":
				return {"title": "Store all materials", "text": "Puts every material, crop, forage find and creature drop in the bag into the vault, merging stacks.", "action": "Store them", "enabled": true}
	if value is Array:
		var into : bool = value[0] == "in"
		var amount : int = value[1]
		var shown : int = (player.wallet.coins if into else Bank.coins(player.progress)) if amount < 0 else amount
		var can : bool = (player.wallet.coins if into else Bank.coins(player.progress)) >= maxi(shown, 1)
		return {"title": "%s $%s" % ["Deposit" if into else "Withdraw", UiKit.coins_text(shown)], "text": "Coins in the bank earn interest at the start of every season." if into else "Coins back into your wallet.", "lines": [["Wallet", "$%s" % UiKit.coins_text(player.wallet.coins)], ["Bank", "$%s" % UiKit.coins_text(Bank.coins(player.progress))]], "action": "Deposit" if into else "Withdraw", "enabled": can}
	if value is int:
		var stack : Item = (Bank.vault(player.progress)[value] if tab == Tab.VAULT else player.inventory.get_item(value)) as Item
		if not stack:
			return {}
		var details : Dictionary = Counter.item_info(stack)
		details.action = "Take it" if tab == Tab.VAULT else "Put it away"
		return details
	return {}

func choose(player : Player, value : Variant) -> String:
	if value is StringName:
		match value:
			&"upgrade_account":
				return ok("Account upgraded!") if Bank.upgrade_account(player) else fail("Not enough yet")
			&"upgrade_vault":
				return ok("Vault upgraded!") if Bank.upgrade_vault(player) else fail("Not enough yet")
			&"store_materials":
				var moved : int = Bank.store_materials(player)
				return ok("Stored %d things" % moved) if moved > 0 else fail("Nothing to store, or the vault is full")
	if value is Array:
		var into : bool = value[0] == "in"
		var amount : int = value[1]
		if into:
			var moved_in : int = Bank.deposit(player, player.wallet.coins if amount < 0 else amount)
			return ok("Deposited $%s" % UiKit.coins_text(moved_in)) if moved_in > 0 else fail("Not enough coins")
		var moved_out : int = Bank.withdraw(player, Bank.coins(player.progress) if amount < 0 else amount)
		return ok("Withdrew $%s" % UiKit.coins_text(moved_out)) if moved_out > 0 else fail("Not that much in the bank")
	if value is int:
		if tab == Tab.VAULT:
			return ok("Took it out") if Bank.take(player, value) > 0 else fail("No room in the bag")
		return ok("Stored") if Bank.store(player, value) > 0 else fail("The vault is full")
	return ""

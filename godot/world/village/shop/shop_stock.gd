extends Resource
class_name ShopStock

# What a shop sells, kept in its own file (res://world/village/shop/stock) so
# stock can be changed without opening the island's scene, and so the skills
# menu can show which levels open up better stock. A Shop sells its stock's
# offers after its own.

const FOLDER : String = "res://world/village/shop/stock"

#------------------------#
# Who sells it, for the skills menu, like "The Tackle Shop".
@export var shopName : String = ""
@export var offers : Array[ShopOffer] = []
#------------------------#


static var cache : Array[ShopStock] = []
static var scanned : bool = false


static func all() -> Array[ShopStock]:
	if not scanned:
		scanned = true
		for resource in Catalog.scan(FOLDER):
			if resource is ShopStock:
				cache.append(resource)
	return cache

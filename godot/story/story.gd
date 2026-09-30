extends RefCounted
class_name Story

# The chapters of the story. Story quests set Progress.chapter as they're
# handed in (Quest.chapter), and a chapter card shows when a new one starts.

const CHAPTERS : PackedStringArray = [
	"Homecoming",
	"The Hermit's Secret",
	"The Village Cup",
	"Deep Trouble",
	"Silver Waters",
	"Frost and Fire",
	"Eye of the Storm",
	"The Rig",
	"The Four Tides",
	"Champion of the Seas",
	"Epilogue",
]


static func chapter_title(index : int) -> String:
	return CHAPTERS[clampi(index, 0, CHAPTERS.size() - 1)]

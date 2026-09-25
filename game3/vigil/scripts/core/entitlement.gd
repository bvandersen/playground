extends Node

## Autoload Entitlement: which tiers of recipes this install may draw.
## A stub until Phase 11 (store billing) -- always "free".

const FREE := "free"
const DEEP := "deep"

func tier() -> String:
	return FREE

func allows(recipe_tier: String) -> bool:
	return recipe_tier == FREE or tier() == DEEP

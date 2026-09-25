extends RefCounted
class_name Skeleton

## The one place the ragdoll's shape is defined: which joints exist, how
## they connect, and the standing rest pose every Move bends away from.
## Offsets are in "doll units" (scale 1.0), relative to the pelvis, y down,
## so a doll standing upright has its pelvis at (0, 0) and feet at +178.

const HEAD := 0
const NECK := 1
const CHEST := 2
const PELVIS := 3
const L_ELBOW := 4
const L_HAND := 5
const R_ELBOW := 6
const R_HAND := 7
const L_KNEE := 8
const L_FOOT := 9
const R_KNEE := 10
const R_FOOT := 11
const COUNT := 12

const DEFAULT_HEAD_RADIUS := 46.0
## Pelvis-to-sole height of the rest pose -- what Stand lifts the pelvis to.
const STAND_HEIGHT := 178.0

## Visible sticks: [a, b]. Rest lengths come from the rest pose.
const BONES := [
	[NECK, HEAD], [NECK, CHEST], [CHEST, PELVIS],
	[NECK, L_ELBOW], [L_ELBOW, L_HAND], [NECK, R_ELBOW], [R_ELBOW, R_HAND],
	[PELVIS, L_KNEE], [L_KNEE, L_FOOT], [PELVIS, R_KNEE], [R_KNEE, R_FOOT],
]

## Invisible braces: [a, b, stiffness] -- keep the head on straight-ish and
## the spine from folding in half, softly, so it still wobbles.
const BRACES := [
	[HEAD, CHEST, 0.35], [NECK, PELVIS, 0.25], [L_KNEE, R_KNEE, 0.02],
]

## The visible parts a style can be applied to, and which joints each one
## draws through. "hands"/"feet" are drawn at their joint, pointing along
## the last bone.
const PART_GROUPS := ["head", "torso", "arms", "legs", "hands", "feet"]
const PART_NAMES := {
	"head": "Head", "torso": "Body", "arms": "Arms", "legs": "Legs",
	"hands": "Hands", "feet": "Feet",
}
const CHAINS := {
	"torso": [[NECK, CHEST, PELVIS]],
	"arms": [[NECK, L_ELBOW, L_HAND], [NECK, R_ELBOW, R_HAND]],
	"legs": [[PELVIS, L_KNEE, L_FOOT], [PELVIS, R_KNEE, R_FOOT]],
}
const ENDS := {
	"hands": [[L_ELBOW, L_HAND], [R_ELBOW, R_HAND]],
	"feet": [[L_KNEE, L_FOOT], [R_KNEE, R_FOOT]],
}

const MASS := [1.4, 1.2, 1.6, 1.8, 0.8, 0.6, 0.8, 0.6, 1.0, 0.8, 1.0, 0.8]
## How much wind catches each joint.
const DRAG := [1.4, 0.6, 1.0, 0.8, 0.8, 1.0, 0.8, 1.0, 0.7, 0.9, 0.7, 0.9]

static func rest_pose(head_radius: float = DEFAULT_HEAD_RADIUS) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.resize(COUNT)
	p[PELVIS] = Vector2(0, 0)
	p[CHEST] = Vector2(0, -62)
	p[NECK] = Vector2(0, -125)
	p[HEAD] = Vector2(0, -125 - head_radius - 6)
	p[L_ELBOW] = Vector2(-35, -59)
	p[L_HAND] = Vector2(-45, 10)
	p[R_ELBOW] = Vector2(35, -59)
	p[R_HAND] = Vector2(45, 10)
	p[L_KNEE] = Vector2(-22, 88)
	p[L_FOOT] = Vector2(-24, 178)
	p[R_KNEE] = Vector2(22, 88)
	p[R_FOOT] = Vector2(24, 178)
	return p

## Collision radius of each joint, in doll units, for a given head size
## and the thickness the torso/limbs are drawn at.
static func joint_radius(i: int, head_radius: float) -> float:
	if i == HEAD:
		return head_radius
	if i == CHEST or i == PELVIS:
		return 22.0
	return 13.0

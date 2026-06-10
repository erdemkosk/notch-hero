class_name MagicSchool
extends RefCounted

enum School { PYROMANCY, CRYOMANCY, ARCANE }

const NAMES := {
	School.PYROMANCY: "Pyromancer",
	School.CRYOMANCY: "Cryomancer",
	School.ARCANE: "Arcane Mage",
}

const COLORS := {
	School.PYROMANCY: Color(1.0, 0.42, 0.24),
	School.CRYOMANCY: Color(0.42, 0.77, 1.0),
	School.ARCANE: Color(0.78, 0.49, 1.0),
}

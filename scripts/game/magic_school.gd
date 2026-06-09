class_name MagicSchool
extends RefCounted

enum School { PYROMANCY, CRYOMANCY, ARCANE }

const NAMES := {
	School.PYROMANCY: "Ates Buyucusu",
	School.CRYOMANCY: "Buz Buyucusu",
	School.ARCANE: "Kadim Buyucu",
}

const COLORS := {
	School.PYROMANCY: Color(1.0, 0.42, 0.24),
	School.CRYOMANCY: Color(0.42, 0.77, 1.0),
	School.ARCANE: Color(0.78, 0.49, 1.0),
}

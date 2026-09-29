// Comprueba que los scripts de GDScript cambiados compilan, con los autoloads
// del proyecto cargados (Database, Auth, ProfileApi...). `godot --check-only`
// no sirve para esto: no registra los autoloads y da "Identifier not found".
//
//   GODOT_BIN=/ruta/a/Godot_v4.5.1-stable_linux.x86_64 node tests/godot_parse.mjs
//
// Se trabaja sobre una copia del proyecto en /tmp para no llenar el repo de
// ficheros de importacion. "Cambiados" = distintos de PARSE_BASE (por defecto
// origin/feat/profile-api), sin commitear incluidos.
//
// Como control, se meten en la copia dos scripts rotos a proposito: si el
// comprobador no los detecta, la prueba falla aunque todo lo demas pase.

import { execFileSync, spawnSync } from "node:child_process";
import { cpSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const GODOT = process.env.GODOT_BIN ?? "godot";
const BASE = process.env.PARSE_BASE ?? "origin/feat/profile-api";

function fail(message) {
	console.error(`GODOT PARSE FAILED: ${message}`);
	process.exit(1);
}

const git = (...args) => execFileSync("git", ["-C", ROOT, ...args], { encoding: "utf8" });

const changed = [
	...git("diff", "--name-only", "--diff-filter=AMR", BASE, "--", "game_godot").split("\n"),
	...git("ls-files", "--others", "--exclude-standard", "--", "game_godot").split("\n"),
]
	.filter((f) => f.endsWith(".gd"))
	.map((f) => "res://" + f.slice("game_godot/".length));

if (changed.length === 0) {
	fail(`no hay scripts cambiados respecto a ${BASE}`);
}

const work = mkdtempSync(path.join(os.tmpdir(), "godot-parse-"));
try {
	const proj = path.join(work, "proj");
	cpSync(path.join(ROOT, "game_godot"), proj, { recursive: true });

	writeFileSync(path.join(proj, "zz_parse_probe.gd"), `extends SceneTree

func _initialize() -> void:
	for f in OS.get_cmdline_user_args():
		var s = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or not (s is GDScript) or not s.can_instantiate():
			print("PROBE FAIL ", f)
		else:
			print("PROBE OK ", f)
	quit()
`);
	// Controles: uno de sintaxis y uno de tipos que usa un autoload.
	writeFileSync(path.join(proj, "zz_broken_syntax.gd"), "extends Node\nfunc _ready() -> void:\n\tvar x: int = 1 +\n");
	writeFileSync(path.join(proj, "zz_broken_types.gd"), "extends Node\nfunc _ready() -> void:\n\tvar t: int = ProfileApi.MENSAJES\n");
	const controls = ["res://zz_broken_syntax.gd", "res://zz_broken_types.gd"];

	const imp = spawnSync(GODOT, ["--headless", "--path", proj, "--import"], { encoding: "utf8", timeout: 900_000 });
	if (imp.error) {
		fail(`no se pudo ejecutar ${GODOT}: ${imp.error.message}`);
	}

	const run = spawnSync(GODOT, ["--headless", "--path", proj, "-s", "res://zz_parse_probe.gd", "--", ...changed, ...controls],
		{ encoding: "utf8", timeout: 300_000 });
	const out = `${run.stdout}\n${run.stderr}`;
	const status = new Map();
	for (const m of out.matchAll(/^PROBE (OK|FAIL) (res:\/\/\S+)$/gm)) {
		status.set(m[2], m[1]);
	}

	for (const c of controls) {
		if (status.get(c) !== "FAIL") {
			fail(`el control ${c} no se detecto como roto (${status.get(c) ?? "sin resultado"})`);
		}
	}

	const broken = changed.filter((f) => status.get(f) !== "OK");
	if (broken.length > 0) {
		const errors = out.split("\n").filter((l) => /SCRIPT ERROR|Parse Error|Compile Error/.test(l));
		fail(`no compilan: ${broken.join(", ")}\n${errors.join("\n")}`);
	}

	console.log(changed.map((f) => `ok ${f}`).join("\n"));
	console.log(`GODOT PARSE PASSED (${changed.length} scripts, ${controls.length} controles detectados)`);
} finally {
	rmSync(work, { recursive: true, force: true });
}

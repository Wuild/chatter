"""Release ZIP regressions: contents, version, load chain, and repeatability."""

from pathlib import Path
import json
import re
import tempfile
import unittest
import zipfile

from package_addon import build_package, prepare_package

REPOSITORY = Path(__file__).resolve().parents[1]
VERSION = "0.1.0"


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source"
        self.output = Path(self.temp.name) / "output"
        self.write("LICENSE", "license")
        self.write("Whispr.toc", "\n".join([
            "## Title: Whispr", "## Interface: 16001, 120100, 11509", "## Version: @project-version@",
            "## X-Curse-Project-ID: 1727008", "scripts\\embeds.xml",
            "extensions\\emoji\\module.lua"]))
        self.write("scripts/embeds.xml", '<Ui><Include file="lib/load.xml"/></Ui>')
        self.write("scripts/lib/load.xml", '<Ui><Script file="../main.lua"/></Ui>')
        self.write("scripts/main.lua", "-- runtime")
        self.write("extensions/emoji/module.lua", "-- data")
        self.write("assets/icons/pin.tga", "fixture")

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def test_clean_versioned_repeatable_package(self):
        for junk in ("tools/update.py", ".wowhead-cache/page.html", ".github/workflow.yml",
                     ".git/config", "dist/old.zip", "Whispr_Vanilla.toc",
                     "scripts/__pycache__/test.pyc", "scripts/.hidden.lua", ".env", ".env.example"):
            self.write(junk, "must not ship")
        archive, version, notes, count = build_package(self.root, self.output, VERSION)
        first_build = archive.read_bytes()
        self.assertEqual(version, VERSION)
        self.assertNotIn("Old notes", notes)
        with zipfile.ZipFile(archive) as bundle:
            names = set(bundle.namelist())
            self.assertEqual(count, 7)
            self.assertEqual(len(names), count)
            self.assertTrue(all(p.startswith("Whispr/") for p in names))
            self.assertIn("Whispr/assets/icons/pin.tga", names)
            self.assertEqual([p for p in names if p.endswith(".toc")], ["Whispr/Whispr.toc"])
            toc = bundle.read("Whispr/Whispr.toc").decode()
            self.assertIn("## Version: " + VERSION, toc)
            self.assertNotIn("@project-version@", toc)
        build_package(self.root, self.output, VERSION)
        self.assertEqual(first_build, archive.read_bytes())
        self.assertTrue(archive.with_suffix(".zip.sha256").exists())

    def test_semantic_release_versions_supported(self):
        for release in ("0.1.0", "0.2.0", "1.0.0"):
            payload, version, _ = prepare_package(self.root, release)
            self.assertEqual(version, release)
            self.assertIn(f"## Version: {release}", payload["Whispr.toc"].decode())
            self.assertIn("## Interface: 16001, 120100, 11509", payload["Whispr.toc"].decode())

    def test_non_semantic_versions_rejected(self):
        for version in ("8.0", "00.1.0", "0.1.0-retail", "0.1.0-forever.", "0.1.0-forever.0", "0.1.0-forever-extra"):
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, "Version must use"):
                build_package(self.root, self.output, version)

    def test_invalid_version_rejected(self):
        with self.assertRaisesRegex(ValueError, "Version must use"):
            prepare_package(self.root, "../../bad")

    def test_missing_xml_dependency_rejected(self):
        (self.root / "scripts/main.lua").unlink()
        with self.assertRaisesRegex(ValueError, "Missing packaged dependency: scripts/main.lua"):
            build_package(self.root, self.output, VERSION)

    def test_wrong_case_dependency_rejected(self):
        self.write("scripts/lib/load.xml", '<Ui><Script file="../Main.lua"/></Ui>')
        with self.assertRaisesRegex(ValueError, "Missing packaged dependency"):
            build_package(self.root, self.output, VERSION)

    def test_release_notes_are_optional_and_do_not_need_a_file(self):
        _, _, default_notes = prepare_package(self.root, VERSION)
        self.assertIn(VERSION, default_notes)
        _, _, notes = prepare_package(self.root, VERSION, "Custom release notes")
        self.assertEqual(notes, "Custom release notes")
        with self.assertRaisesRegex(ValueError, "must not be empty"):
            prepare_package(self.root, VERSION, " ")

    def rules(self, include=None, exclude=None):
        self.write("package-rules.json", json.dumps({
            "include": include if include is not None else ["Whispr.toc", "LICENSE", "scripts/**/*", "extensions/**/*", "assets/**/*"],
            "exclude": exclude or []}))

    def test_include_extra_files_and_exclude_nested_files(self):
        self.write("docs/help.txt", "help")
        self.write("assets/unused.tga", "unused")
        self.write("assets/old/nested.tga", "old")
        self.rules(include=["Whispr.toc", "LICENSE", "scripts/**/*", "extensions/**/*", "assets/**/*", "docs/*.txt"],
                   exclude=["assets/unused.tga", "assets/old"])
        payload, _, _ = prepare_package(self.root, VERSION)
        self.assertIn("docs/help.txt", payload)
        self.assertIn("assets/icons/pin.tga", payload)
        self.assertNotIn("assets/unused.tga", payload)
        self.assertNotIn("assets/old/nested.tga", payload)

    def test_broad_rules_never_include_credentials_or_hidden_metadata(self):
        for name in (".env", ".env.production", ".git/config", "scripts/.env", "scripts/__pycache__/cache.pyc"):
            self.write(name, "private")
        self.rules(include=["**/*"])
        payload, _, _ = prepare_package(self.root, VERSION)
        self.assertFalse(any(".env" in p or ".git" in p or "__pycache__" in p for p in payload))

    def test_excluding_required_files_or_dependencies_fails(self):
        for name in ("Whispr.toc", "LICENSE", "scripts/main.lua"):
            self.rules(exclude=[name])
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "Missing"):
                prepare_package(self.root, VERSION)

    def test_invalid_package_rules_fail(self):
        for rules in ('{', '{}', '{"include": "*", "exclude": []}',
                      '{"include": ["../outside"], "exclude": []}',
                      '{"include": ["C:/outside"], "exclude": []}'):
            self.write("package-rules.json", rules)
            with self.subTest(rules=rules), self.assertRaises(ValueError):
                prepare_package(self.root, VERSION)

    def test_actual_addon_packages_with_all_load_dependencies(self):
        archive, version, _, _ = build_package(REPOSITORY, self.output, VERSION)
        with zipfile.ZipFile(archive) as bundle:
            names = bundle.namelist()
            self.assertFalse(any("/tools/" in p or "/.wowhead-cache/" in p for p in names))
            self.assertIn("Whispr/scripts/libraries/Ace3-LICENSE.txt", names)
            self.assertIn("Whispr/extensions/emoji/module.lua", names)
            self.assertIn("## Version: " + version, bundle.read("Whispr/Whispr.toc").decode())


if __name__ == "__main__":
    unittest.main()

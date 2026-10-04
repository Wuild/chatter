"""Regression checks for the spacing pass that complements StyLua."""

import unittest

from lua_spacing import format_spacing


class LuaSpacingTests(unittest.TestCase):
    def test_neighboring_methods(self):
        source = "local T = {}\nfunction T:One()\nend\nfunction T:Two()\nend\nreturn T\n"
        expected = "local T = {}\n\nfunction T:One()\nend\n\nfunction T:Two()\nend\n\nreturn T\n"
        self.assertEqual(format_spacing(source), expected)
        self.assertEqual(format_spacing(expected), expected)

    def test_nested_blocks_and_callbacks(self):
        source = (
            "local T = {}\nfunction T:One()\n"
            "    if ready then\n        for i = 1, 2 do\n"
            "            run(function()\n            end)\n        end\n"
            "    elseif waiting then\n        repeat\n        until done\n    end\nend\nreturn T\n"
        )
        expected = source.replace("{}\nfunction", "{}\n\nfunction").replace("end\nreturn", "end\n\nreturn")
        self.assertEqual(format_spacing(source), expected)

    def test_literals_and_comments_are_untouched(self):
        for literal in (
            '"function fake() end"',
            "'function fake() end'",
            '[=[\nfunction fake()\nend\n]=]',
            '"escaped \\\" function fake() end"',
        ):
            source = f"local text = {literal}\nreturn text\n"
            self.assertEqual(format_spacing(source), source)
        source = "--[==[\nfunction fake()\nend\n]==]\nlocal n = 1\n-- function fake() end\nreturn n\n"
        self.assertEqual(format_spacing(source), source)

    def test_documentation_stays_with_function(self):
        source = "local T = {}\n-- Description.\n-- More detail.\nlocal function helper()\nend\n"
        self.assertEqual(format_spacing(source), source.replace("{}\n--", "{}\n\n--"))

    def test_first_nested_function_has_no_leading_blank_line(self):
        source = "function outer()\n    local function inner()\n    end\nend\n"
        self.assertEqual(format_spacing(source), source)

    def test_blocks_and_tables(self):
        source = "local T = {\n    one = 1,\n}\nuse(T)\nif ready then\n    run()\nend\nfinish()\n"
        expected = source.replace("}\nuse", "}\n\nuse").replace("end\nfinish", "end\n\nfinish")
        self.assertEqual(format_spacing(source), expected)
        self.assertEqual(format_spacing(expected), expected)

    def test_closing_lines_and_branches_stay_together(self):
        source = (
            "if ready then\n    local T = {\n        {\n            one = 1,\n        },\n    }\n"
            "else\n    while waiting do\n        run()\n    end\nend\n"
        )
        self.assertEqual(format_spacing(source), source)

    def test_function_at_start_and_end_needs_no_extra_lines(self):
        source = "function hello()\nend\n"
        self.assertEqual(format_spacing(source), source)


if __name__ == "__main__":
    unittest.main()

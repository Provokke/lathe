import std/[json, tables, unittest]
import ../src/lathe

suite "variables":
  test "plain text passes through":
    check render("no tags here", %*{}) == "no tags here"

  test "variables are escaped":
    check render("Hi {{name}}!", %*{"name": "<Bruce & Sheila>"}) == "Hi &lt;Bruce &amp; Sheila&gt;!"

  test "triple braces and ampersand skip escaping":
    let ctx = %*{"html": "<b>bold</b>"}
    check render("{{{html}}} {{& html}}", ctx) == "<b>bold</b> <b>bold</b>"

  test "missing values render as nothing":
    check render("[{{missing}}]", %*{}) == "[]"

  test "numbers and booleans":
    check render("{{count}} {{ratio}} {{ok}}", %*{"count": 3, "ratio": 1.5, "ok": true}) == "3 1.5 true"

  test "dotted names":
    check render("{{user.address.city}}", %*{"user": {"address": {"city": "Fremantle"}}}) == "Fremantle"

  test "comments are dropped":
    check render("a{{! ignore me }}b", %*{}) == "ab"

suite "sections":
  test "lists repeat the block":
    let ctx = %*{"items": [{"name": "tea"}, {"name": "milk"}]}
    check render("{{#items}}<li>{{name}}</li>{{/items}}", ctx) == "<li>tea</li><li>milk</li>"

  test "the dot is the current item":
    check render("{{#tags}}{{.}},{{/tags}}", %*{"tags": ["a", "b", "c"]}) == "a,b,c,"

  test "falsy values skip the block":
    let ctx = %*{"no": false, "none": nil, "empty": []}
    check render("{{#no}}x{{/no}}{{#none}}y{{/none}}{{#empty}}z{{/empty}}", ctx) == ""

  test "inverted sections":
    check render("{{^items}}nothing{{/items}}", %*{"items": []}) == "nothing"
    check render("{{^items}}nothing{{/items}}", %*{"items": [1]}) == ""

  test "objects push a scope and outer names stay visible":
    let ctx = %*{"site": "Lathe", "page": {"title": "Home"}}
    check render("{{#page}}{{title}} | {{site}}{{/page}}", ctx) == "Home | Lathe"

  test "nested sections":
    let ctx = %*{"rows": [{"cells": [1, 2]}, {"cells": [3]}]}
    check render("{{#rows}}[{{#cells}}{{.}}{{/cells}}]{{/rows}}", ctx) == "[12][3]"

  test "truthy scalars render once":
    check render("{{#admin}}yes{{/admin}}", %*{"admin": true}) == "yes"

suite "partials":
  test "partials share the context":
    var partials = initTable[string, Template]()
    partials["row"] = compile("<td>{{name}}</td>")
    let page = compile("{{#people}}<tr>{{> row}}</tr>{{/people}}")
    check page.render(%*{"people": [{"name": "Ash"}, {"name": "Kim"}]}, partials) ==
      "<tr><td>Ash</td></tr><tr><td>Kim</td></tr>"

  test "unknown partials render as nothing":
    check render("a{{> nope}}b", %*{}) == "ab"

suite "errors":
  test "unclosed tag":
    expect TemplateError:
      discard compile("hello {{name")

  test "unclosed section":
    expect TemplateError:
      discard compile("{{#items}}never closed")

  test "mismatched closing tag":
    expect TemplateError:
      discard compile("{{#a}}{{/b}}")

  test "stray closing tag":
    expect TemplateError:
      discard compile("text {{/a}}")

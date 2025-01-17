<div align="center">

# lathe

Logic-less templates for Nim in the Mustache style. One module, standard library only.

![License](https://img.shields.io/badge/LICENSE-MIT-blue?style=for-the-badge)  ![Language](https://img.shields.io/badge/NIM-ffe953?style=for-the-badge&logo=nim&logoColor=white)  ![Tests](https://img.shields.io/badge/TESTS-20-brightgreen?style=for-the-badge)

Refer to [LICENSE](LICENSE) for the legal bits.

</div>

## What's in it

Templates are compiled once into a small tree and rendered against a `JsonNode`.

| Tag | Behaviour |
| --- | --- |
| `{{name}}` | value, HTML-escaped |
| `{{{name}}}` or `{{& name}}` | value, not escaped |
| `{{#items}}...{{/items}}` | repeats for arrays, enters objects, renders once for other truthy values |
| `{{^items}}...{{/items}}` | renders when the value is missing, false or empty |
| `{{> partial}}` | includes another compiled template |
| `{{! note }}` | dropped |
| `{{.}}` | the current item |

Dotted names such as `{{user.address.city}}` walk into nested objects, and a name that isn't found in the current scope is looked up in the enclosing ones. There's also a small command-line front end.

```nim
import std/json
import lathe

let page = compile("<ul>{{#items}}<li>{{name}}</li>{{/items}}</ul>")
echo page.render(%*{"items": [{"name": "tea"}, {"name": "milk"}]})
```

## 🏗️ Architecture

```
 template text
      │  compile()  (recursive descent, tracks byte offsets)
      v
 Template { nodes: seq[Node] }
      Node = nkText | nkVar | nkRaw | nkPartial
           | nkSection{key, children} | nkInverted{key, children}
      │
      │  render(context: JsonNode, partials: Table[string, Template])
      v
 scope stack: seq[JsonNode]      lookup() walks it innermost first
      │   truthy() / toText() / escapeHtml()
      v
 one output string

 src/lathe.nim   (library + `when isMainModule` CLI)
 tests/test_lathe.nim   lathe.nimble
```

- `parseNodes` is a single recursive procedure. Sections recurse into themselves and return on the matching closing tag, so mismatched, stray and unclosed tags are all caught there.
- Syntax errors raise `TemplateError` with the byte offset. A missing value or missing partial renders as an empty string instead of raising.
- Arrays push each item onto the scope stack, objects push once, and other truthy values render the block without a new scope.
- Rendering appends to one string and doesn't stream.
- It follows the common parts of the Mustache spec, not all of it. Standalone tag lines aren't stripped, there are no lambdas and the delimiters can't be changed.

## 🚀 Quick start

```
nimble test
nimble build
./lathe page.mustache context.json
```

The context is read from standard input when no JSON file is given. With the template above and `{"items":[{"name":"tea"},{"name":"milk & co"}]}`:

```
<ul><li>tea</li><li>milk &amp; co</li></ul>
```

Tested with Nim 2.2.

## 🧪 Testing

20 tests, all passing (`nimble test` runs `nim c -r tests/test_lathe.nim`):

- Variables (7): plain text, escaping, triple braces and `&`, missing values, numbers and booleans, dotted names and comments.
- Sections (7): list repetition, `{{.}}`, falsy values, inverted sections, object scopes with outer names still visible, nested sections and truthy scalars.
- Partials (2): shared context and unknown partials.
- Errors (4): unclosed tag, unclosed section, mismatched closing tag and a stray closing tag.

## Licence

MIT.

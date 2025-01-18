import std/[json, strutils, tables]

type
  NodeKind = enum
    nkText, nkVar, nkRaw, nkSection, nkInverted, nkPartial

  Node = ref object
    case kind: NodeKind
    of nkText:
      text: string
    of nkVar, nkRaw, nkPartial:
      name: string
    of nkSection, nkInverted:
      key: string
      children: seq[Node]

  Template* = object
    nodes: seq[Node]

  TemplateError* = object of CatchableError

  Partials* = Table[string, Template]

proc fail(message: string, position: int) {.noreturn.} =
  raise newException(TemplateError, message & " at offset " & $position)

proc parseNodes(source: string, pos: var int, closing: string): seq[Node] =
  while pos < source.len:
    let open = source.find("{{", pos)
    if open < 0:
      result.add Node(kind: nkText, text: source[pos .. ^1])
      pos = source.len
      break
    if open > pos:
      result.add Node(kind: nkText, text: source[pos ..< open])

    let triple = source.continuesWith("{{{", open)
    let closer = if triple: "}}}" else: "}}"
    let start = open + closer.len
    let finish = source.find(closer, start)
    if finish < 0:
      fail("unclosed tag", open)
    let body = source[start ..< finish].strip()
    pos = finish + closer.len
    if body.len == 0:
      fail("empty tag", open)

    if triple:
      result.add Node(kind: nkRaw, name: body)
      continue

    let rest = body[1 .. ^1].strip()
    case body[0]
    of '!':
      discard
    of '&':
      result.add Node(kind: nkRaw, name: rest)
    of '>':
      result.add Node(kind: nkPartial, name: rest)
    of '#':
      result.add Node(kind: nkSection, key: rest, children: parseNodes(source, pos, rest))
    of '^':
      result.add Node(kind: nkInverted, key: rest, children: parseNodes(source, pos, rest))
    of '/':
      if rest != closing:
        fail("unexpected closing tag '" & rest & "'", open)
      return
    else:
      result.add Node(kind: nkVar, name: body)

  if closing.len > 0:
    fail("section '" & closing & "' is never closed", pos)

proc compile*(source: string): Template =
  var pos = 0
  result.nodes = parseNodes(source, pos, "")

proc escapeHtml*(text: string): string =
  result = newStringOfCap(text.len)
  for c in text:
    case c
    of '&': result.add "&amp;"
    of '<': result.add "&lt;"
    of '>': result.add "&gt;"
    of '"': result.add "&quot;"
    of '\'': result.add "&#39;"
    else: result.add c

proc lookup(stack: seq[JsonNode], name: string): JsonNode =
  if name == ".":
    return stack[^1]
  let parts = name.split('.')
  for i in countdown(stack.high, 0):
    var current = stack[i]
    var found = true
    for part in parts:
      if current.kind == JObject and current.hasKey(part):
        current = current[part]
      else:
        found = false
        break
    if found:
      return current
  newJNull()

proc toText(value: JsonNode): string =
  case value.kind
  of JNull: ""
  of JString: value.getStr()
  of JInt: $value.getInt()
  of JFloat: $value.getFloat()
  of JBool: $value.getBool()
  else: $value

proc truthy(value: JsonNode): bool =
  case value.kind
  of JNull: false
  of JBool: value.getBool()
  of JArray: value.len > 0
  of JString: value.getStr().len > 0
  else: true

proc renderNodes(nodes: seq[Node], stack: var seq[JsonNode], partials: Partials, output: var string) =
  for node in nodes:
    case node.kind
    of nkText:
      output.add node.text
    of nkVar:
      output.add escapeHtml(toText(lookup(stack, node.name)))
    of nkRaw:
      output.add toText(lookup(stack, node.name))
    of nkPartial:
      if partials.hasKey(node.name):
        renderNodes(partials[node.name].nodes, stack, partials, output)
    of nkInverted:
      if not truthy(lookup(stack, node.key)):
        renderNodes(node.children, stack, partials, output)
    of nkSection:
      let value = lookup(stack, node.key)
      if not truthy(value):
        continue
      if value.kind == JArray:
        for item in value:
          stack.add item
          renderNodes(node.children, stack, partials, output)
          discard stack.pop()
      elif value.kind == JObject:
        stack.add value
        renderNodes(node.children, stack, partials, output)
        discard stack.pop()
      else:
        renderNodes(node.children, stack, partials, output)

proc render*(tmpl: Template, context: JsonNode, partials: Partials = initTable[string, Template]()): string =
  var stack = @[context]
  renderNodes(tmpl.nodes, stack, partials, result)

proc render*(source: string, context: JsonNode): string =
  compile(source).render(context)

when isMainModule:
  import std/os

  if paramCount() < 1 or paramCount() > 2:
    quit("usage: lathe <template> [context.json]", 2)
  try:
    let source = readFile(paramStr(1))
    let context = if paramCount() == 2: parseFile(paramStr(2)) else: parseJson(stdin.readAll())
    stdout.write render(source, context)
  except TemplateError as error:
    quit("lathe: " & error.msg, 1)
  except IOError, JsonParsingError:
    quit("lathe: " & getCurrentExceptionMsg(), 1)


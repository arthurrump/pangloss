# Pangloss: Pandoc Glossary Filter

Pangloss is a native Pandoc glossary filter, meaning that it allows you to create glossaries for any type of output. This filter uses a markdown [definition list](https://pandoc.org/MANUAL.html#definition-lists) to create the glossary list and in-text references are all handled in the filter itself, so no external tools or LaTeX packages are required.

## Glossary definition

The terms of your glossary are defined in the metadata of the document:

```yaml
glossary:
  ast:
    name: abstract syntax tree
    abbreviation: AST
    description: An abstract graph description of a program.
  pandoc:
    name: 
      singular: Pandoc
    description: Awesome converter for documents in all formats.
  filter:
    description: >
      A filter is a way to extend (+pandoc) and make it even more awesome.
  criterion:
    name:
      singular: criterion
      plural: criteria
    description: A standard on which to base judgement or decision.
  example:
    name: example
    description: |
      Sometimes you just need an execuse to demonstrate something. An example 
      is a good way to show how something works.

      This, *for example*, is an example of using multiple paragraphs in the 
      description.

      - You could
      - also
      - include lists.
```

The glossary contains a field for each entry, with the key given as the field name. The key should be lowercase, start with a letter and contain only alphanumeric characters and the characters '-' and '_'. 

The name is the long form of the term. If it is not specified the key is also used as the name (see *filter*, for example). The name can be specified directly, or split into singular and plural forms, like in the case of *criterion*. If not specified explicitly, the plural form is inferred by appending 's' to the singular. *ast*, for example, will be written as "abstract syntax trees" when a plural is requested in the text. This can be disabled by setting only the singular form using the extended syntax, as is done with *Pandoc*. In that case, an error will be thrown if the plural form is requested. If the name is written in lowercase, the casing in the text will depend on the casing of the reference. The glossary list will automatically capitalise the first letter of the word. If capital letters are used in the term, the casing is not changed.

An abbreviation can optionally be included, either directly or split into singular and plural forms. Abbreviations always use the casing that is used in the definition, unlike names. The rules for singular and plural forms are the same as for names.

Finally, a description has to be specified. This will be parsed as markdown using Pandoc, and multiple paragraphs are also allowed. You can also make references to other terms in the description. This will be rendered correctly in the glossary lists, but not in the tooltips that are shown when links are enabled.

### Rendering the glossary

The location to render the glossary is specified in a way similar to references:

```markdown
:::{#glossary}
:::
```

It is also possible to render a list of acronyms separately:

```markdown
:::{#acronyms}
:::
```

If you don't want to render a list of acronyms, you should set the `link-to-acronyms` option to `false` in the metadata. This makes sure that acronyms are linked to the glossary, rather than the list of acronyms.

## Referencing terms in the text

TLDR: `(+[!#][-.~][^]Key)`

- `!` to override disable a link, `#` to override enable a link
- `-` to force long form, `.` to force short form, `~` to force full form
- ` ^` to request the plural form
- `key` for standard lowercase, `Key` for first letter uppercase

---

General syntax: `(+x)` where x is the key of the glossary entry. This will be expanded into:

- "abstract syntax tree (AST)", if an abbreviation is defined and this is the first occurrence in the text.
- "AST", if an abbreviation is given and the term has been used before.
- "filter" or "Pandoc", if no abbreviation is given.

Capitalization depends on the capitalization of the key in the text and on the capitalization of definitions. If `(+X)` is used, with the first (or all) characters of the key capitalised, the following output is generated:

- "Abstract syntax tree (AST)"
- "AST"
- "Filter" or "Pandoc"

Note that capitalization of the key only affects the name and not any abbreviations. If the name contains a capital letter in the definition, it will use that capitalization regardless of how the key is capitalised in the text.

### Requesting a plural

A plural can be referenced using `(+^x)`. This will use the plural version given in the definition, or simply append an 's' if none is defined.

- "Abstract syntax trees (ASTs)"
- "ASTs"
- "filters"

If only a singular is explicitly defined, an error will be thrown if the plural is requested. `(+^pandoc)` will not work, for example.

### Disabling or enabling a link

By default, Pangloss will link each reference in the text to the definition in the glossary. This can be configured globally, see [the section on configuration](#configuration), but also modified per reference.

- If automatic links are enabled, `(+!x)` will disable the link for this reference.
- If automatic links are disabled, `(+#x)` will enable the link for this reference.

The plural modifier can be used after the link modifier, e.g. `(+!^X)` to reference the plural for x, starting with a capital letter and without linking to the glossary.

### Forcing a certain form for an abbreviation

If an abbreviation is defined, the following characters can be used to force long, short or full expansions:

- `-` for the long form, e.g. "abstract syntax tree"
- `.` for the short form, e.g. "AST"
- `~` for the full form, e.g. "abstract syntax tree (AST)"

Only one of these modifiers is allowed (obviously), and it should be placed after the link modifier if present, or after the `+` sign otherwise. A `^` is allowed after the modifier to signify the plural form, e.g. `(+-^ast)` will always expand to "abstract syntax trees".|

### Overview

| Reference              | Form  | Plural | Case  | Result                       |
| ---------------------- | ----- | ------ | ----- | ---------------------------- |
| `(+ast)` (first time)  | Full  | No     | lower | abstract syntax tree (AST)   |
| `(+ast)` (others)      | Short | No     | lower | AST                          |
| `(+^ast)` (first time) | Full  | Yes    | lower | abstract syntax trees (ASTs) |
| `(+^ast)` (others)     | Short | Yes    | lower | ASTs                         |
| `(+-ast)`              | Long  | No     | lower | abstract syntax tree         |
| `(+.ast)`              | Short | No     | lower | AST                          |
| `(+~ast)`              | Full  | No     | lower | abstract syntax tree (AST)   |
| `(+-^ast)`             | Long  | Yes    | lower | abstract syntax trees        |
| `(+.^ast)`             | Short | Yes    | lower | ASTs                         |
| `(+~^ast)`             | Full  | Yes    | lower | abstract syntax trees (ASTs) |
| `(+Ast)` (first time)  | Full  | No     | Upper | Abstract syntax tree (AST)   |
| `(+Ast)` (others)      | Short | No     | Upper | AST                          |
| `(+^Ast)` (first time) | Full  | Yes    | Upper | Abstract syntax trees (ASTs) |
| `(+^Ast)` (others)     | Short | Yes    | Upper | ASTs                         |
| `(+-Ast)`              | Long  | No     | Upper | Abstract syntax tree         |
| `(+.Ast)`              | Short | No     | Upper | AST                          |
| `(+~Ast)`              | Full  | No     | Upper | Abstract syntax tree (AST)   |
| `(+-^Ast)`             | Long  | Yes    | Upper | Abstract syntax trees        |
| `(+.^Ast)`             | Short | Yes    | Upper | ASTs                         |
| `(+~^Ast)`             | Full  | Yes    | Upper | Abstract syntax trees (ASTs) |

## Configuration

Pangloss can be configured through metadata. Below is the default configuration, documented with the available options.

```yaml
pangloss:
  # Automatically link a term in the text to the definition in the glossary.
  auto-links: true # true | false
  # Include a title in the link, which will be displayed on hover in HTML
  # output. The title is based on the description of the item.
  link-titles: true # true | false
  # Link abbreviated forms to the acronyms list rather than the glossary.
  link-to-acronyms: true # true | false
  # Link only the first linkable mention of a term in each paragraph. If 
  # the first use is suppressed using `!`, the second use will be linked, etc.
  link-only-once: false # true | false
```


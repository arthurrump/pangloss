---
pangloss:
  link-only-once: true
glossary:
  ast:
    name: abstract syntax tree
    abbreviation: AST
    description: An abstract graph description of a program.
  cs:
    name:
      singular: Computer Science
    abbreviation:
      singular: CS
    description: A study with a singular acronym and title-cased name.
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
---

# Content

This is a test file for a (+pandoc) (+filter). (+^Filter) are pretty cool. (+Pandoc) will translate this document to an (+ast), which is then passed to the Pangloss (+filter). Pangloss walks over the (+ast) and replaces the references with the proper term and expansion of acronyms. It also creates a link to the glossary entry for that term. It also finds the proper location in the (+-ast) to insert the glossary. For acronyms, the first use of (+cs) is automatically expanded, and later uses of (+cs) will use the abbreviation. We can also force this: (+.cs), (+-cs), (+~cs).

Weird things may (but should not) happen is a term is included in another word, like with test(+pandoc), (+pandoc)(+filter) or (+pandoc)-(+filter). Linking to a term can be disabled, as in this (+!example). Or enabled, if we disabled it globally, like in these (+#^example), (+#criterion).

This paragraph references (+pandoc) multiple times, because (+pandoc) is such a lovely program. Only the first mention of (+pandoc) should be linked to the glossary entry, if that option is enabled.

In the next paragraph (+pandoc) should be linked again, but only for the first time (+pandoc) is mentioned, except when a forced link to (+#pandoc) is used.

```{=latex}
\pagebreak
```
```{=html}
<div style="height: 100vh"></div>
```

# Acronyms

:::{#acronyms}
:::

```{=latex}
\pagebreak
```
```{=html}
<div style="height: 100vh"></div>
```

# Glossary

:::{#glossary}
This content will be removed.
:::

# Appendix

A weird thing happened once when referencing a singular abbreviation with a title-cased name after the glossary with the long ((+!-cs)) or full ((+!~cs)) references, so this appendix is here to make sure that doesn't happen.

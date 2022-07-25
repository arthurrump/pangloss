---
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
---

# Content

This is a test file for a (+pandoc) (+filter). (+^Filter) are pretty cool. (+Pandoc) will translate this document to an (+ast), which is then passed to the Pangloss (+filter). Pangloss walks over the (+ast) and replaces the references with the proper term and expansion of acronyms. It also creates a link to the glossary entry for that term. It also finds the proper location in the (+-ast) to insert the glossary.

Weird things may (but should not) happen is a term is included in another word, like with test(+pandoc), (+pandoc)(+filter) or (+pandoc)-(+filter). Linking to a term can be disabled, as in this (+!example). Or enabled, if we disabled it globally, like in these (+#^example), (+#criterion).

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
# Pangloss: Pandoc Glossary Filter

Pangloss is a native Pandoc glossary filter, meaning that it allows you to create glossaries for any type of output. This filter uses a markdown [definition list](https://pandoc.org/MANUAL.html#definition-lists) to create the glossary list and in-text references are all handled in the filter itself, so no external tools or LaTeX packages are required.

## Usage

1. Create a glossary list in the metadata.

   ```yaml
   glossary:
     ilo:
       name: 
         singular: intended learning outcome
         plural: intended learning outcomes
       abbreviation:
         singular: ILO
         plural: ILOs
       description: >
         What a student is expected to know or be able to do at
         the end of a course.
     pandoc:
       name: Pandoc
       description: Converter for documents in all formats.
     filter:
       description: A filter is like a plugin for (+pandoc).
   ```

   The glossary contains a field for each entry, with the key given as the field name. The key should be lowercase, start with a letter and contain only alphanumeric characters, '-' and '_'. 
   
   The name is the long form of the term, if it is not specified the key is also used as the name. It can be specified directly, or split into singular and plural forms. If specified directly, the plural form is inferred by appending 's' to the singular. This can be disabled by explicitly only the singular form using the extended syntax. In that case, an error will be thrown if the plural form is requested. If the name is written in lowercase, casing in the text will depend on the casing of the reference. The glossary list will automatically capitalise the first letter of the word. If capital letters are used in the term, the casing is not changed.
   
   An abbreviation can optionally be included, either directly or split into singular and plural forms. Abbreviations always use the casing that is used in the definition, unlike names. The rules for singular and plural forms are the same as for names.
   
   Finally, a description has to be specified. This will be parsed as markdown using Pandoc.
   
2. Create a location in your document to place the glossary, similar to how a custom location can be defined for references.

   ```markdown
   :::{#glossary}
   :::
   ```

3. Refer to the identifiers in your document.

   General syntax: `(+x)` where x is the id of the glossary entry. This will be expanded into:

   - "intended learning outcome (ILO)", if an abbreviation is given and this is the first occurrence in the text.
   - "ILO", if an abbreviation is given and the term has been used before.
   - "filter" or "Pandoc", if no abbreviation is given.

   Capitalization depends on the capitalization of the id in the text and on the capitalization of definitions. If `(+X)` is used, with the first (or all) characters of the id capitalised, the following output is generated:

   - "Intended learning outcome (ILO)"
   - "ILO"
   - "Filter" or "Pandoc"

   Note that capitalization of the key only affects the name and not any abbreviations. If the name contains a capital letter in the definition, it will use that capitalization regardless of how the id is capitalised in the text.

   A plural can be referenced using `(+^x)`. This will use the plural version given in the definition, or simply append an 's' if none is defined.

   - "intended learning outcomes (ILOs)"
   - "ILOs"
   - "filters" or "Pandocs"

   If an abbreviation is defined, the following characters can be used to force long, short or full expansions:

   - `-` for the long form, e.g. "intended learning outcome"
   - `.` for the short form, e.g. "ILO"
   - `~` for the full form, e.g. "intended learning outcome (ILO)"

   Only one of these modifiers is allowed (obviously), and it should be placed directly after the `+` sign. A `^` is allowed after the modifier to signify use of the plural form, e.g. `(+.^ilo)` will always expand to "ILOs".
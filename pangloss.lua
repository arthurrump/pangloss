--[[----------------------------------------------------------------------------
Pangloss: Pandoc Glossary Filter
Copyright 2022, Arthur Rump
Licensed under the BSD 2-Clause License

This work is inspired by:
- https://github.com/Enet4/pandoc-ac
- https://github.com/kprussing/pandoc-acro
- https://github.com/hippwn/pandoc-glossaries
- https://github.com/tomncooper/pandoc-gls
--]]----------------------------------------------------------------------------

--[[----------------------------------------------------------------------------
Usage:
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

   The glossary contains a field for each entry, with the key given as the field
   name. The key should be lower case, start with a letter and contain only
   alphanumeric characters, '-' and '_'. 

   The name is the long form of the term, if it is not specified the key is also
   used as the name. It can be specified directly, or split into singular and
   plural forms. If specified directly, the plural form is inferred by appending
   's' to the singular. This can be disabled by explicitly only the singular
   form using the extended syntax. In that case, an error will be thrown if the
   plural form is requested. If the name is written in lowercase, casing in the
   text will depend on the casing of the reference. The glossary list will
   automatically capitalise the first letter of the word. If capital letters are
   used in the term, the casing is not changed.

   An abbreviation can optionally be included, either directly or split into
   singular and plural forms. Abbreviations always use the casing that is used
   in the definition, unlike names. The rules for singular and plural forms are
   the same as for names.

   Finally, a description has to be specified. This will be parsed as markdown
   using Pandoc.

2. Create a location in your document to place the glossary, similar to how a
   custom location can be defined for your references.

   ```markdown
   :::{#glossary}
   :::
   ```

3. Refer to the identifiers in your document.

   General syntax: `(+x)` where x is the id of the glossary entry. This will be
   expanded into:

   - "intended learning outcome (ILO)", if an abbreviation is given and this is
     the first occurence in the text.
   - "ILO", if an abbreviation is given and the term has been used before.
   - "filter" or "Pandoc", if no abbreviation is given.

   Capitalization depends on the capitalization of the id in the text and on the
   capitalization of definitions. If `(+X)` is used, with the first (or all)
   characters of the id capitalized, the following output is generated:

   - "Intended learning outcome (ILO)"
   - "ILO"
   - "Filter" or "Pandoc"

   Note that capitalization of the key only affects the name and not any
   abbreviations. If the name contains a capital letter in the definition, it
   will use that capitalization regardless of how the id is capitalized in the
   text.

   A plural can be referenced using `(+^x)`. This will use the plural version
   given in the definition, or simply append an 's' if none is defined.

   - "intended learning outcomes (ILOs)"
   - "ILOs"
   - "filters" or "Pandocs"

   If an abbreviation is defined, the following characters can be used to force
   long, short or full expansions:

   - `-` for the long form, e.g. "intended learning outcome"
   - `.` for the short form, e.g. "ILO"
   - `~` for the full form, e.g. "intended learning outcome (ILO)"

   Only one of these modifiers is allowed (obviously), and it should be placed
   directly after the `+` sign. A `^` is allowed after the modifier to signify
   use of the plural form, e.g. `(+.^ilo)` will always expand to "ILOs".

--]]----------------------------------------------------------------------------

-- Table to store glossary entries read from metadata.
local glossary = {}
-- Table used to track which acronyms have already been used, to enable
-- automatic expansion on first use only.
local usedTracker = {}

-- Options for paring markdown are copied from the standard and then standalone
-- is disabled to ensure that it can be included in the current document. This
-- is not used often, probably only when a key is translated to inlines...
--
-- TODO: Maybe better to remove this and just use Inlines to create proper
-- Pandoc AST for the keys, since all values are automatically parsed by Pandoc.
-- Keys are very restricted, so this is a bit overkill. Needs some testing to
-- verify this though.
local readerOptions = pandoc.ReaderOptions(PANDOC_READER_OPTIONS)
readerOptions.standalone = false

-- Simple function to dump a table to a string for debugging purposes.
local function dump(obj)
    local function dumprec(object, indent)
        if type(object) == 'table' then
            if #object == 0 then
                return "{}"
            else
                local result = '{'
                for key, value in pairs(object) do
                    result = result ..  '\n' .. string.rep('  ', indent) .. '[' .. key .. '] = ' .. dumprec(value, indent + 1) .. ','
                end
                return string.sub(result, 1, #result - 1) .. '\n' .. string.rep('  ', indent - 1) .. '}'
            end
        elseif object == nil then
            return 'nil'
        else
            return '"' .. pandoc.utils.stringify(object) .. '"'
        end
    end
    return dumprec(obj, 0)
 end

local function isInlineText(elem)
    return pandoc.utils.type(elem) == "string" or
           pandoc.utils.type(elem) == "Inlines"
end

local function isExplicitPluralTable(elem)
    return pandoc.utils.type(elem) == "table" and
           elem.singular ~= nil and
           isInlineText(elem.singular)
end

local function isBlockText(elem)
    return isInlineText(elem) or
           pandoc.utils.type(elem) == "Blocks"
end

local function toInlines(elem)
    if pandoc.utils.type(elem) == "Inlines" then
        return elem
    elseif pandoc.utils.type(elem) == "string" then
        local doc = pandoc.read(elem, "markdown", readerOptions)
        if #doc.blocks ~= 1 then
            error("Glossary: failed to parse '" .. elem .. "' as inline markdown. It contains more or less than one block.")
        end

        local block = doc.blocks[1]
        if block.t == "Para" or block.t == "Plain" or block.t == "Header" then
            return block.content
        else
            error("Glossary: failed to parse '" .. elem .. "' as inline markdown. It contains a block of type '" .. block.t .. "'.")
        end
    else
        error("Unable to convert element of type " .. pandoc.utils.type(elem) .. " (value: '" .. elem .. "') to Inlines.")
    end
end

local function toBlocks(elem)
    if pandoc.utils.type(elem) == "Blocks" then
        return elem
    elseif pandoc.utils.type(elem) == "Inlines" then
        return pandoc.Para(elem)
    elseif pandoc.utils.type(elem) == "string" then
        local doc = pandoc.read(elem, "markdown", readerOptions)
        return doc.blocks
    else
        error("Unable to convert element of type " .. pandoc.utils.type(elem) .. " (value: '" .. elem .. "') to Blocks.")
    end
end

local function pluralise(text)
    if pandoc.utils.type(text) == "Inlines" then
        local appended = text:clone()
        appended:insert(pandoc.Str("s"))
        return appended
    elseif pandoc.utils.type(text) == "string" then
        return text .. "s"
    else
        error("Cannot pluralise something of type " .. pandoc.utils.type(text) .. " (value: '" .. text .. "').")
    end
end

local function isLower(text)
    local plain = pandoc.utils.stringify(text)
    return plain:lower() == plain
end

local function capitalise(text)
    if pandoc.utils.type(text) == "Inlines" then
        local done = false
        return text:walk({
            Str = function (str)
                if not done then
                    done = true
                    return pandoc.Str(capitalise(str.text))
                end
            end
        })
    elseif pandoc.utils.type(text) == "string" then
        return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
    else
        error("Cannot capitalise something of type " .. pandoc.utils.type(text) .. " (value: '" .. text .. "').")
    end
end

local function capitaliseIfLower(text)
    if isLower(text) then
        return capitalise(text)
    else
        return text
    end
end

-- Retrieve the glossary from the metadata
function ReadGlossary(meta)
    if pandoc.utils.type(meta.glossary) == "table" then
        for key, entry in pairs(meta.glossary) do
            if key:find("^%l[%l%d%_%-]*$") ~= 1 then
                error("Glossary key must start with a letter and contain only lowercase letters, digits, '-' and '_'. Found invalid key: " .. key)
            end

            glossary[key] = { name = {} }
            usedTracker[key] = false

            if entry.name == nil then
                glossary[key].name.singular = toInlines(key)
                glossary[key].name.plural = toInlines(pluralise(key))
            elseif isInlineText(entry.name) then
                glossary[key].name.singular = toInlines(entry.name)
                glossary[key].name.plural = toInlines(pluralise(entry.name))
            elseif isExplicitPluralTable(entry.name) then
                glossary[key].name.singular = toInlines(entry.name.singular)

                if entry.name.plural then
                    if not isInlineText(entry.name.plural) then
                        error("Glossary entry '" .. key .. "' has invalid plural name. Should be inline text or nil, but is of type " .. pandoc.utils.type(entry.name.plural))
                    end
                    glossary[key].name.plural = toInlines(entry.name.plural)
                end
            else
                error("Glossary entry '" .. key .. "' has invalid name. Should be inline text, explicit plural table or nil, but is of type " .. pandoc.utils.type(entry.name))
            end

            if isInlineText(entry.abbreviation) then
                glossary[key].abbreviation = {}
                glossary[key].abbreviation.singular = toInlines(entry.abbreviation)
                glossary[key].abbreviation.plural = toInlines(pluralise(entry.abbreviation))
            elseif isExplicitPluralTable(entry.abbreviation) then
                glossary[key].abbreviation = {}
                glossary[key].abbreviation.singular = toInlines(entry.abbreviation.singular)

                if entry.abbreviation.plural then
                    if not isInlineText(entry.abbreviation.plural) then
                        error("Glossary entry '" .. key .. "' has invalid plural abbreviation. Should be a inline text or nil, but is of type " .. pandoc.utils.type(entry.abbreviation.plural))
                    end
                    glossary[key].abbreviation.plural = toInlines(entry.abbreviation.plural)
                end
            elseif entry.abbreviation ~= nil then
                error("Glossary entry '" .. key .. "' has invalid abbreviation. Should be inline text, explicit plural table or nil, but is of type " .. pandoc.utils.type(entry.abbreviation))
            end

            if not isBlockText(entry.description) then
                error("Glossary entry '" .. key .. "' has invalid description. Should be block text, but is of type " .. pandoc.utils.type(entry.description))
            end
            glossary[key].description = toBlocks(entry.description)
        end
    else
        error("No or invalid glossary found. The glossary should be of type `table`, but got: " .. pandoc.utils.type(meta.glossary))
    end
end

local function getPluralised(pluralMod, explicitPluralTable)
    if pluralMod == "" then
        return explicitPluralTable.singular
    elseif pluralMod == "^" then
        if explicitPluralTable.plural then
            return explicitPluralTable.plural
        else
            error("No plural version of '" .. explicitPluralTable.singular .. "' found.")
        end
    else
        error("Invalid plural modifier: " .. pluralMod)
    end
end

local function getCapitalised(key, name)
    if isLower(key) then
        return name
    else
        return capitaliseIfLower(name)
    end
end

local function getReference(abbrMod, pluralMod, key)
    local lookup = string.lower(key)
    local entry = glossary[lookup]
    if entry == nil then
        error("There is no entry for " .. key .. " in the glossary.")
    end

    if entry.abbreviation then
        if abbrMod == "~" or (abbrMod == "" and not usedTracker[lookup]) then
            -- Full form
            local name = getCapitalised(key, getPluralised(pluralMod, entry.name))
            local abbr = getPluralised(pluralMod, entry.abbreviation)
            local result = name:clone()
            result:extend({ pandoc.Space(), pandoc.Str("(") })
            result:extend(abbr)
            result:insert(pandoc.Str(")"))
            usedTracker[lookup] = true
            return result
        elseif abbrMod == "." or (abbrMod == "" and usedTracker[lookup]) then
            -- Short form
            return getPluralised(pluralMod, entry.abbreviation)
        elseif abbrMod == "-" then
            -- Long form
            return getCapitalised(key, getPluralised(pluralMod, entry.name))
        else
            error("Unrecognized abbreviation modifier '" .. abbrMod .. "'.")
        end
    else
        return getCapitalised(key, getPluralised(pluralMod, entry.name))
    end
end

-- Replace the glossary terms in the text
function ReplaceInlineTerm(str)
    if string.find(str.text, "%(%+") then
        local result = pandoc.List()
        local cursor = 1
        for startMatch, abbrMod, pluralMod, key, endMatch in str.text:gmatch("()%(%+([%-%.%~]?)(%^?)(%a[%w%-%_]*)%)()") do
            if cursor < startMatch then result:insert(pandoc.Str(str.text:sub(cursor, startMatch - 1))) end
            result:extend(getReference(abbrMod, pluralMod, key))
            cursor = endMatch
        end

        if cursor <= #str.text then
            result:insert(pandoc.Str(str.text:sub(cursor)))
        end

        return result
    end
end

local function pairsInOrder(t, comparer)
    local orderedKeys = {}
    for key, _ in pairs(t) do
        table.insert(orderedKeys, key)
    end
    table.sort(orderedKeys, function (keyA, keyB) return comparer(t[keyA], t[keyB]) end)
    local i = 0
    return function ()
        i = i + 1
        if orderedKeys[i] == nil then return nil
        else return orderedKeys[i], t[orderedKeys[i]] 
        end
    end
end

local function entryComparisonKey(entry)
    if entry.abbreviation then
        return entry.abbreviation.singular
    else
        return entry.name.singular
    end
end

local function entryComparer(a, b)
    local lexA = string.upper(pandoc.utils.stringify(entryComparisonKey(a)))
    local lexB = string.upper(pandoc.utils.stringify(entryComparisonKey(b)))
    return lexA < lexB
end

-- Replace the glossary block with a definition list
function ReplaceGlossaryBlock(div)
    if div.identifier == "glossary" then
        local def = {}
        for key, entry in pairsInOrder(glossary, entryComparer) do
            local description = entry.description:walk({ Str = ReplaceInlineTerm })
            if entry.abbreviation then
                local title = entry.abbreviation.singular:clone()
                title:extend({ pandoc.Space(), pandoc.Str("(") })
                title:extend(capitaliseIfLower(entry.name.singular))
                title:insert(pandoc.Str(")"))
                table.insert(def, { pandoc.Inlines(title), { description } })
            else
                table.insert(def, { capitaliseIfLower(entry.name.singular), { description } })
            end
        end
        div.content = pandoc.Blocks(pandoc.DefinitionList(def))
        return div
    end
end

return {
    -- First execute the filter on metadata to parse the glossary
    { Meta = ReadGlossary },
    -- Then walk over the document, replacing inline terms and the glossary block
    { Str = ReplaceInlineTerm, Div = ReplaceGlossaryBlock }
}

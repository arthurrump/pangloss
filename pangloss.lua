--[[----------------------------------------------------------------------------
Pangloss: Pandoc Glossary Filter
Copyright 2022, Arthur Rump
Licensed under the BSD 2-Clause License

See README.md for information on usage and configuration.

This work is inspired by:
- https://github.com/Enet4/pandoc-ac
- https://github.com/kprussing/pandoc-acro
- https://github.com/hippwn/pandoc-glossaries
- https://github.com/tomncooper/pandoc-gls
--]]----------------------------------------------------------------------------

-- Table to store glossary entries read from metadata.
local glossary = {}
-- Table used to track which acronyms have already been used, to enable
-- automatic expansion on first use only.
local usedTracker = {}
-- Table used to track which terms have been used in the current paragraph,
-- to enable linking only the first use back to the glossary.
local linkedInParaTracker = {}

-- Table for configuration options.
local config = {
    -- Automatically link a term in the text to the definition in the glossary.
    ["auto-links"] = true,
    -- Include a title in the link, which will be displayed on hover in HTML
    -- output. The title is based on the description of the item.
    ["link-titles"] = true,
    -- Link abbreviated forms to the acronyms list rather than the glossary.
    ["link-to-acronyms"] = true,
    -- Link only the first linkable mention of a term in each paragraph. If the
    -- first use is suppressed using `!`, the second use will be linked, etc.
    ["link-only-once"] = false
}

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
        return pandoc.Blocks(pandoc.Para(elem))
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

-- Read the configuration options from the metadata.
function ReadConfig(meta)
    if meta.pangloss then
        if meta.pangloss["auto-links"] ~= nil then
            config["auto-links"] = meta.pangloss["auto-links"]
        end
        if meta.pangloss["link-titles"] ~= nil then
            config["link-titles"] = meta.pangloss["link-titles"]
        end
        if meta.pangloss["link-to-acronyms"] ~= nil then
            config["link-to-acronyms"] = meta.pangloss["link-to-acronyms"]
        end
        if meta.pangloss["link-only-once"] ~= nil then
            config["link-only-once"] = meta.pangloss["link-only-once"]
        end
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
            local description = toBlocks(entry.description)
            glossary[key].description = description
            local shortDescription = pandoc.utils.blocks_to_inlines({ description[1] })
            if #glossary[key].description > 1 then
                shortDescription:extend({ pandoc.Space(), pandoc.Str("...") })
            end
            glossary[key].shortDescription = pandoc.utils.stringify(shortDescription)
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

local function getReference(linkMod, abbrMod, pluralMod, key)
    local lookup = string.lower(key)
    local entry = glossary[lookup]
    if entry == nil then
        error("There is no entry for " .. key .. " in the glossary.")
    end

    local linkTitle = ""
    if config["link-titles"] then
        linkTitle = entry.shortDescription
    end

    local content
    local linkDestination = "glossary"
    if entry.abbreviation then
        if abbrMod == "~" or (abbrMod == "" and not usedTracker[lookup]) then
            -- Full form
            local name = getCapitalised(key, getPluralised(pluralMod, entry.name))
            local abbr = getPluralised(pluralMod, entry.abbreviation)
            
            content = name:clone()
            content:extend({ pandoc.Space(), pandoc.Str("(") })
            content:extend(abbr)
            content:insert(pandoc.Str(")"))

            usedTracker[lookup] = true
        elseif abbrMod == "." or (abbrMod == "" and usedTracker[lookup]) then
            -- Short form
            content = getPluralised(pluralMod, entry.abbreviation)
            if config["link-titles"] then
                linkTitle = 
                    pandoc.utils.stringify(capitaliseIfLower(getPluralised(pluralMod, entry.name)))
                    .. ". " 
                    .. linkTitle
            end
            if config["link-to-acronyms"] then
                linkDestination = "acronyms"
            end
        elseif abbrMod == "-" then
            -- Long form
            content = getCapitalised(key, getPluralised(pluralMod, entry.name))
        else
            error("Unrecognized abbreviation modifier '" .. abbrMod .. "'.")
        end
    else
        content = getCapitalised(key, getPluralised(pluralMod, entry.name))
    end

    -- Create a link if auotmatic links are enabled, this specific link is not
    -- suppressed and everything should be linked or this is the first linking
    -- in this paragraph; or if this link is explicitly enabled.
    if (config["auto-links"] and linkMod ~= "!" and (not config["link-only-once"] or not linkedInParaTracker[lookup])) or linkMod == "#" then
        linkedInParaTracker[lookup] = true
        return pandoc.Inlines(pandoc.Link(content, "#" .. linkDestination .. "-" .. lookup, linkTitle, { class = "glossary-link" }))
    else
        return content
    end
end

-- Replace the glossary terms in the text
function ReplaceInlineTerm(str)
    if string.find(str.text, "%(%+") then
        local result = pandoc.List()
        local cursor = 1
        for startMatch, linkMod, abbrMod, pluralMod, key, endMatch in str.text:gmatch("()%(%+([%!%#]?)([%-%.%~]?)(%^?)(%a[%w%-%_]*)%)()") do
            if cursor < startMatch then result:insert(pandoc.Str(str.text:sub(cursor, startMatch - 1))) end
            result:extend(getReference(linkMod, abbrMod, pluralMod, key))
            cursor = endMatch
        end

        if cursor <= #str.text then
            result:insert(pandoc.Str(str.text:sub(cursor)))
        end

        return result
    end
end

local function pairsInOrder(t, comparer, filter)
    local orderedKeys = {}
    for key, value in pairs(t) do
        if filter == nil or filter(key, value) then
            table.insert(orderedKeys, key)
        end
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

local function getName(entry)
    return entry.name.singular
end

local function getAbbreviation(entry)
    if entry.abbreviation then
        return entry.abbreviation.singular
    end
end

local function entryComparer(select)
    return
        function (a, b)
            local lexA = string.upper(pandoc.utils.stringify(select(a)))
            local lexB = string.upper(pandoc.utils.stringify(select(b)))
            return lexA < lexB
        end
end

-- Replace the glossary block with a definition list
local function replaceGlossaryBlock(div)
    if div.identifier == "glossary" then
        local def = {}
        for key, entry in pairsInOrder(glossary, entryComparer(getName)) do
            local description = entry.description:walk({ Str = ReplaceInlineTerm })
            local title = capitaliseIfLower(entry.name.singular:clone())
            if entry.abbreviation then
                title:extend({ pandoc.Space(), pandoc.Str("(") })
                title:extend(entry.abbreviation.singular)
                title:insert(pandoc.Str(")"))
                title = pandoc.Inlines(title)
            end
            title = pandoc.Span(title, { id = "glossary-" .. key })
            table.insert(def, { title, { description } })
        end
        return pandoc.DefinitionList(def)
    end
end

-- Replace the acronyms block with a definition list
local function replaceAcronymsBlock(div)
    if div.identifier == "acronyms" then
        local def = {}
        for key, entry in pairsInOrder(glossary, entryComparer(getAbbreviation), function (_, entry) return entry.abbreviation ~= nil end) do
            local abbrev = capitaliseIfLower(entry.abbreviation.singular)
            local title = pandoc.Span(abbrev, { id = "acronyms-" .. key })
            local name = capitaliseIfLower(entry.name.singular)
            local content = pandoc.Para(pandoc.Link(name, "#glossary-" .. key, entry.shortDescription, { class = "glossary-link" }))
            table.insert(def, { title, { content } })
        end
        return pandoc.DefinitionList(def)
    end
end

function ReplaceDefinitionBlocks(div)
    return replaceGlossaryBlock(div) or replaceAcronymsBlock(div)
end

return {
    -- First, extract the pangloss configuration from metadata,
    { Meta = ReadConfig },
    -- then execute the filter on metadata to parse the glossary,
    { Meta = ReadGlossary },
    -- and finally walk over the document, replacing inline terms and the
    -- glossary and acronyms blocks. This traversal is top-down, to reset the
    -- usedInParaTracker each time a new paragraph is entered
    { traverse = "topdown",
      Str = ReplaceInlineTerm,
      Div = ReplaceDefinitionBlocks,
      Para = function (para)
          linkedInParaTracker = {}
      end }
}

--- This module convert the filter rules exported from GMail into some Lua
-- structures.
--
-- It is intended to be used with notmuch to replicate the labels locally and
-- make sure they are in sync.

local ffi = require("ffi")
local io = io

local libxml = ffi.load("libxml2")

local c_head = [[
    typedef struct {} xmlParserInputPtr;
    typedef struct {} xmlParserNodeInfoSeq;
    typedef struct {} xmlValidCtxt;
    typedef struct {} xmlParserInputState;
    typedef struct {} xmlDictPtr;
    typedef struct {} xmlHashTablePtr;
    typedef struct {} xmlAttrPtr;
    typedef struct {} xmlError;
    typedef struct {} xmlParserMode;
    typedef struct {} xmlParserNodeInfo;
    typedef unsigned char xmlChar;

    typedef enum {
        XML_ELEMENT_NODE=		1,
        XML_ATTRIBUTE_NODE=		2,
        XML_TEXT_NODE=		3,
        XML_CDATA_SECTION_NODE=	4,
        XML_ENTITY_REF_NODE=	5,
        XML_ENTITY_NODE=		6,
        XML_PI_NODE=		7,
        XML_COMMENT_NODE=		8,
        XML_DOCUMENT_NODE=		9,
        XML_DOCUMENT_TYPE_NODE=	10,
        XML_DOCUMENT_FRAG_NODE=	11,
        XML_NOTATION_NODE=		12,
        XML_HTML_DOCUMENT_NODE=	13,
        XML_DTD_NODE=		14,
        XML_ELEMENT_DECL=		15,
        XML_ATTRIBUTE_DECL=		16,
        XML_ENTITY_DECL=		17,
        XML_NAMESPACE_DECL=		18,
        XML_XINCLUDE_START=		19,
        XML_XINCLUDE_END=		20
    } xmlElementType;

    typedef unsigned int xmlNsType;

    typedef struct {
        struct _xmlNs  *next;	/* next Ns link for this node  */
        xmlNsType      type;	/* global or local */
        const xmlChar *href;	/* URL for the namespace */
        const xmlChar *prefix;	/* prefix for the namespace */
        void           *_private;   /* application data */
        struct _xmlDoc *context;		/* normally an xmlDoc */
    } xmlNs;

    typedef struct {
        void           *_private;	/* application data */
        xmlElementType   type;	/* type number, must be second ! */
        const xmlChar   *name;      /* the name of the node, or the entity */
        struct _xmlNode *children;	/* parent->childs link */
        struct _xmlNode *last;	/* last child link */
        struct _xmlNode *parent;	/* child->parent link */
        struct _xmlNode *next;	/* next sibling link  */
        struct _xmlNode *prev;	/* previous sibling link  */
        struct _xmlDoc  *doc;	/* the containing document */

        /* End of common part */
        xmlNs           *ns;        /* pointer to the associated namespace */
        xmlChar         *content;   /* the content */
        struct _xmlAttr *properties;/* properties list */
        xmlNs           *nsDef;     /* namespace definitions on this node */
        void            *psvi;	/* for type/PSVI informations */
        unsigned short   line;	/* line number */
        unsigned short   extra;	/* extra data for XPath/XSLT */
    } xmlNode;

    typedef xmlNode *xmlNodePtr;

    typedef struct {
        void           *_private;	/* application data */
        xmlElementType  type;       /* XML_DOCUMENT_NODE, must be second ! */
        char           *name;	/* name/filename/URI of the document */
        struct _xmlNode *children;	/* the document tree */
        struct _xmlNode *last;	/* last child link */
        struct _xmlNode *parent;	/* child->parent link */
        struct _xmlNode *next;	/* next sibling link  */
        struct _xmlNode *prev;	/* previous sibling link  */
        struct _xmlDoc  *doc;	/* autoreference to itself */

        /* End of common part */
        int             compression;/* level of zlib compression */
        int             standalone; /* standalone document (no external refs)
                        1 if standalone="yes"
                        0 if standalone="no"
                        -1 if there is no XML declaration
                        -2 if there is an XML declaration, but no
                        standalone attribute was specified */
        struct _xmlDtd  *intSubset;	/* the document internal subset */
        struct _xmlDtd  *extSubset;	/* the document external subset */
        struct _xmlNs   *oldNs;	/* Global namespace, the old way */
        const xmlChar  *version;	/* the XML version string */
        const xmlChar  *encoding;   /* external initial encoding, if any */
        void           *ids;        /* Hash table for ID attributes if any */
        void           *refs;       /* Hash table for IDREFs attributes if any */
        const xmlChar  *URL;	/* The URI for that document */
        int             charset;    /* encoding of the in-memory content
                    actually an xmlCharEncoding */
        struct _xmlDict *dict;      /* dict used to allocate names or NULL */
        void           *psvi;	/* for type/PSVI informations */
        int             parseFlags;	/* set of xmlParserOption used to parse the
                    document */
        int             properties;	/* set of xmlDocProperties for this document
                    set at the end of parsing */
    } xmlDoc;

    typedef xmlDoc *xmlDocPtr;

    void xmlCleanupParser(void);
    void xmlMemoryDump(void);
    void xmlFreeDoc(xmlDocPtr cur);
    xmlDocPtr xmlParseFile(const char *filename);
    xmlNodePtr xmlDocGetRootElement(const xmlDoc *doc);
    int xmlStrlen(const xmlChar *str);
    xmlNodePtr xmlNextElementSibling(xmlNodePtr node);
    xmlNodePtr xmlFirstElementChild(xmlNodePtr parent);
    unsigned long xmlChildElementCount(xmlNodePtr parent);
    xmlChar * xmlNodeGetContent(const xmlNode *cur);
    xmlAttrPtr xmlHasProp(const xmlNode *node, const xmlChar *name);
    xmlChar * xmlGetProp(const xmlNode *node, const xmlChar *name);
]]
ffi.cdef(c_head)

local imported = false

local function import_xml(path)
    -- Create a Lua table out of the XML content

    local parse = nil
    parse = function(cur)
        local parent = {
            name = ffi.string(cur.name)
        }

        cur = libxml.xmlFirstElementChild(cur)

        while cur ~= nil do
            local this = {}
            if tonumber(libxml.xmlChildElementCount(cur)) > 0 then
                table.insert(parent, parse(cur))
            else
                local content = ffi.string(libxml.xmlNodeGetContent(cur))
                if content ~= "" then
                    parent[ffi.string(cur.name)] = content
                elseif ffi.string(cur.name) == "property" then
                    local prop = libxml.xmlHasProp(cur, "name")
                    if prop ~= nil then
                        local name  = ffi.string(libxml.xmlGetProp(cur, "name" ))
                        local value = ffi.string(libxml.xmlGetProp(cur, "value"))
                        parent[name] = value
                    end
                elseif ffi.string(cur.name) == "category" then
                    parent["category"] = ffi.string(libxml.xmlGetProp(cur, "term"))
                else
                    --TODO print (ffi.string(cur.name))
                end
            end
            cur = libxml.xmlNextElementSibling(cur)
        end

        return parent
    end

    local doc = libxml.xmlParseFile(path)
    assert(doc)

    local cur = libxml.xmlDocGetRootElement(doc)
    assert(cur)

    local rules = parse(cur)

    libxml.xmlFreeDoc(doc)
    libxml.xmlCleanupParser()
    libxml.xmlMemoryDump()

    imported = true

    return rules
end

-- Map GMail (key) filter properties to NotMuch (value)

local mapping = {
    from       = "from",
    to         = "to",
    subject    = "subject",
    attachment = "attachment",
    mimetype   = "mimetype",
    label      = "tag",
    date       = "date",
    hasTheWord = "",

--TODO
--     id         = "",
--     thread     = "",
--     path       = "",
--     folder     = "",
--     lastmod    = "",
--     query      = "",
--     property   = "",
}

local function find_next_logical(str, start_at)
    if not start_at then return end

    local start , stop  = str:find(" AND ", start_at)
    local start2, stop2 = str:find(" OR " , start_at)

    if (not start) and not (start2) then
        return str:sub(start_at, str:len()), nil, ""
    end

    if start and not start2 then
        return str:sub(start_at, start-1), stop+1, " AND "
    end

    if start2 and not start then
        return str:sub(start_at, start2-1), stop2+1, " OR "
    end

    if start < start2 then
        return str:sub(start_at, start-1), stop+1, " AND "
    end

    return str:sub(start_at, start2-1), stop2+1, " OR "
end

local function get_as_keys(str)
    local ret, substr, pos, sep = {}, find_next_logical(str, 1)

    while substr do
        ret[substr] = true
        substr, pos, sep = find_next_logical(str, pos)
    end

    return ret
end

-- GMail XML stores the prefix as the property name and the value can have:
-- AND OR XOR between terms. Notmuch queries need the prefix in front of each
-- terms.
local function format_multi(prefix, str)
    local ret, substr, pos, sep = "", find_next_logical(str, 1)

    while substr do
        ret = ret..prefix..":"..substr..sep
        substr, pos, sep = find_next_logical(str, pos)
    end

    return ret
end

local rules = nil

local module = {}

-- Generate Notmuch queries
function module.get_queries()
    assert(rules, "Please set the xml path before calling this")
    local queries = {}

    for _, v in ipairs(rules) do
        local query, tags = "", {}

        if v.category == "filter" then
            for prop, val in pairs(v) do
                if prop == "label" then
                    tags = get_as_keys(val or "")
                elseif mapping[prop] then
                    local components = {}
                    query = format_multi(mapping[prop], val or "")
                end
            end

            if query ~= "" then
                table.insert(queries, {tags=tags, query = query})
            end
        end
    end

    return queries
end

function module.get_tags()
    assert(rules, "Please set the xml path before calling this")
    local labels = {}

    for _, v in ipairs(rules) do
        if v.category == "filter" and v.label then
            labels[v.label] = true
        end
    end

    local ret = {}

    for l in pairs(labels) do
        table.insert(ret, l)
    end

    table.sort(ret)

    return ret
end

return setmetatable(module, {
    __index = function(_, key)
        if rawget(module, "get_"..key) then
                            print("key", key)
            return rawget(module, "get_"..key)()
        end

        return rawget(module, key)
    end,
    __newindex = function(_, key, value)
        if key == "path" then
            rules = import_xml(value)
        end
    end,
})

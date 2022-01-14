--- Colors

local sugar = require("sugar")

sugar.highlight.SpellBad.cterm = "underline"

sugar.highlight.CursorLineNR = {
    bold    = true,
    ctermbg = 234,
    ctermfg = 75,
}

sugar.highlight.CursorLine = {
    bold    = true,
    ctermbg = 232,
    ctermfg ="None",
}

sugar.highlight.Pmenu = {
    ctermbg = 234,
    guibg   = "none",
    ctermfg = "white"
}

sugar.highlight.PmenuSel = {
    ctermbg = "Red",
    ctermfg = "White",
}

sugar.highlight.TabLine = {
    ctermfg = "Black",
    ctermbg = "Gray",
    cterm   = "NONE",
}

sugar.highlight.TabLineFill = {
    ctermfg = "Black",
    ctermbg = "Gray",
    cterm   = "NONE"
}

sugar.highlight.TabLineSel = {
    ctermfg = "White",
    ctermbg = "DarkBlue",
    cterm   = "NONE"
}

-- The delay mitigates a bug.
-- https://github.com/neovim/neovim/issues/17089
sugar.schedule.delayed(function()
    vim.api.nvim_command("hi MsgArea ctermbg=236 ctermfg=230")

    sugar.schedule.delayed(function()
        pcall(function()
            sugar.highlight.MsgArea.ctermbg = 236
            sugar.highlight.MsgArea.ctermfg = 230
        end)
    end)
end)

sugar.highlight.MoreMsg = {
    bold    = true,
    ctermfg = 230,
}

sugar.highlight.ErrorMsg = {
    ctermfg = 196,
    ctermbg = 236,
    bold    = true
}

sugar.highlight.WarningMsg = {
    ctermfg = 214,
    ctermbg = 236,
    bold    = true,
}

sugar.highlight.SpellBad = {
    underline = true,
    ctermbg   = "none",
    ctermfg   = "none"
}

sugar.highlight.StatusLine = {
    ctermfg = 123,
    ctermbg = 111,
}

sugar.highlight.User1 = {
    ctermfg = 241,
    ctermbg = 28,
}

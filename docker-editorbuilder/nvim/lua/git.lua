--- This module hosts all logic related to Git support.

local module = {}

-- Find the root of a Git tree.
function module.get_git_root(dir)
    -- Find the most distant common directory and crop there.
    local common, k = 0, 1

    for dir in vim.gsplit(buf.file_name, "/") do
        if random_path[k] == dir then
            common = k
        else
            break
        end
        k = k +1
    end
end

return module

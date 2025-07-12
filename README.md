# fr.yazi

a Yazi plugin that integrates `fzf` with `bat` preview for `rg` search and
`rga` preview for `rga` search

**supports**: `bash`, `fish`, and `zsh`

## dependencies

- [bat](https://github.com/sharkdp/bat)
- [fzf](https://junegunn.github.io/fzf/)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [ripgrep-all](https://github.com/phiresky/ripgrep-all) (optional)

## installation

```sh
ya pkg add lpnh/fr
```

## usage

### plugin args

this plugin supports two arguments:

- `rg`:
   - `rg` search
   - `bat` preview
   - `rg` match (default)
   - `fzf` match (alternative)

- `rga`:
   - `rga` search
   - `rga` preview
   - `rga` match

below is an example of how to configure both in the
`~/.config/yazi/keymap.toml` file:

```toml
[[mgr.prepend_keymap]]
on = ["f", "r"]
run = "plugin fr rg"
desc = "Search file by content (rg)"

[[mgr.prepend_keymap]]
on = ["f", "a"]
run = "plugin fr rga"
desc = "Search file by content (rga)"
```

### fzf binds

this plugin provides the following custom `fzf` keybindings:

- `ctrl-r`: reload the search
- `ctrl-s`: toggle the matching method (rg, fzf)
- `ctrl-]`: toggle the preview window size (66%, 80%)
- `ctrl-\`: toggle the preview window position (top, right)

## customization

### color themes

you can customize the default `fzf` colors using the `FZF_DEFAULT_OPTS`
environment variable. for an example, check out [Catppuccin's fzf
repo](https://github.com/catppuccin/fzf?tab=readme-ov-file#usage)

more examples of color themes can be found in the [fzf
documentation](https://github.com/junegunn/fzf/blob/master/ADVANCED.md#color-themes)

### advanced

for those seeking further customization, you can tweak all the integrated tools
used by this plugin in your `~/.config/yazi/init.lua` file. simply pass a table
to the `setup` function with any of the following fields and their respectives
options:

```lua
require("fr"):setup({
    fzf,
    rg,
    bat,
    rga,
    rga_preview,
})
```

all fields are optional and accept either a string or a table of strings
containing command-line options.

example:

```lua
require("fr"):setup {
    fzf = [[--info-command='echo -e "$FZF_INFO 💛"' --no-scrollbar]],
    rg = "--colors 'line:fg:red' --colors 'match:style:nobold'",
    bat = "--style 'header,grid'",
    rga = {
        "--follow",
        "--hidden",
        "--no-ignore",
        "--glob",
        "'!.git'",
        "--glob",
        "!'.venv'",
        "--glob",
        "'!node_modules'",
        "--glob",
        "'!.history'",
        "--glob",
        "'!.Rproj.user'",
        "--glob",
        "'!.ipynb_checkpoints'",
    },
    rga_preview = {
        "--colors 'line:fg:red'"
            .. " --colors 'match:fg:blue'"
            .. " --colors 'match:bg:black'"
            .. " --colors 'match:style:nobold'",
    },
}
```

almost everything from interface elements to search filters can be customized —
you just need to find the right flag. that's the hard part. lol

## acknowledgments

@vvatikiotis for the `rga`
[integration](https://github.com/lpnh/fr.yazi/pull/1)

this is a derivative of @DreamMaoMao's `fg.yazi` plugin. consider using the
original one instead; you can find it at
<https://gitee.com/DreamMaoMao/fg.yazi>, with a mirror available at
<https://github.com/DreamMaoMao/fg.yazi>

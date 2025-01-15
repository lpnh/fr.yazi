# fr.yazi

> [!NOTE]
> this plugin is only guaranteed to be compatible with Yazi nightly

a Yazi plugin that integrates `fzf` to enhance `rg` with a `bat` preview and/or `rga` with a `rga` preview. fr

**supports**: `bash`, `fish`, and `zsh`

## dependencies

- `bat`
- `fzf`
- `rg`
- `rga` (optional; doesn't require `bat` for its preview)

## installation

```sh
ya pack -a lpnh/fr
```

## usage

add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on = ["f", "f"]
run = "plugin fr --args='ff'"
desc = "Find file by content (fuzzy match)"

[[manager.prepend_keymap]]
on = ["f", "r"]
run = "plugin fr --args='fr'"
desc = "Find file by content (ripgrep match)"

[[manager.prepend_keymap]]
on = ["f", "a"]
run = "plugin fr --args='fa'"
desc = "Find file by content (ripgrep-all)"
```

## acknowledgments

@XYenon for the `rg` match [implementation](https://github.com/lpnh/fg.yazi/commits?author=XYenon)

@vvatikiotis for the `rga` [integration](https://github.com/lpnh/fg.yazi/pull/1)

this is a derivative of @DreamMaoMao's `fg.yazi` plugin. consider using the original one instead; you can find it at <https://gitee.com/DreamMaoMao/fg.yazi>, with a mirror available at <https://github.com/DreamMaoMao/fg.yazi>

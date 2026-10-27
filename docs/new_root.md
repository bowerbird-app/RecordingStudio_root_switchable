# New root link

A scope can offer a link that creates a root.

Set `new_root_path` to a same-origin relative path, or to a callable. The callable receives `controller:`, `actor:`, `device_key:`, `scope:`, `current_root_recording:`, and `return_to:`. Return `nil` or `false` when this actor cannot create a root. The gem drops any path that is not a same-origin relative path, then adds `return_to` when the path does not already include it.

`new_root_label` is the link text. A blank label uses page copy `new_root_action_label`, then the English "New workspace".

`new_root_icon` is the FlatPack icon name. Leave it unset and the link uses page copy `new_root_action_icon`, then `"plus"`. A String or Symbol is the icon name. A literal `"+"` uses the `plus` icon. `false` or `""` draws the label with no icon. The same values work as the `new_root_icon:` keyword on `recording_studio_root_switch_dropdown`, `recording_studio_root_switch_list_for`, and `render_recording_studio_root_switch_list`, and as page copy `new_root_action_icon`.

```ruby
scope.new_root_icon = "folder"
scope.new_root_icon = ->(**) { "sparkles" }
scope.new_root_icon = false
```

```erb
<%= recording_studio_root_switch_dropdown(new_root_icon: "sparkles") %>
<%= recording_studio_root_switch_dropdown(new_root_icon: false) %>
```

The switch page passes the resolved name to `register_page_nav`. A `nil` icon leaves that button without an icon. The dropdown row and the collapsed list render `FlatPack::Shared::IconComponent` only when the name is present.

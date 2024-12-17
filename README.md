Luajit Tracy
============================

Tracy bindings for Luajit


## Usage

Compile [Tracy](https://github.com/wolfpld/tracy)  client `0.11.1` as shared library with `TRACY_DELAYED_INIT` and `TRACY_MANUAL_LIFETIME`

Move `TracyClient` shared library to your project, It should be found by package.cpath

Use in luajit

```lua
local Tracy = require 'tracy'
Tracy.start()

while true do
  Tracy.begin('frame') -- zone begin
  Tracy.begin('update')
  -- update
  Tracy.plot(123)
  Tracy.finish_begin('draw') -- equals to finish(); begin('draw')
  -- draw
  Tracy.message('hello')
  Tracy.finish()
  Tracy.finish() -- zone end
  Tracy.mark_frame()
end

-- If you don't call this, your app may not exit normally.
Tracy.stop()
```

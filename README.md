Luajit Tracy
============================

Tracy bindings for Luajit


## Usage

Compile [Tracy](https://github.com/wolfpld/tracy)  client `0.11.1` as shared library with `TRACY_DELAYED_INIT` and `TRACY_MANUAL_LIFETIME`. If the API does not change, other versions can also be used universally. commands


Move `TracyClient` shared library to your project, It should be found by package.cpath

Use in luajit

```lua
local Tracy = require 'tracy'
Tracy.start()

for i = 1, 1000 do
  Tracy.begin('frame') -- zone begin
  Tracy.begin('update')
  os.execute("timeout 1") -- or other code to sleep
  Tracy.plot('total', 123)
  Tracy.finish().begin('draw') -- equals to finish(); begin('draw')
  os.execute("timeout 1")
  Tracy.message('hello')
  Tracy.finish()
  Tracy.finish() -- zone end
  Tracy.mark_frame()
end

-- If you don't call this, your app may not exit normally.
Tracy.stop()
```

`begin` `finish` `plot` `plot_incr` `message` support chain calls.
such as `Tracy.finish().begin('xx').plot('a', 1).message('text')`

Open TracyProfiler(You can download from [here](https://github.com/wolfpld/tracy/releases/tag/v0.11.1) or compile from source)


## Compile Tracy Client

In Tracy folider

```shell
mkdir _build
cd _build
cmake -DTRACY_STATIC=OFF -DTRACY_DELAYED_INIT=ON -DTRACY_MANUAL_LIFETIME=ON ..
```
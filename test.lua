local Tracy = require 'tracy'
Tracy.start()

for i = 1, 1000 do
  Tracy.begin('frame') -- zone begin

  Tracy.begin('update')
  os.execute("timeout 1") -- or other code to sleep
  Tracy.plot('total', math.random() * 100).message('aaaa')

  Tracy.finish().begin('draw')
  os.execute("timeout 1")
  Tracy.plot_incr('x', 1).message('hello').plot_incr('x', math.random() * 3)
  Tracy.finish()

  Tracy.finish() -- zone end
  Tracy.mark_frame()
end

-- If you don't call this, your app may not exit normally.
Tracy.stop()

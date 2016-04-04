SuperStrict

Framework mky.mojo2
?Not opengles
Import brl.GLGraphics
?opengles
Import sdl.sdlgraphics
?
Import brl.pngloader
Import brl.random

Graphics 800, 600, 0

Local canvas:TCanvas = New TCanvas.CreateCanvas()

Local drawList:TDrawList = New TDrawList

For Local i:Int=0 Until 100

	drawList.SetColor Float(Rnd()),Float(Rnd()),Float(Rnd())
	
	drawList.DrawCircle Float(Rnd(GraphicsWidth())-GraphicsWidth()/2),Float(Rnd(GraphicsHeight())-GraphicsHeight()/2),Float(Rnd(10,20))
Next

Local angle:Float = 0

While Not KeyDown(KEY_ESCAPE)

	angle :+ 0.5

	canvas.Clear 0,0,1

	canvas.RenderDrawListXYZ drawList,MouseX(),MouseY(),angle
	
	canvas.Flush

	Flip
	
Wend

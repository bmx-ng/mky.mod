SuperStrict

Framework mky.mojo2
?Not opengles
Import brl.GLGraphics
?opengles
Import sdl.sdlgraphics
?
Import brl.pngloader

Graphics 800, 600, 0

Local canvas:TCanvas = New TCanvas.CreateCanvas()

While Not KeyDown(KEY_ESCAPE)

	canvas.Clear 0,0,1
	
	canvas.SetBlendMode 3
	canvas.SetColor 0,0,0,.5
	canvas.DrawText "HELLO WORLD!",GraphicsWidth()/2+2,GraphicsHeight()/2+2,.5,.5
	
	canvas.SetBlendMode 1
	canvas.SetColor 1,1,0,1
	canvas.DrawText "HELLO WORLD!",GraphicsWidth()/2,GraphicsHeight()/2,.5,.5
	
	canvas.Flush
	
	Flip
	
Wend

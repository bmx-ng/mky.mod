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

canvas.SetAmbientLight .2,.2,.2
		
Local tile:TImage=TImage.Load( "images/t3.png",0,0 )


While Not KeyDown(key_escape)

	canvas.Clear 0,0,1

	'Set light 0
	canvas.SetLightType 0,1
	canvas.SetLightColor 0,.3,.3,.3
	canvas.SetLightPosition 0,MouseX(),MouseY(),-100
	canvas.SetLightRange 0,200
	
	'Light will affect subsequent rendering...
	For Local x:Int=0 Until GraphicsWidth() Step 128
		For Local y:Int=0 Until GraphicsHeight() Step 128	
			canvas.DrawImage tile,x,y
		Next
	Next
	
	canvas.Flush

	Flip

Wend


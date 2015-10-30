SuperStrict

Framework mky.mojo2
?Not opengles
Import brl.GLGraphics
?opengles
Import sdl.sdlgraphics
?
Import brl.pngloader
Import brl.linkedlist

Graphics 800, 600, 0

Local canvas:TCanvas = New TCanvas.CreateCanvas()

Local image:TImage = New TImage.Create( 256,256 )
Local 	icanvas:TCanvas=New TCanvas.CreateCanvas( image )


While Not KeyDown(key_escape)

	
	'render to image...
	For Local x:Int=0 Until 16
		For Local y:Int=0 Until 16
			If (x~y)&1
				icanvas.SetColor Sin( MilliSecs*.1 )*.5+.5,Cos( MilliSecs*.1 )*.5+.5,.5
			Else
				icanvas.SetColor 1,1,0
			EndIf
			icanvas.DrawRect x*16,y*16,16,16
		Next
	Next
	icanvas.Flush
	
	'render to main canvas...
	canvas.Clear
	canvas.DrawImage image,MouseX(),MouseY()


	canvas.Flush

	Flip

Wend


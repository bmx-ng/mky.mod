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
Local data:TPixmap = New TPixmap.Create(16,16,PF_RGBA8888)

While Not KeyDown(key_escape)

	Local pitch:Int=256*4
		
	For Local x:Int=0 Until 16
	
		For Local y:Int=0 Until 16

			Local r:Float=1.0
			Local g:Float=1.0
			Local b:Float=1.0
			Local a:Float=1.0
			
			If (x~y)&1 Then
				r=Sin( MilliSecs()*.1 )*.5+.5
				g=Cos( MilliSecs()*.1 )*.5+.5
				b=.5
			EndIf
			
			Local rgba:Int=Int(a*255) Shl 24 | Int(b*255) Shl 16 | Int(g*255) Shl 8 | Int(r*255)
			
			Local pix:Int Ptr = Int Ptr(data.pixels)
			For Local i:Int=0 Until 16*16
				pix[i] = rgba
			Next
			
			image.WritePixels x*16,y*16,16,16,data

		Next
	Next
	
	'render image to main canvas...
	'
	canvas.Clear
	canvas.DrawImage image,MouseX(),MouseY()
	canvas.Flush


	Flip

Wend

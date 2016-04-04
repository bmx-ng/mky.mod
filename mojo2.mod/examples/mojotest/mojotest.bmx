SuperStrict

Framework mky.mojo2
?Not opengles
'Import brl.GLGraphics
Import sdl.sdlgraphics
?opengles
Import sdl.sdlgraphics
?
Import brl.pngloader


Graphics 640, 480, 0

Local ms:Int
Local me:Int

Local canvas:TCanvas = New TCanvas.CreateCanvas()

Local image:TImage=TImage.Load( "images/RedbrushAlpha.png" )
Local tx:Float
Local ty:Float

Local c:Int = 7
Local r:Int = 255
Local g:Int = 255
Local b:Int = 255

Local ang:Float = 0

While Not KeyDown(key_escape)

ms = MilliSecs()
	canvas.SetScissor 0,0,GraphicsWidth(),GraphicsHeight()
	canvas.Clear 0,0,.5
	
	Local sz:Float=Sin(ang * 10)*32
	Local sx:Int=32+sz
	Local sy:Int=32
	Local sw:Int=GraphicsWidth()-(64+sz*2)
	Local sh:Int=GraphicsHeight()-(64+sz)
	
	canvas.SetScissor sx,sy,sw,sh
	canvas.Clear 1,32.0/255.0,0

	canvas.PushMatrix

	canvas.Translate tx,ty
	canvas.Scale GraphicsWidth()/640.0,GraphicsHeight()/480.0
	canvas.Translate 320,240
'	canvas.Rotate MilliSecs()/1000.0*12
	canvas.Rotate ang
	canvas.Translate -320,-240
	
	canvas.SetColor .5,1,0
	canvas.DrawRect 32,32,640-64,480-64

	canvas.SetColor 1,1,0
	For Local y:Int=0 Until 480
		For Local x:Int=16 Until 640 Step 32
			canvas.SetAlpha Min( Abs( y-240.0 )/120.0,1.0 )
			canvas.DrawPoint x,y
		Next
	Next
	canvas.SetAlpha 1

	canvas.SetColor 0,.5,1
	canvas.DrawOval 64,64,640-128,480-128

	canvas.SetColor 1,0,.5
	canvas.DrawLine 32,32,640-32,480-32
	canvas.DrawLine 640-32,32,32,480-32

	canvas.SetColor r/255.0,g/255.0,b/255.0,Float(Sin(ang * 5)*.5+.5)
	canvas.DrawImageXYZ image,320,240,0
	canvas.SetAlpha 1

	canvas.SetColor 1,0,.5
	canvas.DrawPoly( [ 140.0,232.0, 320.0,224.0, 500.0,232.0, 500.0,248.0, 320.0,256.0, 140.0,248.0 ] )
			
	canvas.SetColor .5,.5,.5
	canvas.DrawText "The Quick Brown Fox Jumps Over The Lazy Dog",320,240,.5,.5
	

	canvas.PopMatrix
	
	canvas.Flush()
me = MilliSecs()

	ang :+ 0.2

'Print (me - ms)
	Flip 1
Wend

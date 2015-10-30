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

Local vertices:Float[] = New Float[4*2*100]
	
Local indices:Int[]

Local sz:Float=20.0
Local p:Int=0

For Local i:Int=0 Until 100

	Local x:Float=Rnd(GraphicsWidth())-sz/2-GraphicsWidth()/2
	Local y:Float=Rnd(GraphicsHeight())-sz/2-GraphicsHeight()/2
	
	vertices[p+0]=x
	vertices[p+1]=y
	
	vertices[p+2]=x+sz
	vertices[p+3]=y
	
	vertices[p+4]=x+sz
	vertices[p+5]=y+sz
	
	vertices[p+6]=x
	vertices[p+7]=y+sz
	
	p:+8
Next

'quick test of indices...
indices = New Int[400]
For Local i:Int=0 Until 400
	indices[i]=i
Next


While Not KeyDown(key_escape)

	canvas.Clear 0,0,1
		
	canvas.SetColor Sin( MilliSecs()*.01 )*.5+.5,Cos( MilliSecs()*.03 )*.5+.5,Sin( MilliSecs()*.05 )*.5+.5
	
	canvas.PushMatrix
	canvas.Translate MouseX(),MouseY()
	
	canvas.DrawIndexedPrimitives 4,100,vertices,indices	'should draw same thing...
	
	canvas.PopMatrix

	canvas.Flush

	Flip

Wend


SuperStrict

Framework mky.mojo2
?Not opengles
Import brl.GLGraphics
?opengles
Import sdl.sdlgraphics
?
Import brl.pngloader

Graphics 640, 480, 0

'generate color texture
Local colortex:TTexture=New TTexture.Create( 256,256,PF_RGBA8888,TTexture.ClampST|TTexture.RenderTarget )
Local rcanvas:TCanvas=New TCanvas.CreateCanvas( colortex )
rcanvas.Clear( 1,1,1 )
rcanvas.Flush

'generate normal texture		
Local normtex:TTexture=New TTexture.Create( 256,256,PF_RGBA8888,TTexture.ClampST|TTexture.RenderTarget )
rcanvas.SetRenderTarget( normtex )
rcanvas.Clear( .5,.5,1.0,0.0 )
For Local x:Int=0 Until 256 'Step 32
	For Local y:Int=0 Until 256 'Step 32
		
		Local dx:Float=x-127.5
		Local dy:Float=y-127.5
		Local dz:Float=127.5*127.5-dx*dx-dy*dy
		
		If dz<=0 Continue
		
		dz=Sqr( dz )
		
		Local r:Float=(dx+127.5)/255.0
		Local g:Float=(dy+127.5)/-255.0
		Local b:Float=(dz+127.5)/255.0
		
		rcanvas.SetColor( r,g,b,1 )
		rcanvas.DrawPoint( x,y )

	Next
Next
rcanvas.Flush

Local material:TMaterial=New TMaterial.Create( TShader.BumpShader() )
material.SetTexture( "ColorTexture",colortex )
material.SetTexture( "NormalTexture",normtex )
material.SetVector( "AmbientColor",[0.0,0.0,0.0,1.0] )

Local image:TImage=New TImage.CreateMaterial( material,.5,.5 )

Local canvas:TCanvas=New TCanvas.CreateCanvas()
canvas.SetAmbientLight .2,.2,.2

Local rot:Float

While Not KeyDown(key_escape)

	canvas.Clear 0,0,0
	
	'Set light 0
	canvas.SetLightType 0,1
	canvas.SetLightColor 0,.3,.3,.3
	canvas.SetLightPosition 0,MouseX(),MouseY(),-100
	canvas.SetLightRange 0,400
	
	rot:+1
	
	canvas.DrawImageXYZS image,GraphicsWidth()/2,GraphicsHeight()/2,rot,.5,.5
	
	canvas.Flush

	Flip

Wend


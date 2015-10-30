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

Local sourceImage:TImage = TImage.Load( "data/default_player.png" )
Local targetImage:TImage = New TImage.Create( sourceImage.Width(),sourceImage.Height() )

Local effect:TShaderEffect = New TShaderEffect
Local level:Float = 1

While Not KeyDown(key_escape)

	If KeyDown( KEY_A )
		level=Min( level+.01,1.0 )
	Else If KeyDown( KEY_Z )
		level=Max( level-.01,0.0 )
	EndIf

	effect.SetLevel level
	
	effect.Render( sourceImage,targetImage )
	
	canvas.Clear
	
	canvas.DrawImage targetImage,MouseX(),MouseY()
	
	canvas.DrawText "Effect level="+level+" (A/Z to change)",0,0
	
	canvas.Flush


	Flip

Wend





'Our custom shader
Type TBWShader Extends TShader

	Method Create:TBWShader(source:String)
		Build( LoadString( source ) )
		Return Self
	End Method
	
	'must implement this - sets valid/default material params
	Method OnInitMaterial( material:TMaterial )
		material.SetTexture "ColorTexture",TTexture.White()
		material.SetScalar "EffectLevel",1
	End Method
	
	Function Instance:TBWShader()
		If Not _instance _instance=New TBWShader.Create("data/bwshader.glsl")
		Return _instance
	End Function
	
	Private
	
	Global _instance:TBWShader
	
End Type

Type TShaderEffect

	Method New()
		If Not _canvas _canvas=New TCanvas.CreateCanvas()

		_material=New TMaterial.Create( TBWShader.Instance() )
	End Method
	
	Method SetLevel( level:Float )
	
		_material.SetScalar "EffectLevel",level
	End Method
	
	Method Render( source:TImage,target:TImage )
	
		_material.SetTexture "ColorTexture",source.Material.ColorTexture()
		
		_canvas.SetRenderTarget target
		_canvas.SetViewport 0,0,target.Width(),target.Height()
		_canvas.SetProjection2d 0,target.Width(),0,target.Height()
		
		_canvas.DrawRect 0,0,target.Width(),target.Height(),_material
		
		_canvas.Flush
	End Method
	
	'Private
	
	Global _canvas:TCanvas	'shared between ALL effects
	
	Field _material:TMaterial
	
End Type

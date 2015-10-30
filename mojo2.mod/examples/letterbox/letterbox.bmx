SuperStrict

Framework mky.mojo2
?Not opengles
Import brl.GLGraphics
?opengles
Import sdl.sdlgraphics
?
Import brl.pngloader

Graphics 800, 600, 0

Const VWIDTH:int=320
Const VHEIGHT:int=240

Local canvas:TCanvas = New TCanvas.CreateCanvas()
local splitScreen:int

While Not KeyDown(key_escape)
	
	If KeyHit( KEY_SPACE ) then
		splitScreen = Not splitScreen
	End If

	canvas.SetViewport 0,0,GraphicsWidth(),GraphicsHeight()

	canvas.Clear 0,0,0

	If splitScreen
	
		Local h:Int=GraphicsHeight()/2

		RenderScene( canvas, "PLAYER 1 READY",[0,0,GraphicsWidth(),h] )
	
		RenderScene( canvas, "PLAYER 2 READY",[0,h,GraphicsWidth(),h] )
	
	Else
	
		RenderScene( canvas, "SPACE TO TOGGLE SPLITSCREEN",[0,0,GraphicsWidth(),GraphicsHeight()] )

	Endif

	canvas.Flush

	Flip

Wend

Function RenderScene( canvas:TCanvas, msg:String, devrect:Int[] )

	Local vprect:Int[4]
		
	CalcLetterbox( VWIDTH,VHEIGHT,devrect,vprect )

	canvas.SetViewport vprect[0],vprect[1],vprect[2],vprect[3]
	
	canvas.SetProjection2d 0,VWIDTH,0,VHEIGHT

	canvas.Clear 0,0,1
	
	canvas.DrawText msg,VWIDTH/2,VHEIGHT/2,.5,.5
	
End Function

Function CalcLetterbox( vwidth:Float,vheight:Float,devrect:Int[],vprect:Int[] )
	
	Local vaspect:Float=vwidth/vheight
	Local daspect:Float=Float(devrect[2])/devrect[3]

	If daspect > vaspect Then
		vprect[2] = devrect[3]*vaspect
		vprect[3] = devrect[3]
		vprect[0] = (devrect[2]-vprect[2])/2+devrect[0]
		vprect[1] = devrect[1]
	Else
		vprect[2] = devrect[2]
		vprect[3] = devrect[2]/vaspect
		vprect[0] = devrect[0]
		vprect[1] = (devrect[3]-vprect[3])/2+devrect[1]
	Endif

End Function

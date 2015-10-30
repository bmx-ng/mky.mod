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

Local drawing:TList = MakeVectorDrawing()
Local rotstep:Float
Local wiggle:Float
Local rot:Float


While Not KeyDown(key_escape)

	 If KeyHit(KEY_W) 
	 	wiggle = 0.5

	 EndIf
	 
	 If MouseDown(1)
	 	For Local pt:TTriPrims = EachIn drawing 		 
 			pt.Pull(MouseX(),MouseY(),0.0001) 		
 		Next
	 EndIf
	 
	 If MouseDown(2)
	 	For Local pt:TTriPrims = EachIn drawing 		 
 			pt.Pull(MouseX(),MouseY(),-0.0001) 		
 		Next
	 EndIf

	If KeyHit(KEY_SPACE)
		wiggle = 0
		rot = 0
		For Local pt:TTriPrims = EachIn drawing 		 
 			pt.ResetMorph(1)	
 		Next
		 
	 
		rotstep = 0
	EndIf 


	canvas.ResetMatrix()
	
	canvas.Clear .5,.7,1
	 	
	canvas.SetColor 0.5,0.5,0.5
	canvas.DrawText "Mouse Click with left/right mouse button",10,10
	canvas.DrawText "Press [W] to wiggle",10,30
	canvas.DrawText "Press [Space] to reset",10,50
	 
	rot = 0
	 	
	For Local pt:TTriPrims = EachIn drawing
		canvas.Rotate rot
		pt.Draw(canvas)
		canvas.Rotate -rot
		rot :+ rotstep
	Next
	 	
	canvas.Flush
	rotstep :+ Cos(Float(MilliSecs() Mod 360))*wiggle
	 
	wiggle :* 0.95
	
	rotstep :* 0.99
	
	For Local pt:TTriPrims = EachIn drawing 		 
		pt.ResetMorph(0.01)	
	Next
	
	Flip

Wend



Function MakeVectorDrawing:TList()

	Local data:String=LoadString( "data.txt" )

	Local primslist:TList= New TList
	
	
	Local LINES:String[] = data.Split("*")
	
	Local tp:TTriPrims
	
	For Local line:String = EachIn LINES
		Local parts:String[] = line.Split(";")
	
		 
		 Select parts[0]
		 
		 	Case "color"
				tp = New TTriPrims
				
				Local vals:String[] = parts[1].Split(",")
				tp.r = Float(vals[0])
				tp.g = Float(vals[1])
				tp.b = Float(vals[2])
			 	primslist.AddLast(tp)
			 	
			 Case "vertices"	
			 	Local vals:String[] = parts[1].Split(",")
			 	
			 	tp.vertices = New Float[vals.Length]
			 	For Local i:Int = 0  Until vals.Length
			 		tp.vertices[i] = Float(vals[i])*0.01
			 	Next
			 			
				 
			 Case "indexes"				
				Local vals:String[] = parts[1].Split(",")
			 	tp.indexes = New Int[vals.Length]
			 	For Local i:Int = 0  Until vals.Length
			 		tp.indexes[i] = Int(vals[i])
			 	Next			
		 
		 End Select
		 
		 Next
		 
		 
		 Return primslist
		 
End Function



Type TTriPrims
	Field r:Float,g:Float,b:Float,a:Float = 1
	Field vertices:Float[]
	Field morphedvertices:Float[]
	Field indexes:Int[]
	
	Method ResetMorph(factor:Float = 1.0)
	
		If factor >= 1
			Local invfactor:Float = 1.0 - factor
			For Local i:Int = 0 Until vertices.Length
				morphedvertices[i] =  vertices[i]  
			Next
			Return 
		EndIf
	
	
		Local invfactor:Float = 1.0 - factor
		For Local i:Int = 0 Until vertices.Length
			Local newval:Float =  morphedvertices[i] *invfactor +  vertices[i] * factor
		Next
	End Method
	
	
	
	Method Draw(canvas:TCanvas)
		If morphedvertices.Length<>vertices.Length
			morphedvertices= New Float[vertices.Length]
			ResetMorph()
	 	EndIf
	
		canvas.SetColor r,g,b,a
		canvas.DrawIndexedPrimitives(3,indexes.Length/3,morphedvertices,indexes)
	End Method
	
	Method Pull(x:Float,y:Float,factor:Float)
		
		For Local i:Int = 0 Until vertices.Length Step 2
		
			Local vx:Float = (morphedvertices[i]-x)
			Local vy:Float = (morphedvertices[i+1]-y) 
		
			Local dist:Float = Sqr(vx*vx+vy*vy)
		
	 		dist = 200-dist

			Local newx:Float = morphedvertices[i]  + vx  * dist  * factor 
			Local newy:Float = morphedvertices[i+1]  + vy *  dist  * factor 
 
			morphedvertices[i] = newx
			morphedvertices[i+1] = newy
 
		Next
	End Method
	
End Type


'
' BlitzMax port, 2015 Bruce A Henderson
' 
' Copyright (c) 2015 Mark Sibly
' 
' This software is provided 'as-is', without any express or implied
' warranty. In no event will the authors be held liable for any damages
' arising from the use of this software.
' 
' Permission is granted to anyone to use this software for any purpose,
' including commercial applications, and to alter it and redistribute it
' freely, subject to the following restrictions:
' 
' 1. The origin of this software must not be misrepresented; you must not
'    claim that you wrote the original software. If you use this software
'    in a product, an acknowledgement in the product documentation would be
'    appreciated but is not required.
' 2. Altered source versions must be plainly marked as such, and must not be
'    misrepresented as being the original software.
' 3. This notice may not be removed or altered from any source distribution.
' 
SuperStrict

Import "graphics.bmx"


Type TLayerData
	Field matrix:Float[]=Mat4New()
	Field invMatrix:Float[]=Mat4New()
	Field drawList:TDrawList
End Type

Global lvector:Float[4]
Global tvector:Float[4]

Public

?bmxng
Interface ILight

	Method LightMatrix:Float[]()
	Method LightType:Int()
	Method LightColor:Float[]()
	Method LightRange:Float()
	Method LightImage:TImage()
	
End Interface

Interface ILayer

	Method LayerMatrix:Float[]()
	Method LayerFogColor:Float[]()
	Method LayerLightMaskImage:TImage()
	Method EnumLayerLights( lights:TILightStack )
	Method OnRenderLayer( drawLists:TDrawListStack )
	
End Interface
?Not bmxng
Type ILight

	Method LightMatrix:Float[]() Abstract
	Method LightType:Int() Abstract
	Method LightColor:Float[]() Abstract
	Method LightRange:Float() Abstract
	Method LightImage:TImage() Abstract
	
End Type

Type ILayer

	Method LayerMatrix:Float[]() Abstract
	Method LayerFogColor:Float[]() Abstract
	Method LayerLightMaskImage:TImage() Abstract
	Method EnumLayerLights( lights:TILightStack ) Abstract
	Method OnRenderLayer( drawLists:TDrawListStack ) Abstract
	
End Type
?

Type TRenderer

	Method SetClearMode( clearMode:Int )
		_clearMode=clearMode
	End Method
	
	Method SetClearColor( clearColor:Float[] )
		_clearColor=clearColor
	End Method
	
	Method SetAmbientLight( AmbientLight:Float[] )
		_ambientLight=AmbientLight
	End Method
	
	Method SetCameraMatrix( cameraMatrix:Float[] )
		_cameraMatrix=cameraMatrix
	End Method
	
	Method SetProjectionMatrix( projectionMatrix:Float[] )
		_projectionMatrix=projectionMatrix
	End Method
	
	Method Layers:TILayerStack()
		Return _layers
	End Method
	
	Method Render(dcanvas:TCanvas)

		Local canvas:TCanvas=dcanvas
		_canvas=canvas
		_viewport=canvas.Viewport()
		_projectionMatrix=canvas.ProjectionMatrix()

		Local vwidth:Int=_viewport[2]
		Local vheight:Int=_viewport[3]

		If vwidth<=0 Or vheight<=0 Return
		
		Mat4Inverse( _projectionMatrix,_invProjMatrix )

		lvector[0]=-1;lvector[1]=-1;lvector[2]=-1;lvector[3]=1
		Mat4Project( _invProjMatrix,lvector,tvector )
		Local px0:Float=tvector[0]
		Local py0:Float=tvector[1]

		lvector[0]=1;lvector[1]=1;lvector[2]=-1;lvector[3]=1
		Mat4Project( _invProjMatrix,lvector,tvector )
		Local px1:Float=tvector[0]
		Local py1:Float=tvector[1]

		Local twidth:Int=px1-px0,theight:Int=py1-py0
		
		If Not _timage Or _timage.Width()<>twidth Or _timage.Height()<>theight
			_timage=New TImage.Create( twidth,theight,0,0 )
		End If
		
		If Not _timage2 Or _timage2.Width()<>twidth Or _timage2.Height()<>theight
			_timage2=New TImage.Create( twidth,theight,0,0 )
		End If

		If Not _tcanvas
			_tcanvas=New TCanvas.CreateCanvas( _timage )
		EndIf
		
		_tcanvas.SetProjectionMatrix( _projectionMatrix )
		_tcanvas.SetViewport( 0,0,twidth,theight )
		_tcanvas.SetScissor( 0,0,twidth,theight )

		Mat4Inverse _cameraMatrix,_viewMatrix
		
		Local invProj:Int=False

		'Clear!		
		'_canvas.SetRenderTarget _image	
		'_canvas.SetViewport _viewport[0],_viewport[1],_viewport[2],_viewport[3]
		Select _clearMode
		Case 1
			_canvas.Clear _clearColor[0],_clearColor[1],_clearColor[2],_clearColor[3]
		End Select
		
		For Local layerId:Int=0 Until _layers.Length
		
			Local layer:ILayer=ILayer(_layers.Get( layerId ))
			Local fog:Float[]=layer.LayerFogColor()
			
			Local layerMatrix:Float[]=layer.LayerMatrix()
			Mat4Inverse layerMatrix,_invLayerMatrix
			
			_drawLists.Clear
			layer.OnRenderLayer( _drawLists )
			
			Local lights:TILightStack=New TILightStack
			layer.EnumLayerLights( lights )
			
			If Not lights.Length
			
				For Local i:Int=0 Until 4
					canvas.SetLightType i,0
				Next
			
				canvas.SetShadowMap Null'_timage
				canvas.SetViewMatrix _viewMatrix
				canvas.SetModelMatrix layerMatrix
				canvas.SetAmbientLight _ambientLight[0],_ambientLight[1],_ambientLight[2],1
				canvas.SetFogColor fog[0],fog[1],fog[2],fog[3]
				
				canvas.SetColor 1,1,1,1
				For Local i:Int=0 Until _drawLists.Length
					canvas.RenderDrawList _drawLists.Get( i )
				Next
				canvas.Flush
				
				Continue
				
			EndIf
			
			Local light0:Int=0
			
			Repeat
			
				Local numLights:Int=Min(lights.Length-light0,4)
				
				'Shadows
				'
				canvas=_tcanvas
				canvas.SetRenderTarget _timage
				canvas.SetShadowMap Null
				canvas.SetViewMatrix _viewMatrix
				canvas.SetModelMatrix layerMatrix
				canvas.SetAmbientLight 0,0,0,0
				canvas.SetFogColor 0,0,0,0
				
				canvas.Clear 1,1,1,1
				canvas.SetBlendMode 0
				canvas.SetColor 0,0,0,0

				canvas.SetDefaultMaterial TShader.ShadowShader().DefaultMaterial()
				
				For Local i:Int=0 Until numLights
				
					Local light:ILight=lights.Get(light0+i)
					
					Local matrix:Float[]=light.LightMatrix()
					
					Vec4CopySrcDst matrix,lvector,12,0
					Mat4Transform _invLayerMatrix,lvector,tvector
					Local lightx:Float=tvector[0]
					Local lighty:Float=tvector[1]
					
					canvas.SetColorMask i=0,i=1,i=2,i=3
					
					Local image:TImage=light.LightImage()
					If image
						canvas.Clear 0,0,0,0
						canvas.PushMatrix
						canvas.SetMatrix matrix[0],matrix[1],matrix[4],matrix[5],lightx,lighty
						canvas.DrawImageImage image
						canvas.PopMatrix
					EndIf
		
					For Local j:Int=0 Until _drawLists.Length
						canvas.DrawShadows lightx,lighty,_drawLists.Get( j )
					Next
				
				Next
				
				canvas.SetDefaultMaterial TShader.FastShader().DefaultMaterial()
				canvas.SetColorMask True,True,True,True
				canvas.Flush
				
				'LightMask
				'
				Rem
				Local lightMask:TImage=layer.LayerLightMaskImage()
				If lightMask
				
					If Not invProj
						Mat4Inverse _projectionMatrix,_invProjMatrix
						Mat4Project( _invProjMatrix,[-1.0,-1.0,-1.0,1.0],_ptl )
						Mat4Project( _invProjMatrix,[ 1.0, 1.0,-1.0,1.0],_pbr )
					EndIf
					
					Local fwidth:Float=(_pbr[0]-_ptl[0])
					Local fheight:Float=(_pbr[1]-_ptl[1])
					
					If _projectionMatrix[15]=0
						Local scz:Float=(layerMatrix[14]-_cameraMatrix[14])/_ptl[2]
						fwidth:*scz
						fheight:*scz
					EndIf
				
					_canvas.SetProjection2d 0,fwidth,0,fheight					
					_canvas.SetViewMatrix Mat4Identity
					_canvas.SetModelMatrix Mat4Identity
					
					'test...
					'_canvas.SetBlendMode 0
					'_canvas.SetColor 1,1,1,1
					'_canvas.DrawRect 0,0,fwidth,fheight
					
					_canvas.SetBlendMode 4
					
					Local w:Float=lightMask.Width()
					Local h:Float=lightMask.Height()
					Local x:Int:-w
					While x<fwidth+w
						Local y:Int:-h
						While y<fheight+h
							_canvas.DrawImage lightMask,x,y
							y:+h
						Wend
						x:+w
					Wend
					
					_canvas.Flush

				EndIf
				end rem
				
				'Enable lights
				'
				canvas=_canvas
				If light0 canvas=_tcanvas
				
				For Local i:Int=0 Until numLights
				
					Local light:ILight=lights.Get(light0+i)
					
					Local c:Float[]=light.LightColor()
					Local m:Float[]=light.LightMatrix()
					
					canvas.SetLightType i,1
					canvas.SetLightColor i,c[0],c[1],c[2],c[3]
					canvas.SetLightPosition i,m[12],m[13],m[14]
					canvas.SetLightRange i,light.LightRange()
				Next
				For Local i:Int=numLights Until 4
					canvas.SetLightType i,0
				Next
				
				If light0=0	'first pass?
				
					'render lights+ambient to output
					'
					canvas=_canvas
					canvas.SetShadowMap _timage
					canvas.SetViewMatrix _viewMatrix
					canvas.SetModelMatrix layerMatrix
					canvas.SetAmbientLight _ambientLight[0],_ambientLight[1],_ambientLight[2],1
					canvas.SetFogColor fog[0],fog[1],fog[2],fog[3]
					
					canvas.SetColor 1,1,1,1
					For Local i:Int=0 Until _drawLists.Length
						canvas.RenderDrawList _drawLists.Get( i )
					Next
					canvas.Flush
					
				Else
				
					'render lights only
					'
					canvas=_tcanvas
					canvas.SetRenderTarget _timage2
					canvas.SetShadowMap _timage
					canvas.SetViewMatrix _viewMatrix
					canvas.SetModelMatrix layerMatrix
					canvas.SetAmbientLight 0,0,0,0
					canvas.SetFogColor 0,0,0,fog[3]
					
					canvas.Clear 0,0,0,1
					canvas.SetColor 1,1,1,1
					For Local i:Int=0 Until _drawLists.Length
						canvas.RenderDrawList _drawLists.Get( i )
					Next
					canvas.Flush
					
					'add light to output
					'
					'_canvas.SetRenderTarget _image
					canvas=_canvas
					canvas.SetShadowMap Null
					canvas.SetViewMatrix Mat4Identity
					canvas.SetModelMatrix Mat4Identity
					canvas.SetAmbientLight 0,0,0,1
					canvas.SetFogColor 0,0,0,0
					
					canvas.SetBlendMode 2
					canvas.SetColor 1,1,1,1
					canvas.DrawImageImage _timage2
					canvas.Flush
					
				EndIf
				
				light0:+4
			
			Until light0>=lights.Length
			
		Next
	End Method
	
	'Protected
	
	Field _canvas:TCanvas
	Field _tcanvas:TCanvas
	
	Field _timage:TImage		'tmp lighting texture
	Field _timage2:TImage		'another tmp lighting image for >4 lights

	Field _viewport:Int[]=[0,0,640,480]
	Field _clearMode:Int=1
	Field _clearColor:Float[]=[0.0,0.0,0.0,1.0]
	Field _ambientLight:Float[]=[1.0,1.0,1.0,1.0]
	Field _projectionMatrix:Float[]=Mat4New()
	Field _cameraMatrix:Float[]=Mat4New()
	Field _viewMatrix:Float[]=Mat4New()
	
	Field _layers:TILayerStack=New TILayerStack
	
	Field _invLayerMatrix:Float[16]
	Field _drawLists:TDrawListStack=New TDrawListStack
	
	Field _invProjMatrix:Float[16]
	Field _ptl:Float[4]
	Field _pbr:Float[4]
		
End Type

Type TILightStack
	Field data:ILight[]
	Field length:Int

	Method Push( value:ILight )
		If length=data.Length
			data=data[..length*2+10]
		EndIf
		data[length]=value
		length:+1
	End Method

	Method Pop:ILight()
		length:-1
		Local v:ILight=data[length]
		data[length]=Null
		Return v
	End Method

	Method Top:ILight()
		Return data[length-1]
	End Method
	
	Method Get:ILight(index:Int)
		Return data[index]
	End Method

	Method Clear()
		For Local i:Int=0 Until length
			data[i]=Null
		Next
		length=0
	End Method

End Type

Type TILayerStack
	Field data:ILayer[]
	Field length:Int

	Method Push( value:ILayer )
		If length=data.Length
			data=data[..length*2+10]
		EndIf
		data[length]=value
		length:+1
	End Method

	Method Pop:ILayer()
		length:-1
		Local v:ILayer=data[length]
		data[length]=Null
		Return v
	End Method

	Method Top:ILayer()
		Return data[length-1]
	End Method
	
	Method Get:ILayer(index:Int)
		Return data[index]
	End Method

	Method Clear()
		For Local i:Int=0 Until length
			data[i]=Null
		Next
		length=0
	End Method

End Type

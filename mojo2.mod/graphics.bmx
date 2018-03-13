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


'Framework brl.standardio

Import brl.bank
Import brl.map
Import brl.ramstream
Import brl.pixmap
Import brl.filesystem
Import brl.system
Import brl.Graphics
Import "math3d.bmx"
Import "glutil.bmx"
Import "glslparser.bmx"
Import "maps.bmx"


Incbin "data/mojo2_font.png"
Incbin "data/mojo2_program.glsl"
Incbin "data/mojo2_fastshader.glsl"
Incbin "data/mojo2_bumpshader.glsl"
Incbin "data/mojo2_matteshader.glsl"
Incbin "data/mojo2_shadowshader.glsl"
Incbin "data/mojo2_lightmapshader.glsl"

Private

Global _inited:Int

Global mainShader:String

Global _fastShader:TShader
Global _bumpShader:TShader
Global _matteShader:TShader
Global _shadowShader:TShader
Global _lightMapShader:TShader

Global defaultFont:TFont
Global _defaultShader:TShader

Global freeOps:TDrawOpStack=New TDrawOpStack
Global nullOp:TDrawOp=New TDrawOp

Global defaultFbo:Int

Global tmpMat2d:Float[6]
Global tmpMat3d:Float[16]
Global tmpMat3d2:Float[16]

Global flipYMatrix:Float[]=Mat4New()
Global graphicsSeq:Int=1
Global vbosSeq:Int

'shader params
Global rs_projMatrix:Float[]=Mat4New()
Global rs_modelViewMatrix:Float[]=Mat4New()
Global rs_modelViewProjMatrix:Float[]=Mat4New()
Global rs_clipPosScale:Float[]=[1.0,1.0,1.0,1.0]
Global rs_globalColor:Float[]=[1.0,1.0,1.0,1.0]
Global rs_numLights:Int
Global rs_fogColor:Float[]=[0.0,0.0,0.0,0.0]
Global rs_ambientLight:Float[]=[0.0,0.0,0.0,1.0]
Global rs_lightColors:Float[MAX_LIGHTS*4]
Global rs_lightVectors:Float[MAX_LIGHTS*4]
Global rs_shadowTexture:TTexture
Global rs_program:TGLProgram
Global rs_material:TMaterial
Global rs_blend:Int=-1
Global rs_vbo:Int
Global rs_ibo:Int

Const VBO_USAGE:Int=GL_STREAM_DRAW
Const VBO_ORPHANING_ENABLED:Int=False

Const MAX_LIGHTS:Int=4
Const BYTES_PER_VERTEX:Int=28

'can really be anything <64K (due to 16bit indices) but this keeps total VBO size<64K, and making it bigger doesn't seem to improve performance much.
Const MAX_VERTICES:Int=65536/BYTES_PER_VERTEX	

Const MAX_QUADS:Int=MAX_VERTICES/4
Const MAX_QUAD_INDICES:Int=MAX_QUADS*6
Const PRIM_VBO_SIZE:Int=MAX_VERTICES*BYTES_PER_VERTEX

Function IsPow2:Int( sz:Int )
	Return (sz & (sz-1))=0
End Function

Public

Type TLightData
	Field kind:Int=0
	Field color:Float[]=[1.0,1.0,1.0,1.0]
	Field position:Float[]=[0.0,0.0,-10.0]
	Field Range:Float=10
	'
	Field vector:Float[]=[0.0,0.0,-10.0,1.0]
	Field tvector:Float[4]
End Type

Private

Function InitVbos()
	If vbosSeq=graphicsSeq 
		BindVbos()
		Return
	EndIf
	vbosSeq=graphicsSeq

	glGenBuffers 1, Varptr rs_vbo
	glBindBuffer GL_ARRAY_BUFFER,rs_vbo
	glBufferData GL_ARRAY_BUFFER,PRIM_VBO_SIZE,Null,VBO_USAGE
	
	glEnableVertexAttribArray 0
	glVertexAttribPointer 0,2,GL_FLOAT,False,BYTES_PER_VERTEX,Byte Ptr(0)
	
	glEnableVertexAttribArray 1
	glVertexAttribPointer 1,2,GL_FLOAT,False,BYTES_PER_VERTEX,Byte Ptr(8)
	
	glEnableVertexAttribArray 2
	glVertexAttribPointer 2,2,GL_FLOAT,False,BYTES_PER_VERTEX,Byte Ptr(16)
	
	glEnableVertexAttribArray 3
	glVertexAttribPointer 3,4,GL_UNSIGNED_BYTE,True,BYTES_PER_VERTEX,Byte Ptr(24)
	
	glGenBuffers(1, Varptr rs_ibo)
	glBindBuffer GL_ELEMENT_ARRAY_BUFFER,rs_ibo
	Local idxs:TBank=New TBank.Create( MAX_QUAD_INDICES*4*2 )
?bmxng
	For Local j:Size_t = 0 Until 4
		Local k:Size_T = j*MAX_QUAD_INDICES*2
		For Local i:Size_T = 0 Until MAX_QUADS
?Not bmxng
	For Local j:Int = 0 Until 4
		Local k:Int = j*MAX_QUAD_INDICES*2
		For Local i:Int = 0 Until MAX_QUADS
?
			idxs.PokeShort i*12+k+0,Int(i*4+j+0)
			idxs.PokeShort i*12+k+2,Int(i*4+j+1)
			idxs.PokeShort i*12+k+4,Int(i*4+j+2)
			idxs.PokeShort i*12+k+6,Int(i*4+j+0)
			idxs.PokeShort i*12+k+8,Int(i*4+j+2)
			idxs.PokeShort i*12+k+10,Int(i*4+j+3)
		Next
	Next
	glBufferData GL_ELEMENT_ARRAY_BUFFER,Int(idxs.Size()),idxs._buf,GL_STATIC_DRAW
	'idxs.Discard
End Function

Function BindVbos()
	glBindBuffer( GL_ARRAY_BUFFER,rs_vbo )
	glEnableVertexAttribArray( 0 ) ; glVertexAttribPointer 0,2,GL_FLOAT,False,BYTES_PER_VERTEX, Byte Ptr(0)
	glEnableVertexAttribArray( 1 ) ; glVertexAttribPointer 1,2,GL_FLOAT,False,BYTES_PER_VERTEX, Byte Ptr(8)
	glEnableVertexAttribArray( 2 ) ; glVertexAttribPointer 2,2,GL_FLOAT,False,BYTES_PER_VERTEX, Byte Ptr(16)
	glEnableVertexAttribArray( 3 ) ; glVertexAttribPointer 3,4,GL_UNSIGNED_BYTE,True,BYTES_PER_VERTEX, Byte Ptr(24)

	glBindBuffer( GL_ELEMENT_ARRAY_BUFFER,rs_ibo )
End Function

Global inited:Int

Function InitMojo2()
	If inited Return
	inited=True

?Not opengles
	glewInit()
?
	
	InitVbos
	
	glGetIntegerv GL_FRAMEBUFFER_BINDING, Varptr defaultFbo
	
	mainShader=LoadString( "incbin::data/mojo2_program.glsl" )
	
	_fastShader=New TShader.Create( LoadString( "incbin::data/mojo2_fastshader.glsl" ) )
	_bumpShader=New TBumpShader.Create( LoadString( "incbin::data/mojo2_bumpshader.glsl" ) )
	_matteShader=New TMatteShader.Create( LoadString( "incbin::data/mojo2_matteshader.glsl" ) )
	_shadowShader=New TShader.Create( LoadString( "incbin::data/mojo2_shadowshader.glsl" ) )
	_lightMapShader=New TShader.Create( LoadString( "incbin::data/mojo2_lightmapshader.glsl" ) )
	_defaultShader=_bumpShader

	defaultFont=TFont.Load( "incbin::data/mojo2_font.png",32,96,True )'9,13,1,0,7,13,32,96 )
	If Not defaultFont Throw "Can't load default font"
	
	flipYMatrix[5]=-1
End Function

Public

Type TRefCounted

	Method Retain()
		If _refs<=0 Throw "Internal error"
		_refs:+1
	End Method
	
	Method Free()
		If _refs<=0 Throw "Internal error"
		_refs:-1
		If _refs Return
		_refs=-1
		Destroy
	End Method
	
	Method Destroy() Abstract

	Field _refs:Int=1
End Type

'***** Texture *****

Rem
bbdoc: Textures contains image data for use by shaders when rendering.
about: For more information, please see the #TShader type.
end rem
Type TTexture Extends TRefCounted

	'flags
	Const Filter:Int=1
	Const Mipmap:Int=2
	Const ClampS:Int=4
	Const ClampT:Int=8
	Const ClampST:Int=12
	Const RenderTarget:Int=16
	Const Managed:Int=256

	Rem
	bbdoc: Creates a new texture.
	about: The @width and @height are parameters are the size of the new texture.
	The @format parameter must be 4.
	The @flags parameter can be a bitwise combination of:
	| @ Flags				| @Description
	| Texture.Filter			| The texture is filtered when magnified
	| Texture.Mipmap			| The texture is mipmapped when minified
	| Texture.ClampS			| Texture S coordinate is clamped
	| Texture.ClampT			| Texture T coordinate is clamped
	| Texture.ClampST		| Texture S and T coordinates are clamped.
	| Texture.RenderTarget	| The texture can rendered to using a #Canvas.
	| Texture.Managed		| Texture contents are preserved when graphics are lost
	End Rem
	Method Create:TTexture( width:Int,height:Int,format:Int,flags:Int, data:TPixmap = Null )

		If format<>PF_RGBA8888 Then
			Throw "Invalid texture format: "+format
		End If

		'can't mipmap NPOT textures on gles20
		If Not IsPow2( width ) Or Not IsPow2( height ) flags:&~Mipmap
		
		_width=width
		_height=height
		_format=format
		_flags=flags
		_data=data

		If _flags & Managed
			_managed=New TPixmap.Create( width,height,PF_RGBA8888 )
			If _data
				_managed.Paste( _data,0,0 )
				_data=Null
			Else
				_managed.ClearPixels( $ffff00ff )
			EndIf
		EndIf
		
		Validate()

		Return Self
	End Method
	
	Method Destroy()
		If _seq=graphicsSeq glDeleteTextures 1, Varptr _glTexture
		_glTexture=0
		_glFramebuffer=0
	End Method
	
	Rem
	bbdoc: Gets texture width.
	end rem
	Method Width:Int()
		Return _width
	End Method
	
	Rem
	bbdoc: Gets texture height.
	end rem
	Method Height:Int()
		Return _height
	End Method
	
	Rem
	bbdoc: Gets texture format.
	end rem
	Method Format:Int()
		Return _format
	End Method
	
	Rem
	bbdoc: Gets texture flags.
	end rem
	Method Flags:Int()
		Return _flags
	End Method

	Rem
	bbdoc: Writes pixel data to texture.
	about: Pixels should be in premultiplied alpha format.
	end rem
	Method WritePixels( x:Int,y:Int,width:Int,height:Int,data:TPixmap,dataOffset:Int=0,dataPitch:Int=0 )

		glPushTexture2d GLTexture()
	
		If Not dataPitch Or dataPitch=width*4
		
			glTexSubImage2D GL_TEXTURE_2D,0,x,y,width,height,GL_RGBA,GL_UNSIGNED_BYTE,data.pixels + dataOffset
			
		Else
			For Local iy:Int=0 Until height
				glTexSubImage2D GL_TEXTURE_2D,0,x,y+iy,width,1,GL_RGBA,GL_UNSIGNED_BYTE,data.pixels + dataOffset+iy*dataPitch
			Next
		EndIf
		
		glPopTexture2d
		
		If _flags & Managed
		
			Local texPitch:Int=_width*4
			If Not dataPitch dataPitch=width*4
			
			For Local iy:Int=0 Until height
?bmxng
				MemCopy _data.pixels + (y+iy)*texPitch+x*4, data.pixels + dataOffset+iy*dataPitch, Size_T(width*4)
?Not bmxng
				MemCopy _data.pixels + (y+iy)*texPitch+x*4, data.pixels + dataOffset+iy*dataPitch, width*4
?
			Next
			
		EndIf

	End Method

	Method SetData( x:Int,y:Int,pixmap:TPixmap )
		
		If _managed
			If pixmap<>_managed _managed.Paste( pixmap,x,y )
		Else If _data
			If pixmap<>_data Throw "Texture is read only" 
		EndIf
		
		glPushTexture2d( GLTexture() )
		
		Local width:Int=pixmap.Width
		Local height:Int=pixmap.Height
		
		If pixmap.Pitch=_width*4
		
			glTexSubImage2D( GL_TEXTURE_2D,0,x,y,width,height,GL_RGBA,GL_UNSIGNED_BYTE,pixmap.pixels )
			
		Else
		
			For Local iy:Int=0 Until height
				glTexSubImage2D( GL_TEXTURE_2D,0,x,y+iy,width,1,GL_RGBA,GL_UNSIGNED_BYTE,pixmap.PixelPtr( 0,iy ) )
			Next
			
		EndIf
		
		glPopTexture2d
		
	End Method
		
	Method UpdateMipmaps()
		If Not (_flags & Mipmap) Return
			
		If _seq<>graphicsSeq
			Validate()
			Return
		EndIf

		glPushTexture2d GLTexture()

		glGenerateMipmap GL_TEXTURE_2D
		
		glPopTexture2d
	End Method
	
	Method Loading:Int()
			Return False
	End Method
	
	Method GLTexture:Int()
		Validate
		Return _glTexture
	End Method
	
	Method GLFramebuffer:Int()
		Validate
		Return _glFramebuffer
	End Method
	
	Function TexturesLoading:Int()
			Return 0
	End Function
	
	Rem
	bbdoc: Loads a texture from a url.
	end rem
	Function Load:TTexture( url:Object,format:Int=PF_RGBA8888,flags:Int=Filter|Mipmap|ClampST )
	
		Local info:Int[2]
		
		Local data:TPixmap=LoadPixmap(url)
		If Not data Return Null
		
		' convert to RGBA
		If data.format <> format Then
			data = data.Convert(format)
		End If
		
		PremultiplyAlpha(data)
			
		Local tex:TTexture=New TTexture.Create( data.width,data.height,format,flags,data )
		
		Return tex
	End Function

	Function PremultiplyAlpha(pix:TPixmap)
		For Local y:Int=0 Until pix.height
			For Local x:Int=0 Until pix.width
				Local pixel:Int=pix.ReadPixel( x,y )
				Local a:Int=pixel Shr 24 & 255
				Local b:Int=(pixel Shr 16 & 255)*a/255
				Local g:Int=(pixel Shr 8 & 255)*a/255
				Local r:Int=(pixel & 255)*a/255
				pixel=a Shl 24 | b Shl 16 | g Shl 8 | r
				pix.WritePixel( x,y,pixel )
			Next
		Next
	End Function
	
	Function Color:TTexture( color:Int )
?bmxng
		Local tex:TTexture=TTexture(_colors.ValueForKey( color ))
?Not bmxng
		Local c:TIntVal = New TIntVal
		c.value = color
		Local tex:TTexture=TTexture(_colors.ValueForKey( c ))
?
		If tex Return tex

		Local pixmap:TPixmap=New TPixmap.Create( 1,1,PF_RGBA8888 )
		pixmap.ClearPixels( color )

		tex=New TTexture.Create( 1,1,PF_RGBA8888,ClampST,pixmap )
?bmxng
		_colors.Insert color,tex
?Not bmxng
		_colors.Insert c,tex
?
		Return tex
	End Function
	
	Rem
	bbdoc: Returns a stock single texel black texture.
	end rem
	Function Black:TTexture()
		If Not _black _black=Color( $ff000000 )
		Return _black
	End Function
	
	Rem
	bbdoc: Returns a stock single texel white texture.
	end rem
	Function White:TTexture()
		If Not _white _white=Color( $ffffffff )
		Return _white
	End Function
	
	Rem
	bbdoc: Returnss a stock single texel magenta texture.
	end rem
	Function Magenta:TTexture()
		If Not _magenta _magenta=Color( $ffff00ff )
		Return _magenta
	End Function
	
	Rem
	bbdoc: Returns a stock single texel 'flat' texture for normal mapping.
	end rem
	Function Flat:TTexture()
		If Not _flat _flat=Color( $ff888888 )
		Return _flat
	End Function
	
	Method Data:TPixmap()
		Return _data
	End Method
	
?bmxng	
	Private
?
	Field _seq:Int
	Field _width:Int
	Field _height:Int
	Field _format:Int
	Field _flags:Int
	Field _data:TPixmap
	Field _managed:TPixmap
	
	Field _glTexture:Int
	Field _glFramebuffer:Int

?bmxng
	Global _colors:TIntMap=New TIntMap
?Not bmxng
	Global _colors:TMap=New TMap
?
	Global _black:TTexture
	Global _white:TTexture
	Global _magenta:TTexture
	Global _flat:TTexture

	Method Validate()
		
		If _seq=graphicsSeq Return
		
		InitMojo2()
	
		_seq=graphicsSeq
	
		glGenTextures(1, Varptr _glTexture)
		
		glPushTexture2d _glTexture
		
		If _flags & Filter
			glTexParameteri GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR
		Else
			glTexParameteri GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST
		EndIf
		If (_flags & Mipmap) And (_flags & Filter)
			glTexParameteri GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR
		Else If _flags & Mipmap
			glTexParameteri GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST_MIPMAP_NEAREST
		Else If _flags & Filter
			glTexParameteri GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR
		Else
			glTexParameteri GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST
		EndIf

		If _flags & ClampS glTexParameteri GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE
		If _flags & ClampT glTexParameteri GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE

		glTexImage2D GL_TEXTURE_2D,0,GL_RGBA,_width,_height,0,GL_RGBA,GL_UNSIGNED_BYTE,Null

		glPopTexture2d
		
		If _flags & RenderTarget
		
			glGenFramebuffers(1, Varptr _glFramebuffer)
			
			glPushFramebuffer _glFramebuffer
			
			glBindFramebuffer GL_FRAMEBUFFER,_glFramebuffer
			glFramebufferTexture2D GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,_glTexture,0
			
			If glCheckFramebufferStatus( GL_FRAMEBUFFER )<>GL_FRAMEBUFFER_COMPLETE Throw "Incomplete framebuffer"
			
			glPopFramebuffer
			
		EndIf
		
		If _managed Then

			SetData( 0,0,_managed )
			UpdateMipmaps()
			
		Else If _data
		
			SetData( 0,0,_data )
			UpdateMipmaps()
		
		EndIf
		
	End Method
	
	Method LoadData( data:TPixmap )
		glPushTexture2d GLTexture()
		
		glTexImage2D GL_TEXTURE_2D,0,GL_RGBA,_width,_height,0,GL_RGBA,GL_UNSIGNED_BYTE,data.pixels

		glPopTexture2d
		
		UpdateMipmaps
	End Method
	
End Type

'***** Shader ****

Public

Type TGLUniform
	Field name:String
	Field location:Int
	Field size:Int
	Field kind:Int
	
	Method Create:TGLUniform( name:String,location:Int,size:Int,kind:Int )
		Self.name=name
		Self.location=location
		Self.size=size
		Self.kind=kind
		Return Self
	End Method
	
End Type

Type TGLProgram
	Field program:Int
	'material uniforms
	Field matuniforms:TGLUniform[]
	'hard coded uniform locations
	Field mvpMatrix:Int
	Field mvMatrix:Int
	Field clipPosScale:Int
	Field globalColor:Int
	Field AmbientLight:Int
	Field fogColor:Int
	Field lightColors:Int
	Field lightVectors:Int
	Field shadowTexture:Int
	
	Method Create:TGLProgram( program:Int,matuniforms:TGLUniform[] )
		Self.program=program
		Self.matuniforms=matuniforms
		mvpMatrix=glGetUniformLocation( program,"ModelViewProjectionMatrix" )
		mvMatrix=glGetUniformLocation( program,"ModelViewMatrix" )
		clipPosScale=glGetUniformLocation( program,"ClipPosScale" )
		globalColor=glGetUniformLocation( program,"GlobalColor" )
		fogColor=glGetUniformLocation( program,"FogColor" )
		AmbientLight=glGetUniformLocation( program,"AmbientLight" )
		lightColors=glGetUniformLocation( program,"LightColors" )
		lightVectors=glGetUniformLocation( program,"LightVectors" )
		shadowTexture=glGetUniformLocation( program,"ShadowTexture" )
		Return Self
	End Method
	
	Method Bind()
	
		glUseProgram program
		
		If mvpMatrix<>-1 glUniformMatrix4fv mvpMatrix,1,False,rs_modelViewProjMatrix
		If mvMatrix<>-1 glUniformMatrix4fv mvMatrix,1,False,rs_modelViewMatrix
		If clipPosScale<>-1 glUniform4fv clipPosScale,1,rs_clipPosScale
		If globalColor<>-1 glUniform4fv globalColor,1,rs_globalColor
		If fogColor<>-1 glUniform4fv fogColor,1,rs_fogColor
		If AmbientLight<>-1 glUniform4fv AmbientLight,1,rs_ambientLight
		If lightColors<>-1 glUniform4fv lightColors,rs_numLights,rs_lightColors
		If lightVectors<>-1 glUniform4fv lightVectors,rs_numLights,rs_lightVectors
		glActiveTexture GL_TEXTURE0+7
		If shadowTexture<>-1 And rs_shadowTexture
			glBindTexture GL_TEXTURE_2D,rs_shadowTexture.GLTexture()
			glUniform1i shadowTexture,7
		Else
			glBindTexture GL_TEXTURE_2D,TTexture.White().GLTexture()
		End If
		glActiveTexture GL_TEXTURE0
	End Method
	
End Type

Public

Type TShader

	Method Create:TShader( source:String )
		Build source
		Return Self
	End Method
	
	Method DefaultMaterial:TMaterial()
		If Not _defaultMaterial _defaultMaterial=New TMaterial.Create( Self )
		Return _defaultMaterial
	End Method
	
	Function FastShader:TShader()
		Return _fastShader
	End Function
	
	Rem
	bbdoc: Returns a stock bump shader for drawing lit sprites with specular and normal maps.
	about: 
The following material properties are supported:

| @Property			| @Type		| @Default
| ColorTexture		| Texture	| White
| SpecularTexture	| Texture	| Black
| NormalTexture		| Texture	| Flat
| AmbientColor		| Float[4]	| [0.0,0.0,0.0,1.0]
| Roughness			| Float		| 0.5

The shader b3d_Ambient value is computed by multiplying ColorTexture by AmbientColor.

The shader b3d_Diffuse value is computed by multiplying ColorTexture by 1-AmbientColor.

When loading materials that use the bump shader, diffuse, specular and normal maps can be given the following files names:

| @Texture map		| @Valid paths
| Diffuse			| (FILE).(EXT) ; (FILE)_d.(EXT) ; (FILE)_diff.(EXT) ; (FILE)_diffuse.(EXT)
| Specular			| (FILE)_s.(EXT) ; (FILE)_spec.(EXT) ; (FILE)_specular.(EXT) ;(FILE)_SPECUALR.(EXT)
| Normal			| (FILE)_n.(EXT) ; (FILE)_norm.(EXT) ; (FILE)_normal.(EXT) ; (FILE)_NORMALS.(EXT)

Where (FILE) is the filename component of the path provided to Material.Load or Image.Load, and (EXT) is the file extension, eg: png, jpg.
	end rem
	Function BumpShader:TShader()
		Return _bumpShader
	End Function
	
	Rem
	bbdoc: Returns a stock matte shader for drawing lit sprites with no specular or normal maps.
	about: 
The following material properties are supported:

| @Property			| @Type		| @Default
| ColorTexture		| Texture	| White
| AmbientColor		| Float[4]	| [0.0,0.0,0.0,1.0]
| Roughness			| Float		| 0.5
	end rem
	Function MatteShader:TShader()
		Return _matteShader
	End Function
	
	Rem
	bbdoc: Returns a stock shadow shader for drawing shadows.
	about: This shader simply writes 'black' to b3d_FragColor.
	end rem
	Function ShadowShader:TShader()
		Return _shadowShader
	End Function
	
	Rem
	bbdoc: Returns a stock shader for drawing light textures and light mask effects.
	about: 
This shader performs a texture lookup, and writes the red component to b3d_FragColor.
	
The following material properties are supported:

| @Property			| @Type		| @Default
| ColorTexture		| Texture	| White
	end rem	
	Function LightMapShader:TShader()
		Return _lightMapShader
	End Function
	
	Rem
	bbdoc: Returns the default shader used when a material is created with a 'Null' shader.
	about: This is initially the #BumpShader, but can be modified using #SetDefaultShader.
	end rem
	Function DefaultShader:TShader()
		Return _defaultShader
	End Function
	
	Rem
	bbdoc: Sets the default shader used when a material is created with a 'Null' shader.
	end rem
	Function SetDefaultShader( shader:TShader )
		If Not shader shader=_bumpShader
		_defaultShader=shader
	End Function
	
	'Protected
	
	Rem
	bbdoc: Compiles and links the shader.
	about: Types that extend Shader must call this method at some point. This is usually done in the subclasses constructor.
	end rem
	Method Build( source:String )
		_source=source
		BuildInit
	End Method
	
	Rem
	bbdoc: Types that extend Shader must set defalut values for all valid shader parameters in this method.
	end rem
	Method OnInitMaterial( material:TMaterial )
		material.SetTexture "ColorTexture",TTexture.White()
	End Method
	
	Rem
	bbdoc: Classes that extend Shader should load textures and other valid shader parameters from @path into @material in this method.
	about: The interpretation of @path is completely up to the shader. The @texFlags parameter contains texture flag values that should be used for any textures loaded.
	The @material parameter is an already initialized material.
	This method should return @material if successful, or null on failure.
	end rem
	Method OnLoadMaterial:TMaterial( material:TMaterial,url:Object,texFlags:Int )
		Local texture:TTexture=TTexture.Load( url,PF_RGBA8888,texFlags )
		If Not texture Return Null
		material.SetTexture "ColorTexture",texture
		If texture texture.Free
		Return material
	End Method
	
	'Private
	
	Const MAX_FLAGS:Int=8
	
	Field _seq:Int
	Field _source:String
	
	Field _vsource:String
	Field _fsource:String
?bmxng
	Field _uniforms:TStringMap=New TStringMap
?Not bmxng
	Field _uniforms:TMap=New TMap
?	
	Field _glPrograms:TGLProgram[MAX_LIGHTS+1]
	
	Field _defaultMaterial:TMaterial
	
	Method Bind()	
		Local program:TGLProgram=GLProgram()
		
		If program=rs_program Return

		rs_program=program
		rs_material=Null
		
		program.Bind
	End Method
	
	Method GLProgram:TGLProgram()
	
		If _seq<>graphicsSeq 
			_seq=graphicsSeq
			rs_program=Null
			BuildInit
		EndIf
		
		Return _glPrograms[rs_numLights]
	End Method
	
	Method BuildProgram:TGLProgram( numLights:Int )

		Local defs:String=""
		defs:+"#define NUM_LIGHTS "+numLights+"~n"

		Local vshader:Int=glCompile( GL_VERTEX_SHADER,defs+_vsource )
		Local fshader:Int=glCompile( GL_FRAGMENT_SHADER,defs+_fsource )
		
		Local program:Int=glCreateProgram()
		glAttachShader program,vshader
		glAttachShader program,fshader
		glDeleteShader vshader
		glDeleteShader fshader
		
		glBindAttribLocation program,0,"Position"
		glBindAttribLocation program,1,"Texcoord0"
		glBindAttribLocation program,2,"Tangent"
		glBindAttribLocation program,3,"Color"
		
		glLink program
		
		'enumerate program uniforms	
		Local matuniforms:TGLUniform[] = New TGLUniform[0]
		Local size:Int
		Local kind:Int
		Local buf:Byte[1024]
		Local l:Int
		Local n:Int
		glGetProgramiv program,GL_ACTIVE_UNIFORMS, Varptr n
		For Local i:Int=0 Until n
			glGetActiveUniform program,i,1024,Varptr l,Varptr size, Varptr kind, buf
			Local name:String = String.FromBytes(buf, l)
			If _uniforms.Contains( name )
				Local location:Int=glGetUniformLocation( program,name )
				If location=-1 Continue  'IE fix...
				matuniforms :+ [New TGLUniform.Create( name,location,size,kind )]
'				Print name[0]+"->"+location
			EndIf
		Next
		
		Return New TGLProgram.Create( program,matuniforms )
	
	End Method
	
	Method BuildInit()
		InitMojo2

		Local p:TGlslParser=TGlslParser(New TGlslParser.Create( _source ))

		Local vars:TMap=New TMap
		
		While p.Toke()
		
			If p.CParse( "uniform" )
				'uniform decl
				Local ty:String=p.ParseType()
				Local id:String=p.ParseIdent()
				p.ParseToke ";"
				_uniforms.Insert id, id
'				Print "uniform "+ty+" "+id+";"
				Continue
			EndIf
			
			Local id:String=p.CParseIdent()
			If id
				If id.StartsWith( "gl_" )
					vars.Insert "B3D_"+id.ToUpper(), ""
				Else If id.StartsWith( "b3d_" ) 
					vars.Insert id.ToUpper(), ""
				EndIf
				Continue
			EndIf
			
			p.Bump
		Wend
		
		Local vardefs:String=""
		For Local v:String=EachIn vars.Keys()
			vardefs:+"#define "+v+" 1~n"
		Next
		
'		Print "Vardefs:";Print vardefs
		
		Local source:String=mainShader
		Local i0:Int=source.Find( "//@vertex" )
		If i0=-1 Throw "Can't find //@vertex chunk"
		Local i1:Int=source.Find( "//@fragment" )
		If i1=-1 Throw "Can't find //@fragment chunk"
		
		Local header:String=vardefs+source[..i0]
		_vsource=header+source[i0..i1]
		_fsource=header+source[i1..].Replace( "${SHADER}",_source )
		
		For Local numLights:Int=0 To MAX_LIGHTS
		
			_glPrograms[numLights]=BuildProgram( numLights )

			If numLights Or vars.Contains( "B3D_DIFFUSE" ) Or vars.Contains( "B3D_SPECULAR" ) Continue
			
			For Local i:Int=1 To MAX_LIGHTS
				_glPrograms[i]=_glPrograms[0]
			Next
			
			Exit
			
		Next
		
		
	End Method
	
End Type

Type TBumpShader Extends TShader

'	Method New( source:String )
'		Super.New( source )
'	End

	'Protected
	
	Method OnInitMaterial( material:TMaterial )
		material.SetTexture "ColorTexture",TTexture.White()
		material.SetTexture "SpecularTexture",TTexture.Black()
		material.SetTexture "NormalTexture",TTexture.Flat()
		material.SetVector "AmbientColor",[1.0,1.0,1.0,1.0]
		material.SetScalar "Roughness",1.0
	End Method
	
	Method OnLoadMaterial:TMaterial( material:TMaterial,url:Object,texFlags:Int )

		Local format:Int = PF_RGBA8888
	
		Local path:String = String(url)
	
		Local colorTex:TTexture
		Local specularTex:TTexture
		Local normalTex:TTexture
	
		If Not path Then
			colorTex=TTexture.Load( url,format,texFlags )
		Else
			Local ext:String = ExtractExt( path )
			If ext path=StripExt( path ) Else ext="png"
			
			colorTex=TTexture.Load( path+"."+ext,format,texFlags )
			If Not colorTex colorTex=TTexture.Load( path+"_d."+ext,format,texFlags )
			If Not colorTex colorTex=TTexture.Load( path+"_diff."+ext,format,texFlags )
			If Not colorTex colorTex=TTexture.Load( path+"_diffuse."+ext,format,texFlags )
			
			specularTex = TTexture.Load( path+"_s."+ext,format,texFlags )
			If Not specularTex specularTex=TTexture.Load( path+"_spec."+ext,format,texFlags )
			If Not specularTex specularTex=TTexture.Load( path+"_specular."+ext,format,texFlags )
			If Not specularTex specularTex=TTexture.Load( path+"_SPECULAR."+ext,format,texFlags )
			
			normalTex = TTexture.Load( path+"_n."+ext,format,texFlags )
			If Not normalTex normalTex=TTexture.Load( path+"_norm."+ext,format,texFlags )
			If Not normalTex normalTex=TTexture.Load( path+"_normal."+ext,format,texFlags )
			If Not normalTex normalTex=TTexture.Load( path+"_NORMALS."+ext,format,texFlags )

		End If
		
		If Not colorTex And Not specularTex And Not normalTex Return Null

		material.SetTexture "ColorTexture",colorTex
		material.SetTexture "SpecularTexture",specularTex
		material.SetTexture "NormalTexture",normalTex
		
		If specularTex Or normalTex
			material.SetVector "AmbientColor",[0.0,0.0,0.0,1.0]
			material.SetScalar "Roughness",.5
		EndIf
		
		If colorTex colorTex.Free
		If specularTex specularTex.Free
		If normalTex normalTex.Free
		
		Return material
	End Method
	
End	Type

Type TMatteShader Extends TShader

'	Method Create( source:String )
'		Super.New( source )
'	End
	
'	Protected
	
	Method OnInitMaterial( material:TMaterial )
		material.SetTexture "ColorTexture",TTexture.White()
		material.SetVector "AmbientColor",[0.0,0.0,0.0,1.0]
		material.SetScalar "Roughness",1.0
	End Method
	
End Type

'***** Material *****

Rem
bbdoc: Materials contain shader parameters that map to shader uniforms variables when rendering. 
End Rem
Type TMaterial Extends TRefCounted

	Rem
	bbdoc: Creates a new material.
	End Rem
	Method Create:TMaterial( shader:TShader=Null )
		InitMojo2
		
		If Not shader shader=_defaultShader
		_shader=shader
		_shader.OnInitMaterial( Self )
		_inited=True
		
		Return Self
	End Method
	
	Method Destroy()
		For Local tex:TTexture=EachIn _textures
			tex.Free()
		Next
	End Method
	
	Rem
	bbdoc: Gets material shader.
	End Rem
	Method Shader:TShader() 
		Return _shader
	End Method
	
	Method ColorTexture:TTexture()
		Return _colorTexture
	End Method
	
	Method Width:Int()
		If _colorTexture Return _colorTexture.Width()
		Return 0
	End Method
	
	Method Height:Int()
		If _colorTexture Return _colorTexture.Height()
		Return 0
	End Method
	
	Rem
	bbdoc: Sets float shader parameter.
	End Rem
	Method SetScalar( param:String,scalar:Float )
		If _inited And Not _scalars.Contains( param ) Return
		_scalars.Insert param,scalar
	End Method
	
	Rem
	bbdoc: Gets float shader parameter.
	End Rem
	Method GetScalar:Float( param:String,defValue:Float=1.0 )
		If Not _scalars.Contains( param ) Return defValue
		Return _scalars.ValueForKey( param )
	End Method
	
	Rem
	bbdoc: Sets vector shader parameter.
	End Rem
	Method SetVector( param:String,vector:Float[] )
		If _inited And Not _vectors.Contains( param ) Return
		_vectors.Insert param,vector
	End Method
	
	Rem
	bbdoc: Gets vector shader parameter.
	End Rem
?bmxng
	Method GetVector:Float[]( param:String,defValue:Float[]=[1.0,1.0,1.0,1.0] )
		If Not _vectors.Contains( param ) Return defValue
		Return _vectors.ValueForKey( param )
?Not bmxng
	Method GetVector:Float[]( param:String,defValue:Float[]=Null )
		If Not _vectors.Contains( param ) Then
			If defValue Then
				Return defValue
			Else
				Return [1.0,1.0,1.0,1.0]
			End If
		End If
		Return Float[](_vectors.ValueForKey( param ))
?
	End Method
	
	Rem
	bbdoc: Sets texture shader parameter.
	End Rem
	Method SetTexture( param:String,texture:TTexture )
		If Not texture Return
		If _inited And Not _textures.Contains( param ) Return
		
		Local old:TTexture=TTexture(_textures.ValueForKey( param ))
		texture.Retain
		_textures.Insert param,texture
		If old old.Free
		
		If param="ColorTexture" _colorTexture=texture
		
	End Method
	
	Rem
	bbdoc: Gets texture shader parameter.
	End Rem
	Method GetTexture:TTexture( param:String,defValue:TTexture=Null )
		If Not _textures.Contains( param ) Return defValue
		Return TTexture(_textures.ValueForKey( param ))
	End Method
	
	Method Loading:Int()
		Return False
	End Method
	
	Rem
	bbdoc: Loads a material.
	about: If @shader is null, the TShader.DefaultShader is used.
	End Rem
	Function Load:TMaterial( url:Object,texFlags:Int,shader:TShader )
	
		Local material:TMaterial=New TMaterial.Create( shader )

		material=material.Shader().OnLoadMaterial( material,url,texFlags )
		
		Return material
	End Function
	
	'Private
	
	Field _shader:TShader
	Field _colorTexture:TTexture
	Field _scalars:TStringFloatMap=New TStringFloatMap
?bmxng
	Field _vectors:TStringMap=New TStringMap
	Field _textures:TStringMap=New TStringMap
?Not bmxng
	Field _vectors:TMap=New TMap
	Field _textures:TMap=New TMap
?
	Field _inited:Int
	
	Method Bind:Int()
	
		_shader.Bind
		
		If rs_material=Self Return True
		
		rs_material=Self
	
		Local texid:Int=0
		
		For Local u:TGLUniform=EachIn rs_program.matuniforms
			Select u.kind
			Case GL_FLOAT
				glUniform1f u.location,GetScalar( u.name )
			Case GL_FLOAT_VEC4
				glUniform4fv u.location,1,GetVector( u.name )
			Case GL_SAMPLER_2D
				Local tex:TTexture=GetTexture( u.name )
'				If tex.Loading
'					rs_material=Null 
'					Exit
'				Endif
				glActiveTexture GL_TEXTURE0+texid
				glBindTexture GL_TEXTURE_2D,tex.GLTexture()
				glUniform1i u.location,texid
				texid:+1
			Default
				Throw "Unsupported uniform type:"+u.kind 
			End Select
		Next

		If texid glActiveTexture GL_TEXTURE0
		
		Return rs_material=Self
	End Method
	
End Type

'***** ShaderCaster *****

Rem
bbdoc: The ShadowCaster class provides support for simple 2d shadow rendering.
about: Shadow casters are used by #Renderer objects when rendering layers. To render shadows, you will need to add
shadow casters to the drawlists returned by ILayer.OnRenderLayer.
A shadow caster can either be added to a drawlist using [[DrawList.AddShadowCaster]], or attached to images using [[Image.SetShadowCaster]]. Shadow casters attached to images are automatically added to drawlists when an image is drawn.
A shadow caster contains a set of 2d vertices which describe the geometric shape of the object that casts a shadow. The vertices should describe a convex polygon.
End Rem
Type TShadowCaster

	Method Create:TShadowCaster( verts:Float[] = Null,kind:Int = -1 )
		If verts Then
			_verts=verts
		End If
		If kind >= 0 Then
			_kind=kind
		End If
		Return Self
	End Method
	
	Rem
	bbdoc: Set shadow caster vertices.
	end rem
	Method SetVertices( vertices:Float[] )
		_verts=vertices
	End Method
	
	Rem
	bbdoc: Get shadow caster vertices.
	end rem
	Method Vertices:Float[]()
		Return _verts
	End Method

	Method SetKind( kind:Int )
		_kind=kind
	End Method
	
	Method Kind:Int()
		Return _kind
	End Method
	
	'Private
	
	Field _verts:Float[]
	Field _kind:Int
	
End Type

'***** Image *****

Rem
bbdoc: An image is a rectangular area of pixels within a material, that can be drawn using one of the [[DrawList.DrawImage]] methods.
about: You can create a new image using one of the [[Image.Create]] methods, or load an image from file using [[Image.Load|Image.Load]].
An image also has a handle, an offset within the image that represents it's origin whan it is drawn. Image handles are specified in fractional values, where 0,0 is the top-left of an image, 1,1 is the bottom-right and .5,.5 is the center.
end rem
Type TImage

	Const Filter:Int=TTexture.Filter
	Const Mipmap:Int=TTexture.Mipmap
	Const Managed:Int=TTexture.Managed
	
	Rem
	bbdoc: Creates a new image for rendering.
	about: The new image can be used as a render target for a [[Canvas]].
The @flags parameter can be any bitwise combination of:
| @Flags			| @Description
| TImage.Filter		| The image is filtered
| TImage.Mipmap		| The image is mipmapped
| TImage.Managed	| The image is managed
The TImage.Managed flag should be used if you want mojo2 to preserve the image contents when the graphics mode changes. This is not necessary if the image is being re-rendered every frame.
TImage.Managed consumes more memory, and slows down image rendering somewhat so should be avoided if possible.
	End Rem
	Method Create:TImage( width:Int,height:Int,xhandle:Float=.5,yhandle:Float=.5,flags:Int=TImage.Filter )
		flags:&_flagsMask
		Local texture:TTexture=New TTexture.Create( width,height,PF_RGBA8888,flags|TTexture.ClampST|TTexture.RenderTarget )
		_material=New TMaterial.Create( _fastShader )
		_material.SetTexture "ColorTexture",texture
		_width=width
		_height=height
		SetHandle xhandle,yhandle
		Return Self
	End Method
	
	Rem
	bbdoc: Creates a new image from a region within an existing image.
	about: The new image shares the same material and image flags as @image.
	End Rem
	Method CreateImage:TImage( image:TImage,x:Int,y:Int,width:Int,height:Int,xhandle:Float=.5,yhandle:Float=.5 )
		_material=image._material
		_material.Retain
		_x=image._x+x
		_y=image._y+y
		_width=width
		_height=height
		SetHandle xhandle,yhandle
		Return Self
	End Method
	
	Rem
	bbdoc: Creates a new image from a material.
	End Rem
	Method CreateMaterial:TImage( material:TMaterial,xhandle:Float=.5,yhandle:Float=.5 )
		Local texture:TTexture=material.ColorTexture()
		If Not texture Throw "Material has no ColorTexture"
		_material=material
		_material.Retain
		_width=_material.Width()
		_height=_material.Height()
		SetHandle xhandle,yhandle
		Return Self
	End Method

	Rem
	bbdoc: Creates a new image representing a rect within a material.
	End Rem
	Method CreateMaterialRect:TImage( material:TMaterial,x:Int,y:Int,width:Int,height:Int,xhandle:Float=.5,yhandle:Float=.5 )
		Local texture:TTexture=material.ColorTexture()
		If Not texture Throw "Material has no ColorTexture"
		_material=material
		_material.Retain
		_x=x
		_y=y
		_width=width
		_height=height
		SetHandle xhandle,yhandle
		Return Self
	End Method

	Method Delete()
		Discard()
	End Method

	Rem
	bbdoc: Discards any internal resources such as videomem used by the image.
	End Rem
	Method Discard()
		If _material _material.Free
		_material=Null
	End Method
	
	Method Material:TMaterial()
		Return _material
	End Method
	
	Rem
	bbdoc: Gets x coordinate of the left edge of the image rect.
	End Rem
	Method X0:Float()
		Return _x0
	End Method
	
	Rem
	bbdoc: Gets y coordinate of the top edge of the image rect.
	End Rem
	Method Y0:Float()
		Return _y0
	End Method
	
	Rem
	bbdoc: Gets x coordinate of the right edge of the image rect.
	End Rem
	Method X1:Float()
		Return _x1
	End Method
	
	Rem
	bbdoc: Gets y coordinate of the bottom edge of the image rect.
	End Rem
	Method Y1:Float()
		Return _y1
	End Method
	
	Rem
	bbdoc: Gets image width.
	End Rem
	Method Width:Int()
		Return _width
	End Method
	
	Rem
	bbdoc: Gets image height.
	End Rem
	Method Height:Int()
		Return _height
	End Method
	
	Rem
	bbdoc: Gets image x handle.
	End Rem
	Method HandleX:Float()
		Return -_x0/(_x1-_x0)
	End Method
	
	Rem
	bbdoc: Gets image y handle.
	End Rem
	Method HandleY:Float()
		Return -_y0/(_y1-_y0)
	End Method
	
	Rem
	bbdoc: Writes pixel data to image.
	about: Pixels should be in premultiplied alpha format.
	End Rem
	Method WritePixels( x:Int,y:Int,width:Int,height:Int,data:TPixmap,dataOffset:Int=0,dataPitch:Int=0 )
		_material.ColorTexture().WritePixels( x+_x,y+_y,width,height,data,dataOffset,dataPitch )
	End Method
	
	Method SetHandle( xhandle:Float,yhandle:Float )
		_x0=Float(_width)*-xhandle
		_x1=Float(_width)*(1-xhandle)
		_y0=Float(_height)*-yhandle
		_y1=Float(_height)*(1-yhandle)
		_s0=Float(_x)/Float(_material.Width())
		_t0=Float(_y)/Float(_material.Height())
		_s1=Float(_x+_width)/Float(_material.Width())
		_t1=Float(_y+_height)/Float(_material.Height())
	End Method
	
	Rem
	bbdoc: Set image shadow caster.
	about: Attaching a shadow caster to an image will cause the shadow caster to be automatically added to the
	drawlist whenever the image is drawn.
	End Rem
	Method SetShadowCaster( shadowCaster:TShadowCaster )
		_caster=shadowCaster
	End Method
	
	Rem
	bbdoc: Gets attached shadow caster.
	End Rem
	Method ShadowCaster:TShadowCaster()
		Return _caster
	End Method
	
	Method Loading:Int()
		Return _material.Loading()
	End Method
	
	Function ImagesLoading:Int()
		Return TTexture.TexturesLoading()>0
	End Function
	
	Rem
	bbdoc: Sets an internal 'flags mask' that can be used to filter out specific image flags when creating images.
	about: The flags mask value is 'anded' with any flags values passed to Image.New, Image.Load or Image.LoadFrames.
	For example, by setting the flags mask to just Image.Managed, the Image.Filter and Image.Mipmap flags will be effectively disabled for all images - useful for pixel art or retro style graphics.
	The default flags mask is Image.Filter|Image.Mipmap|Image.Managed, which effectively disables the filter.
	End Rem
	Function SetFlagsMask( mask:Int )
		_flagsMask=mask
	End Function
	
	Rem
	bbdoc: Returns the current flags mask.
	End Rem
	Function FlagsMask:Int()
		Return _flagsMask
	End Function
	
	Rem
	bbdoc: 
	End Rem
	Function Load:TImage( url:Object,xhandle:Float=.5,yhandle:Float=.5,flags:Int=TImage.Filter|TImage.Mipmap,shader:TShader=Null )
		flags:&_flagsMask
	
		Local material:TMaterial=TMaterial.Load( url,flags|TTexture.ClampST,shader )
		If Not material Return Null

		Return New TImage.CreateMaterial( material,xhandle,yhandle )
	End Function
	
	Function LoadFrames:TImage[]( url:Object,numFrames:Int,padded:Int=False,xhandle:Float=.5,yhandle:Float=.5,flags:Int=TImage.Filter|TImage.Mipmap,shader:TShader=Null )
		flags:&_flagsMask
	
		Local material:TMaterial=TMaterial.Load( url,flags|TTexture.ClampST,shader )
		If Not material Return Null
		
		Local cellWidth:Int=material.Width()/numFrames
		Local cellHeight:Int=material.Height()
		
		Local x:Int=0
		Local width:Int=cellWidth
		If padded Then
			x:+1
			width:-2
		End If
		
		Local frames:TImage[]=New TImage[numFrames]
		
		For Local i:Int=0 Until numFrames
			frames[i]=New TImage.CreateMaterialRect( material,i*cellWidth+x,0,width,cellHeight,xhandle,yhandle )
		Next
		
		Return frames
	End Function
	
	'Private
	
	Global _flagsMask:Int=Filter|Mipmap|Managed
	
	Field _material:TMaterial
	Field _x:Int,_y:Int,_width:Int,_height:Int
	Field _x0:Float=-1,_y0:Float=-1,_x1:Float=1,_y1:Float=1
	Field _s0:Float=0 ,_t0:Float=0 ,_s1:Float=1,_t1:Float=1

	Field _caster:TShadowCaster
	
End Type

'***** Font *****

Type TGlyph
	Field image:TImage
	Field char:Int
	Field x:Int
	Field y:Int
	Field width:Int
	Field height:Int
	Field advance:Float
	
	Method Create:TGlyph( image:TImage,char:Int,x:Int,y:Int,width:Int,height:Int,advance:Float )
		Self.image=image
		Self.char=char
		Self.x=x
		Self.y=y
		Self.width=width
		Self.height=height
		Self.advance=advance
		Return Self
	End Method
End Type

Rem
bbdoc: Provides support for simple fixed width bitmap fonts.
End Rem
Type TFont

	Method Create:TFont( glyphs:TGlyph[],firstChar:Int,height:Float )
		_glyphs=glyphs
		_firstChar=firstChar
		_height=height
		Return Self
	End Method

	Method GetGlyph:TGlyph( char:Int )
		Local i:Int=char-_firstChar
		If i>=0 And i<_glyphs.Length Return _glyphs[i]
		Return Null
	End Method
	
	Rem
	bbdoc: Gets width of @text drawn in this font.
	End Rem
	Method TextWidth:Float( Text:String )
		Local w:Float=0.0
?bmxng
		For Local char:Int=EachIn Text
?Not bmxng
		For Local i:Int=0 Until Text.length
			Local char:Int = Text[i]
?
			Local glyph:TGlyph=GetGlyph( char )
			If Not glyph Continue
			w:+glyph.advance
		Next
		Return w
	End Method

	Rem
	bbdoc: Gets height of @text drawn in this font.
	End Rem
	Method TextHeight:Float( Text:String )
		Return _height
	End Method
	
	Rem
	bbdoc: Loads a fixed width font from @path.
	about: Glyphs should be laid out horizontally within the source image.
	If @padded is true, then each glyph is assumed to have a transparent one pixel padding border around it.
	End Rem
	Function Load:TFont( url:Object,firstChar:Int,numChars:Int,padded:Int )

		Local image:TImage=TImage.Load( url )
		If Not image Return Null
		
		Local cellWidth:Int=image.Width()/numChars
		Local cellHeight:Int=image.Height()
		Local glyphX:Int=0,glyphY:Int=0,glyphWidth:Int=cellWidth,glyphHeight:Int=cellHeight
		If padded glyphX:+1;glyphY:+1;glyphWidth:-2;glyphHeight:-2

		Local w:Int=image.Width()/cellWidth
		Local h:Int=image.Height()/cellHeight

		Local glyphs:TGlyph[]=New TGlyph[numChars]
		
		For Local i:Int=0 Until numChars
			Local y:Int=i / w
			Local x:Int=i Mod w
			Local glyph:TGlyph=New TGlyph.Create( image,firstChar+i,x*cellWidth+glyphX,y*cellHeight+glyphY,glyphWidth,glyphHeight,glyphWidth )
			glyphs[i]=glyph
		Next
		
		Return New TFont.Create( glyphs,firstChar,glyphHeight )
	
	End Function
	
	Function LoadSize:TFont( url:Object,cellWidth:Int,cellHeight:Int,glyphX:Int,glyphY:Int,glyphWidth:Int,glyphHeight:Int,firstChar:Int,numChars:Int )

		Local image:TImage=TImage.Load( url )
		If Not image Return Null

		Local w:Int=image.Width()/cellWidth
		Local h:Int=image.Height()/cellHeight

		Local glyphs:TGlyph[]=New TGlyph[numChars]
		
		For Local i:Int=0 Until numChars
			Local y:Int=i / w
			Local x:Int=i Mod w
			Local glyph:TGlyph=New TGlyph.Create( image,firstChar+i,x*cellWidth+glyphX,y*cellHeight+glyphY,glyphWidth,glyphHeight,glyphWidth )
			glyphs[i]=glyph
		Next
		
		Return New TFont.Create( glyphs,firstChar,glyphHeight )
	End Function
	
	'Private
	
	Field _glyphs:TGlyph[]
	Field _firstChar:Int
	Field _height:Float
	
End Type

'***** DrawList *****

Type TDrawOp
'	Field shader:Shader
	Field material:TMaterial
	Field blend:Int
	Field order:Int
	Field count:Int
End Type

Type TBlendMode
	Const Opaque:Int=0
	Const Alpha:Int=1
	Const Additive:Int=2
	Const Multiply:Int=3
	Const Multiply2:Int=4
End Type

Rem
bbdoc: A drawlist contains drawing state and a sequence of 2d drawing operations.
about:
You add drawing operations to a drawlist using any of the Draw methods. When a drawing operation is added, the current drawing state is captured by the drawing operation. Further changes to the drawing state will not affect drawing operations already in the drawlist.
A [[Canvas]] extends [[DrawList]], and can be used to draw directly to the app window or an image. A drawlist can also be rendered to a canvas using [[Canvas.RenderDrawList]].
A drawlist's drawing state consists of:
| @Drawing state			| @Description
| Current color			| [[SetColor]]
| Current 2d matrix		| [[Translate]], [[Rotate]], [[Scale]], [[PushMatrix]], [[PopMatrix]]
| Current blend mode		| [[SetBlendMode]]
| Current font			| [[DrawText]]
End Rem
Type TDrawList

	Method New()
		InitMojo2
		
		_color = __colorArray
		
		SetFont Null
		SetDefaultMaterial _fastShader.DefaultMaterial()
	End Method
	
	Method SetBlendMode( blend:Int )
		_blend=blend
	End Method
	
	Method BlendMode:Int()
		Return _blend
	End Method
	
	Method SetColor( r:Float,g:Float,b:Float,a:Float = -1 )
		Local c:Float Ptr = _color
		c[0]=r
		c[1]=g
		c[2]=b
		If a >= 0
			c[3]=a
			_alpha=a*255
		End If
		_pmcolor=Int(_alpha) Shl 24 | Int(c[2]*_alpha) Shl 16 | Int(c[1]*_alpha) Shl 8 | Int(c[0]*_alpha)
	End Method
	
	Method SetAlpha( a:Float )
		_color[3]=a
		_alpha=a*255
		_pmcolor=Int(_alpha) Shl 24 | Int(_color[2]*_alpha) Shl 16 | Int(_color[1]*_alpha) Shl 8 | Int(_color[0]*_alpha)
	End Method
	
	Method Color:Float[]()
		Return [_color[0],_color[1],_color[2],_color[3]]
	End Method
	
	Method GetColor( color:Float[] )
		color[0]=_color[0]
		color[1]=_color[1]
		color[2]=_color[2]
		If color.Length>3 color[3]=_color[3]
	End Method
	
	Method Alpha:Float()
		Return _color[3]
	End Method
	
	Rem
	bbdoc: Sets the current 2d matrix to the identity matrix.
	about: Same as SetMatrix( 1,0,0,1,0,0 ).
	end rem
	Method ResetMatrix()
		_ix=1;_iy=0
		_jx=0;_jy=1
		_tx=0;_ty=0
	End Method
	
	Rem
	bbdoc: Sets the current 2d matrix to the given matrix.
	end rem
	Method SetMatrix( ix:Float,iy:Float,jx:Float,jy:Float,tx:Float,ty:Float )
		_ix=ix;_iy=iy
		_jx=jx;_jy=jy
		_tx=tx;_ty=ty
	End Method
	
	Rem
	bbdoc: Gets the current 2d matrix.
	end rem
	Method GetMatrix( matrix:Float[] )
		matrix[0]=_ix
		matrix[1]=_iy
		matrix[2]=_jx
		matrix[3]=_jy
		matrix[4]=_tx
		matrix[5]=_ty
	End Method
	
	Rem
	bbdoc: Multiplies the current 2d matrix by the given matrix.
	end rem
	Method Transform( ix:Float,iy:Float,jx:Float,jy:Float,tx:Float,ty:Float )
		Local ix2:Float=ix*_ix+iy*_jx
		Local iy2:Float=ix*_iy+iy*_jy
		Local jx2:Float=jx*_ix+jy*_jx
		Local jy2:Float=jx*_iy+jy*_jy
		Local tx2:Float=tx*_ix+ty*_jx+_tx
		Local ty2:Float=tx*_iy+ty*_jy+_ty
		SetMatrix ix2,iy2,jx2,jy2,tx2,ty2
	End Method

	Rem
	bbdoc: Translates the current 2d matrix.
	end rem
	Method Translate( tx:Float,ty:Float )
		Transform 1,0,0,1,tx,ty
	End Method
	
	Rem
	bbdoc: Rotates the current 2d matrix.
	end rem
	Method Rotate( rz:Float )
		Transform Float(Cos( rz )),Float(-Sin( rz )),Float(Sin( rz )),Float(Cos( rz )),0,0
	End Method
	
	Rem
	bbdoc: Scales the current 2d matrix.
	end rem
	Method Scale( sx:Float,sy:Float )
		Transform sx,0,0,sy,0,0
	End Method
	
	Rem
	bbdoc: Translates and rotates (in that order) the current 2d matrix.
	end rem
	Method TranslateRotate( tx:Float,ty:Float,rz:Float )
		Translate tx,ty
		Rotate rz
	End Method
	
	Rem
	bbdoc: Rotates and scales (in that order) the current 2d matrix.
	end rem
	Method RotateScale( rz:Float,sx:Float,sy:Float )
		Rotate rz
		Scale sx,sy
	End Method
	
	Method TranslateScale( tx:Float,ty:Float,sx:Float,sy:Float )
		Translate tx,ty
		Scale sx,sy
	End Method
	
	Rem
	bbdoc: Translates, rotates and scales (in that order) the current 2d matrix.
	end rem
	Method TranslateRotateScale( tx:Float,ty:Float,rz:Float,sx:Float,sy:Float )
		Translate tx,ty
		Rotate rz
		Scale sx,sy
	End Method
	
	Rem
	bbdoc: Sets the maximum number of 2d matrices that can be pushed onto the matrix stack using @PushMatrix.
	end rem
	Method SetMatrixStackCapacity( capacity:Int )
		'_matStack=_matStack.Resize( capacity*6 )
		_matStack = _matStack[..capacity*6]
		_matSp=0
	End Method
	
	Rem
	bbdoc: Gets the maximum number of 2d matrices that can be pushed onto the matrix stack using @PushMatrix.
	end rem
	Method MatrixStackCapacity:Int()
		Return _matStack.Length/6
	End Method
	
	Rem
	bbdoc: Pushes the current 2d matrix on the 2d matrix stack.
	end rem
	Method PushMatrix()
		_matStack[_matSp+0]=_ix;_matStack[_matSp+1]=_iy
		_matStack[_matSp+2]=_jx;_matStack[_matSp+3]=_jy
		_matStack[_matSp+4]=_tx;_matStack[_matSp+5]=_ty
		_matSp:+6
		If _matSp>=_matStack.Length _matSp:-_matStack.Length
	End Method
	
	Rem
	bbdoc: Pops the current 2d matrix from the 2d matrix stack.
	end rem
	Method PopMatrix()
		_matSp:-6
		If _matSp<0 _matSp:+_matStack.Length
		_ix=_matStack[_matSp+0]
		_iy=_matStack[_matSp+1]
		_jx=_matStack[_matSp+2]
		_jy=_matStack[_matSp+3]
		_tx=_matStack[_matSp+4]
		_ty=_matStack[_matSp+5]
	End Method
	
	Rem
	bbdoc: Sets current font for use with #DrawText.
	about: 	If @font is null, a default font is used.
	end rem
	Method SetFont( font:TFont )
		If Not font font=defaultFont
		_font=font
	End Method
	
	Rem
	bbdoc: Gets the current font.
	end rem
	Method Font:TFont()
		Return _font
	End Method
	
	Rem
	bbdoc: Sets the default material used for drawing operations that use a null material.
	end rem
	Method SetDefaultMaterial( material:TMaterial )
		_defaultMaterial=material
	End Method
	
	Rem
	bbdoc: Returns the current default material.
	end rem
	Method DefaultMaterial:TMaterial()
		Return _defaultMaterial
	End Method
	
	Rem
	bbdoc: Draws a point at @x0,@y0.
	about: If @material is null, the current default material is used.
	end rem
	Method DrawPoint( x0:Float,y0:Float,material:TMaterial=Null,s0:Float=0,t0:Float=0 )
		BeginPrim material,1
		PrimVert x0+.5,y0+.5,s0,t0
	End Method
	
	Rem
	bbdoc: Draws a line from @x0,@y0 to @x1,@y1.
	about: If @material is null, the current default material is used.
	end rem
	Method DrawLine( x0:Float,y0:Float,x1:Float,y1:Float,material:TMaterial=Null,s0:Float=0,t0:Float=0,s1:Float=1,t1:Float=0 )
		BeginPrim material,2
		PrimVert x0+.5,y0+.5,s0,t0
		PrimVert x1+.5,y1+.5,s1,t1
	End Method
	
	Rem
	bbdoc: Draw a triangle.
	about: If @material is null, the current default material is used.
	End Rem
	Method DrawTriangle( x0:Float,y0:Float,x1:Float,y1:Float,x2:Float,y2:Float,material:TMaterial=Null,s0:Float=.5,t0:Float=0,s1:Float=1,t1:Float=1,s2:Float=0,t2:Float=1 )
		BeginPrim material,3
		PrimVert x0,y0,s0,t0
		PrimVert x1,y1,s1,t1
		PrimVert x2,y2,s2,t2
	End Method
	
	Rem
	bbdoc: Draw a quad.
	about: If @material is null, the current default material is used.
	end rem
	Method DrawQuad( x0:Float,y0:Float,x1:Float,y1:Float,x2:Float,y2:Float,x3:Float,y3:Float,material:TMaterial=Null,s0:Float=.5,t0:Float=0,s1:Float=1,t1:Float=1,s2:Float=0,t2:Float=1 )
		BeginPrim material,4
		PrimVert x0,y0,s0,t0
		PrimVert x1,y1,s1,t1
		PrimVert x2,y2,s2,t2
		PrimVert x3,y3,s2,t2
	End Method
	
	Rem
	bbdoc: Draw an oval in the given rectangle.
	about: If @material is null, the current default material is used.
	end rem
	Method DrawOval( x:Float,y:Float,width:Float,height:Float,material:TMaterial=Null )
		Local xr:Float=width/2.0
		Local yr:Float=height/2.0
		
		Local dx_x:Float=xr*_ix
		Local dx_y:Float=xr*_iy
		Local dy_x:Float=yr*_jx
		Local dy_y:Float=yr*_jy
		Local dx:Float=Sqr( dx_x*dx_x+dx_y*dx_y )
		Local dy:Float=Sqr( dy_x*dy_x+dy_y*dy_y )

		Local n:Int=Int( dx+dy )
		If n<12 
			n=12 
		Else If n>MAX_VERTICES
			n=MAX_VERTICES
		Else
			n:&~3
		EndIf
		
		Local x0:Float=x+xr
		Local y0:Float=y+yr
		
		BeginPrim material,n
		
		For Local i:Int=0 Until n
			Local th:Float=i*360.0/n
			Local px:Float=x0+Cos( th ) * xr
			Local py:Float=y0+Sin( th ) * yr
			PrimVert px,py,0,0
		Next
	End Method
	
	Rem
	bbdoc: Draw an ellipse at @x, @y with radii @xRadius, @yRadius.
	about: If @material is null, the current default material is used.
	end rem
	Method DrawEllipse( x:Float,y:Float,xr:Float,yr:Float,material:TMaterial=Null )
		DrawOval x-xr,y-yr,xr*2,yr*2,material
	End Method
	
	Rem
	bbdoc: Draw a circle at @x, @y with radius @radius.
	about: If @material is null, the current default material is used.
	end rem
	Method DrawCircle( x:Float,y:Float,r:Float,material:TMaterial=Null )
		DrawOval x-r,y-r,r*2,r*2,material
	End Method
	
	Method DrawPoly( vertices:Float[],material:TMaterial=Null )
	
		Local n:Int=vertices.Length/2
		If n<3 Or n>MAX_VERTICES Return
	
		BeginPrim material,n

		For Local i:Int=0 Until n
			PrimVert vertices[i*2],vertices[i*2+1],0,0
		Next
	End Method
	
	Rem
	bbdoc: Draw a batch of primtives.
	about:
	@order is the number of vertices for each primitive, eg: 1 for points, 2 for lines, 3 for triangles etc.
	@count is the number of primitives to draw.
	The @vertices array contains x,y vertex data, and must be at least @count \* @order \* 2 long.
	If @material is null, the current default material is used.
	end rem
	Method DrawPrimitives( order:Int,count:Int,vertices:Float[],material:TMaterial=Null )
	
		BeginPrims material,order,count
		Local p:Int=0
		For Local i:Int=0 Until count
			For Local j:Int=0 Until order
				PrimVert vertices[p],vertices[p+1],0,0
				p:+2
			Next
		Next
	End Method
	
	Rem
	bbdoc: Draw a batch of primtives.
	about: 
	@order is the number of vertices for each primitive, eg: 1 for points, 2 for lines, 3 for triangles etc.
	@count is the number of primitives to draw.
	The @vertices array contains x,y vertex data, and must be at least @count \* @order \* 2 long.
	The @texcoords array contains s,t texture coordinate data, and must be at least @count \* @order \* 2 long.
	If @material is null, the current default material is used.
	end rem
	Method DrawPrimitivesCoords( order:Int,count:Int,vertices:Float[],texcoords:Float[],material:TMaterial=Null )
	
		BeginPrims material,order,count
		Local p:Int=0
		For Local i:Int=0 Until count
			For Local j:Int=0 Until order
				PrimVert vertices[p],vertices[p+1],texcoords[p],texcoords[p+1]
				p:+2
			Next
		Next
	End Method
	
	Rem
	bbdoc: Draw a batch of indexed primtives.
	about:
	@order is the number of vertices for each primitive, eg: 1 for points, 2 for lines, 3 for triangles etc.
	@count is the number of primitives to draw.
	The @vertices array contains x,y vertex data.
	The @indices array contains vertex indices, and must be at least @count \* @order long.
	If @material is null, the current default material is used.
	end rem
	Method DrawIndexedPrimitives( order:Int,count:Int,vertices:Float[],indices:Int[],material:TMaterial=Null )
	
		BeginPrims material,order,count
		Local p:Int=0
		For Local i:Int=0 Until count
			For Local j:Int=0 Until order
				Local k:Int=indices[p+j]*2
				PrimVert vertices[k],vertices[k+1],0,0
			Next
			p:+order
		Next
	
	End Method
	
	Method DrawIndexedPrimitivesCoords( order:Int,count:Int,vertices:Float[],texcoords:Float[],indices:Int[],material:TMaterial=Null )
	
		BeginPrims material,order,count
		Local p:Int=0
		For Local i:Int=0 Until count
			For Local j:Int=0 Until order
				Local k:Int=indices[p+j]*2
				PrimVert vertices[k],vertices[k+1],texcoords[k],texcoords[k+1]
			Next
			p:+order
		Next
	
	End Method
	
	Rem
	bbdoc: Draws a rect from @x,@y to @x+@width,@y+@height.
	about: If @material is null, the current default material is used.
	end rem
	Method DrawRect( x0:Float,y0:Float,width:Float,height:Float,material:TMaterial=Null,s0:Float=0,t0:Float=0,s1:Float=1,t1:Float=1 )
		Local x1:Float=x0+width
		Local y1:Float=y0+height
		BeginPrim material,4
		PrimVert x0,y0,s0,t0
		PrimVert x1,y0,s1,t0
		PrimVert x1,y1,s1,t1
		PrimVert x0,y1,s0,t1
	End Method
	
	Rem
	bbdoc: Draws a rect from @x,@y to @x+@width,@y+@height filled with @image.
	about: The image's handle is ignored.
	end rem
	Method DrawRectImage( x0:Float,y0:Float,width:Float,height:Float,image:TImage )
		DrawRect x0,y0,width,height,image._material,image._s0,image._t0,image._s1,image._t1
	End Method
	
	Rem
	bbdoc: Draws a rect at @x,@y filled with the given subrect of @image.
	about: The image's handle is ignored.
	end rem
	Method DrawRectImageSource( x:Float,y:Float,image:TImage,sourceX:Int,sourceY:Int,sourceWidth:Int,sourceHeight:Int )
		DrawRectImageSourceSize( x,y,sourceWidth,sourceHeight,image,sourceX,sourceY,sourceWidth,sourceHeight )
	End Method

	Rem
	bbdoc: Draws a rect from @x,@y to @x+@width,@y+@height filled with the given subrect of @image.
	about: The image's handle is ignored.
	end rem
	Method DrawRectImageSourceSize( x0:Float,y0:Float,width:Float,height:Float,image:TImage,sourceX:Int,sourceY:Int,sourceWidth:Int,sourceHeight:Int )
		Local material:TMaterial=image._material
		Local s0:Float=Float(image._x+sourceX)/Float(material.Width())
		Local t0:Float=Float(image._y+sourceY)/Float(material.Height())
		Local s1:Float=Float(image._x+sourceX+sourceWidth)/Float(material.Width())
		Local t1:Float=Float(image._y+sourceY+sourceHeight)/Float(material.Height())
		DrawRect x0,y0,width,height,material,s0,t0,s1,t1
	End Method
	
	'gradient rect - kinda hacky, but doesn't slow anything else down
	Method DrawGradientRect( x0:Float,y0:Float,width:Float,height:Float,r0:Float,g0:Float,b0:Float,a0:Float,r1:Float,g1:Float,b1:Float,a1:Float,axis:Int )
	
		r0:*_color[0];g0:*_color[1];b0:*_color[2];a0:*_alpha
		r1:*_color[0];g1:*_color[1];b1:*_color[2];a1:*_alpha
		
		Local pm0:Int=Int( a0 ) Shl 24 | Int( b0*a0 ) Shl 16 | Int( g0*a0 ) Shl 8 | Int( r0*a0 )
		Local pm1:Int=Int( a1 ) Shl 24 | Int( b1*a0 ) Shl 16 | Int( g1*a0 ) Shl 8 | Int( r1*a0 )
		
		Local x1:Float=x0+width
		Local y1:Float=y0+height
		Local s0:Float=0.0
		Local t0:Float=0.0
		Local s1:Float=1.0
		Local t1:Float=1.0
		
		BeginPrim Null,4

		Local pmcolor:Int=_pmcolor
		
		BeginPrim Null,4
		
		Select axis
		Case 0	'left->right
			_pmcolor=pm0
			PrimVert x0,y0,s0,t0
			_pmcolor=pm1
			PrimVert x1,y0,s1,t0
			PrimVert x1,y1,s1,t1
			_pmcolor=pm0
			PrimVert x0,y1,s0,t1
		Default	'top->bottom
			_pmcolor=pm0
			PrimVert x0,y0,s0,t0
			PrimVert x1,y0,s1,t0
			_pmcolor=pm1
			PrimVert x1,y1,s1,t1
			PrimVert x0,y1,s0,t1
		End Select
		
		_pmcolor=pmcolor
	End Method
	
	Method DrawImageImage( image:TImage )
		BeginPrim image._material,4
		PrimVert image._x0,image._y0,image._s0,image._t0
		PrimVert image._x1,image._y0,image._s1,image._t0
		PrimVert image._x1,image._y1,image._s1,image._t1
		PrimVert image._x0,image._y1,image._s0,image._t1
		If image._caster AddShadowCaster image._caster
	End Method
	
	Method DrawImage( image:TImage,tx:Float,ty:Float )
		PushMatrix
		Translate tx,ty
		DrawImageImage image
		PopMatrix
	End Method

	Method DrawImageXYZ( image:TImage,tx:Float,ty:Float,rz:Float )
		PushMatrix
		TranslateRotate tx,ty,rz
		DrawImageImage image
		PopMatrix
	End Method
	
	Method DrawImageXYZS( image:TImage,tx:Float,ty:Float,rz:Float,sx:Float,sy:Float )
		PushMatrix
		TranslateRotateScale tx,ty,rz,sx,sy
		DrawImageImage image
		PopMatrix
	End Method
	
	Rem
	bbdoc: Draws @text at @x,@y in the current font.
	end rem
	Method DrawText( Text:String,x:Float,y:Float,xhandle:Float=0,yhandle:Float=0 )
		x:-_font.TextWidth( Text )*xhandle
		y:-_font.TextHeight( Text )*yhandle
?bmxng
		For Local char:Int=EachIn Text
?Not bmxng
		For Local i:Int=0 Until Text.length
			Local char:Int = Text[i]
?
			Local glyph:TGlyph=_font.GetGlyph( char )
			If Not glyph Continue
			DrawRectImageSource x,y,glyph.image,glyph.x,glyph.y,glyph.width,glyph.height
			x:+glyph.advance
		Next
	End Method
	
	Rem
	bbdoc: Draws a shadow volume.
	end rem
	Method DrawShadow:Int( lx:Float,ly:Float,x0:Float,y0:Float,x1:Float,y1:Float )
	
		Local ext:Int=1024
	
		Local dx:Float=x1-x0
		Local dy:Float=y1-y0
		Local d0:Float=Sqr( dx*dx+dy*dy )
		Local nx:Float=-dy/d0
		Local ny:Float=dx/d0
		Local pd:Float=-(x0*nx+y0*ny)
		
		Local d:Float=lx*nx+ly*ny+pd
		If d<0 Return False

		Local x2:Float=x1-lx
		Local y2:Float=y1-ly
		'Local d2:Float=ext/Sqr( x2*x2+y2*y2 )
		x2=lx+x2*ext;y2=ly+y2*ext
		
		Local x3:Float=x0-lx
		Local y3:Float=y0-ly
		'Local d3:Float=ext/Sqr( x3*x3+y3*y3 )
		x3=lx+x3*ext;y3=ly+y3*ext
		
		Local x4:Float=(x2+x3)/2-lx
		Local y4:Float=(y2+y3)/2-ly
		'Local d4:Float=ext/Sqr( x4*x4+y4*y4 )
		x4=lx+x4*ext;y4=ly+y4*ext
		
		DrawTriangle x0,y0,x4,y4,x3,y3
		DrawTriangle x0,y0,x1,y1,x4,y4
		DrawTriangle x1,y1,x2,y2,x4,y4
		
		Return True
	End Method
	
	Rem
	bbdoc: Draws multiple shadow volumes.
	end rem
	Method DrawShadows( x0:Float,y0:Float,drawList:TDrawList )
	
		Local lx:Float= x0 * _ix + y0 * _jx + _tx
		Local ly:Float= x0 * _iy + y0 * _jy + _ty

		Local verts:Float[]=drawList._casterVerts.Data
		Local v0:Int=0
		
		For Local i:Int=0 Until drawList._casters.Length
		
			Local caster:TShadowCaster=drawList._casters.Get( i )
			Local n:Int=caster._verts.Length
			
			Select caster._kind
			Case 0	'closed loop
				Local x0:Float=verts[v0+n-2]
				Local y0:Float=verts[v0+n-1]
				For Local i:Int=0 Until n-1 Step 2
					Local x1:Float=verts[v0+i]
					Local y1:Float=verts[v0+i+1]
					DrawShadow( lx,ly,x0,y0,x1,y1 )
					x0=x1
					y0=y1
				Next
			Case 1	'open loop
			Case 2	'edge soup
			End Select
			
			v0:+n
		Next
		
	End Method
	
	Rem
	bbdoc: Adds a shadow caster to the drawlist.
	end rem
	Method AddShadowCaster( caster:TShadowCaster )
		_casters.Push caster
		Local verts:Float[]=caster._verts
		For Local i:Int=0 Until verts.Length-1 Step 2
			Local x0:Float=verts[i]
			Local y0:Float=verts[i+1]
			_casterVerts.Push x0*_ix+y0*_jx+_tx
			_casterVerts.Push x0*_iy+y0*_jy+_ty
		Next
	End Method
	
	Rem
	bbdoc: Adds a shadow caster to the drawlist at @tx,@ty.
	end rem
	Method AddShadowCasterXY( caster:TShadowCaster,tx:Float,ty:Float )
		PushMatrix
		Translate tx,ty
		AddShadowCaster caster
		PopMatrix
	End Method
	
	Method AddShadowCasterXYZ( caster:TShadowCaster,tx:Float,ty:Float,rz:Float )
		PushMatrix
		TranslateRotate tx,ty,rz
		AddShadowCaster caster
		PopMatrix
	End Method
	
	Method AddShadowCasterXYZS( caster:TShadowCaster,tx:Float,ty:Float,rz:Float,sx:Float,sy:Float )
		PushMatrix
		TranslateRotateScale tx,ty,rz,sx,sy
		AddShadowCaster caster
		PopMatrix
	End Method
	
	Method IsEmpty:Int()
		Return _next=0
	End Method
	
	Method Compact()
		If _data.Size()=_next Return
		Local data:TBank=New TBank.Create( _next )
		'_data.CopyBytes 0,data,0,_next
		'_data.Discard
?bmxng
		MemCopy(data._buf,_data._buf,Size_T(_next))
?Not bmxng
		MemCopy(data._buf,_data._buf,_next)
?
		_data=data
	End Method
	
	Method RenderOp( op:TDrawOp,index:Int,count:Int )
	
		If Not op.material.Bind() Return
		
		If op.blend<>rs_blend
			rs_blend=op.blend
			Select rs_blend
			Case TBlendMode.Opaque
				glDisable GL_BLEND
			Case TBlendMode.Alpha
				glEnable GL_BLEND
				glBlendFunc GL_ONE,GL_ONE_MINUS_SRC_ALPHA
			Case TBlendMode.Additive
				glEnable GL_BLEND
				glBlendFunc GL_ONE,GL_ONE
			Case TBlendMode.Multiply
				glEnable GL_BLEND
				glBlendFunc GL_DST_COLOR,GL_ONE_MINUS_SRC_ALPHA
			Case TBlendMode.Multiply2
				glEnable GL_BLEND
				glBlendFunc GL_DST_COLOR,GL_ZERO
			End Select
		End If
		
		Select op.order
		Case 1
			glDrawArrays GL_POINTS,index,count
		Case 2
			glDrawArrays GL_LINES,index,count
		Case 3
			glDrawArrays GL_TRIANGLES,index,count
		Case 4
			glDrawElements GL_TRIANGLES,count/4*6,GL_UNSIGNED_SHORT,Byte Ptr((index/4*6 + (index&3)*MAX_QUAD_INDICES)*2)
		Default
			Local j:Int=0
			While j<count
				glDrawArrays GL_TRIANGLE_FAN,index+j,op.order
				j:+op.order
			Wend
		End Select

	End Method
	
	Method Render()
		If Not _next Return
		
		Local offset:Int=0
		Local opid:Int=0
		Local ops:Object[]=_ops.Data
		Local length:Int=_ops.length
				
		While offset<_next
		
			Local size:Int=_next-offset
			Local lastop:Int=length
			
			If size>PRIM_VBO_SIZE
			
				size=0
				lastop=opid
				While lastop<length
					Local op:TDrawOp=TDrawOp(ops[lastop])
					Local n:Int=op.count*BYTES_PER_VERTEX
					If size+n>PRIM_VBO_SIZE Exit
					size:+n
					lastop:+1
				Wend
				
				If Not size
					Local op:TDrawOp=TDrawOp(ops[opid])
					Local count:Int=op.count
					While count
						Local n:Int=count
						If n>MAX_VERTICES n=MAX_VERTICES/op.order*op.order
						Local size:Int=n*BYTES_PER_VERTEX
						
						If VBO_ORPHANING_ENABLED glBufferData GL_ARRAY_BUFFER,PRIM_VBO_SIZE,Null,VBO_USAGE
						glBufferSubData GL_ARRAY_BUFFER,0,size,_data._buf + offset
						
						RenderOp op,0,n
						
						offset:+size
						count:-n
					Wend
					opid:+1
					Continue
				EndIf
				
			EndIf
			
			If VBO_ORPHANING_ENABLED glBufferData GL_ARRAY_BUFFER,PRIM_VBO_SIZE,Null,VBO_USAGE
			glBufferSubData GL_ARRAY_BUFFER,0,size,_data._buf + offset
			
			Local index:Int=0
			While opid<lastop
				Local op:TDrawOp=TDrawOp(ops[opid])
				RenderOp op,index,op.count
				index:+op.count
				opid:+1
			Wend
			offset:+size
			
		Wend
		
		glGetError
		
	End Method
	
	Method Reset()
		_next=0
		
		Local data:TDrawOp[]=_ops.Data
		For Local i:Int=0 Until _ops.Length
			data[i].material=Null
			freeOps.Push data[i]
		Next
		_ops.Clear()
		_op=nullOp
		
		_casters.Clear
		_casterVerts.Clear
	End Method
	
	Method Flush()
		Render
		Reset
	End Method
	
'	Protected

	Field _blend:Float=1
	Field _alpha:Float=255.0
	Field _color:Float Ptr
	Field __colorArray:Float[]=[1.0,1.0,1.0,1.0]
	Field _pmcolor:Int=$ffffffff
	Field _ix:Float=1,_iy:Float
	Field _jx:Float,_jy:Float=1
	Field _tx:Float,_ty:Float
	Field _matStack:Float[64*6]
	Field _matSp:Int
	Field _font:TFont
	Field _defaultMaterial:TMaterial
	
'	Private
	
	Field _data:TBank=New TBank.Create( 4096 )
	Field _next:Int=0
	
	Field _op:TDrawOp=nullOp
	Field _ops:TDrawOpStack=New TDrawOpStack'<DrawOp>
	Field _casters:TShadowCasterStack=New TShadowCasterStack'<ShadowCaster>
	Field _casterVerts:TFloatStack=New TFloatStack

	Method BeginPrim( material:TMaterial,order:Int ) Final
	
		If Not material material=_defaultMaterial
		
		If _next+order*BYTES_PER_VERTEX>_data.Size()
			Local newsize:Int=Max( _data.Size()+_data.Size()/2,_next+order*BYTES_PER_VERTEX )
			Local data:TBank=New TBank.Create( newsize )
?bmxng
			MemCopy(data._buf, _data._buf, Size_T(_next))
?Not bmxng
			MemCopy(data._buf, _data._buf, _next)
?
			'_data.CopyBytes 0,data,0,_next
			'_data.Discard
			_data=data
		EndIf
	
		If material=_op.material And _blend=_op.blend And order=_op.order
			_op.count:+order
			Return
		EndIf
		
		If freeOps.Length _op=freeOps.Pop() Else _op=New TDrawOp
		
		_ops.Push _op
		_op.material=material
		_op.blend=_blend
		_op.order=order
		_op.count=order
	End Method
	
	Method BeginPrims( material:TMaterial,order:Int,count:Int ) Final
	
		If Not material material=_defaultMaterial
		
		count:*order
		
		If _next+count*BYTES_PER_VERTEX>_data.Size()
			Local newsize:Int=Max( _data.Size()+_data.Size()/2,_next+count*BYTES_PER_VERTEX )
			Local data:TBank=New TBank.Create( newsize )
?bmxng
			MemCopy data._buf, _data._buf, Size_T(_next)
?Not bmxng
			MemCopy data._buf, _data._buf, _next
?
			_data=data
		EndIf
	
		If material=_op.material And _blend=_op.blend And order=_op.order
			_op.count:+count
			Return
		EndIf
		
		If freeOps.Length _op=freeOps.Pop() Else _op=New TDrawOp
		
		_ops.Push _op
		_op.material=material
		_op.blend=_blend
		_op.order=order
		_op.count=count
	End Method
	
	Method PrimVert( x0:Float,y0:Float,s0:Float,t0:Float ) Final
		Local df:Float Ptr = Float Ptr(_data._buf + _next)
		Local di:Int Ptr = Int Ptr(_data._buf + _next)
		df[0] = x0 * _ix + y0 * _jx + _tx
		df[1] = x0 * _iy + y0 * _jy + _ty
		df[2] = s0
		df[3] = t0
		df[4] = _ix
		df[5] = _iy
		di[6] = _pmcolor
		_next:+BYTES_PER_VERTEX
	End Method
	
End Type


'***** Canvas *****

Type TCanvas Extends TDrawList

	Const MaxLights:Int=MAX_LIGHTS

	Method CreateCanvas:TCanvas( target:Object=Null )
'		Super.Create()
		Init
		SetRenderTarget target
		SetViewport 0,0,_width,_height
		SetProjection2d 0,_width,0,_height
		Return Self
	End Method
	
	Method Discard()
	End Method

	Method SetRenderTarget( target:Object )

		FlushPrims
		
		If Not target
		
			_image=Null
			_texture=Null
			_width=GraphicsWidth()
			_height=GraphicsHeight()
			_twidth=_width
			_theight=_height
		
		Else If TImage( target )
		
			_image=TImage( target )
			_texture=_image.Material().ColorTexture()
			If Not (_texture.Flags() & TTexture.RenderTarget) Throw "Texture is not a render target texture"
			_width=_image.Width()
			_height=_image.Height()
			_twidth=_texture.Width()
			_theight=_texture.Height()
			
		Else If TTexture( target )
		
			_image=Null
			_texture=TTexture( target )

			If Not (_texture.Flags() & TTexture.RenderTarget) Throw "Texture is not a render target texture"
			_width=_texture.Width()
			_height=_texture.Height()
			_twidth=_texture.Width()
			_theight=_texture.Height()
			
		Else
		
			Throw "RenderTarget object must a TImage, a TTexture or Null"
			
		EndIf
		
		_dirty=-1
		
	End Method

	Method RenderTarget:Object()
		If _image Return _image Else Return _texture
	End Method
	
	Method Width:Int()
		Return _width
	End Method
	
	Method Height:Int()
		Return _height
	End Method
	
	Method SetColorMask( r:Int,g:Int,b:Int,a:Int )
		FlushPrims
		_colorMask[0]=r
		_colorMask[1]=g
		_colorMask[2]=b
		_colorMask[3]=a
		_dirty:|DIRTY_COLORMASK
	End Method
	
	Method ColorMask:Int[]()
		Return _colorMask
	End Method
	
	Method SetViewport( x:Int,y:Int,w:Int,h:Int )
		FlushPrims
		_viewport[0]=x
		_viewport[1]=y
		_viewport[2]=w
		_viewport[3]=h
		_dirty:|DIRTY_VIEWPORT
	End Method
	
	Method Viewport:Int[]()
		Return _viewport
	End Method
	
	Method SetScissor( x:Int,y:Int,w:Int,h:Int )
		FlushPrims
		_scissor[0]=x
		_scissor[1]=y
		_scissor[2]=w
		_scissor[3]=h
		_dirty:|DIRTY_VIEWPORT
	End Method
	
	Method Scissor:Int[]()
		Return _scissor
	End Method
	
	Method SetProjectionMatrix( projMatrix:Float[] )
		FlushPrims
		If projMatrix
			Mat4Copy projMatrix,_projMatrix
		Else
			Mat4InitArray _projMatrix
		EndIf
		_dirty:|DIRTY_SHADER
	End Method
	
	Method SetProjection2d( Left:Float,Right:Float,top:Float,bottom:Float,znear:Float=-1,zfar:Float=1 )
		FlushPrims
		Mat4Ortho Left,Right,top,bottom,znear,zfar,_projMatrix
		_dirty:|DIRTY_SHADER
	End Method
	
	Method ProjectionMatrix:Float[]()
		Return _projMatrix
	End Method
	
	Method SetViewMatrix( viewMatrix:Float[] )
		FlushPrims
		If viewMatrix
			Mat4Copy viewMatrix,_viewMatrix
		Else
			Mat4InitArray _viewMatrix
		End If
		_dirty:|DIRTY_SHADER
	End Method
	
	Method ViewMatrix:Float[]()
		Return _viewMatrix
	End Method
	
	Method SetModelMatrix( modelMatrix:Float[] )
		FlushPrims
		If modelMatrix
			Mat4Copy modelMatrix,_modelMatrix
		Else
			Mat4InitArray _modelMatrix
		EndIf
		_dirty:|DIRTY_SHADER
	End Method
	
	Method ModelMatrix:Float[]()
		Return _modelMatrix
	End Method

	Method SetAmbientLight( r:Float,g:Float,b:Float,a:Float=1 )
		FlushPrims
		_ambientLight[0]=r
		_ambientLight[1]=g
		_ambientLight[2]=b
		_ambientLight[3]=a
		_dirty:|DIRTY_SHADER
	End Method
	
	Method AmbientLight:Float[]()
		Return _ambientLight
	End Method
	
	Method SetFogColor( r:Float,g:Float,b:Float,a:Float )
		FlushPrims
		_fogColor[0]=r
		_fogColor[1]=g
		_fogColor[2]=b
		_fogColor[3]=a
		_dirty:|DIRTY_SHADER
	End Method
	
	Method FogColor:Float[]()
		Return _fogColor
	End Method
	
	Method SetLightType( index:Int,kind:Int )
		FlushPrims
		Local light:TLightData=_lights[index]
		light.kind=kind
		_dirty:|DIRTY_SHADER
	End Method
	
	Method GetLightType:Int( index:Int )
		Return _lights[index].kind
	End Method
	
	Method SetLightColor( index:Int,r:Float,g:Float,b:Float,a:Float=1 )
		FlushPrims
		Local light:TLightData=_lights[index]
		light.color[0]=r
		light.color[1]=g
		light.color[2]=b
		light.color[3]=a
		_dirty:|DIRTY_SHADER
	End Method
	
	Method GetLightColor:Float[]( index:Int )
		Return _lights[index].color
	End Method
	
	Method SetLightPosition( index:Int,x:Float,y:Float,z:Float )
		FlushPrims
		Local light:TLightData=_lights[index]
		light.position[0]=x
		light.position[1]=y
		light.position[2]=z
		light.vector[0]=x
		light.vector[1]=y
		light.vector[2]=z
		_dirty:|DIRTY_SHADER
	End Method
	
	Method GetLightPosition:Float[]( index:Int )
		Return _lights[index].position
	End Method
	
	Method SetLightRange( index:Int,Range:Float )
		FlushPrims
		Local light:TLightData=_lights[index]
		light.Range=Range
		_dirty:|DIRTY_SHADER
	End Method
	
	Method GetLightRange:Float( index:Int )
		Return _lights[index].Range
	End Method
	
	Method SetShadowMap( image:TImage )
		FlushPrims
		_shadowMap=image
		_dirty:|DIRTY_SHADER
	End Method
	
	Method ShadowMap:TImage()
		Return _shadowMap
	End Method
	
	Method SetLineWidth( lineWidth:Float )
		FlushPrims
		_lineWidth=lineWidth
		_dirty:|DIRTY_LINEWIDTH
	End Method
	
	Method LineWidth:Float()
		Return _lineWidth
	End Method
	
	Method Clear( r:Float=0,g:Float=0,b:Float=0,a:Float=1 )
		FlushPrims
		Validate
		If _clsScissor
			glEnable GL_SCISSOR_TEST
			glScissor _vpx,_vpy,_vpw,_vph
		EndIf
		glClearColor r,g,b,a
		glClear GL_COLOR_BUFFER_BIT
		If _clsScissor glDisable GL_SCISSOR_TEST
	End Method
	
	Method ReadPixels( x:Int,y:Int,width:Int,height:Int,data:TBank,dataOffset:Int=0,dataPitch:Int=0 )
	
		FlushPrims
		
		If Not dataPitch Or dataPitch=width*4
			glReadPixels x,y,width,height,GL_RGBA,GL_UNSIGNED_BYTE,data._buf + dataOffset
		Else
			For Local iy:Int=0 Until height
				glReadPixels x,y+iy,width,1,GL_RGBA,GL_UNSIGNED_BYTE,data._buf + dataOffset+dataPitch*iy
			Next
		EndIf

	End Method

	Method RenderDrawList( drawbuf:TDrawList )

		Local fast:Int=_ix=1 And _iy=0 And _jx=0 And _jy=1 And _tx=0 And _ty=0 And _color[0]=1 And _color[1]=1 And _color[2]=1 And _color[3]=1
		
		If fast
			FlushPrims
			Validate
			drawbuf.Render
			Return
		EndIf
		
		tmpMat3d[0]=_ix
		tmpMat3d[1]=_iy
		tmpMat3d[4]=_jx
		tmpMat3d[5]=_jy
		tmpMat3d[12]=_tx
		tmpMat3d[13]=_ty
		tmpMat3d[10]=1
		tmpMat3d[15]=1
		
		Mat4Multiply _modelMatrix,tmpMat3d,tmpMat3d2
		
		FlushPrims
		
		Local tmp:Float[]=_modelMatrix
		_modelMatrix=tmpMat3d2
		rs_globalColor[0]=_color[0]*_color[3]
		rs_globalColor[1]=_color[1]*_color[3]
		rs_globalColor[2]=_color[2]*_color[3]
		rs_globalColor[3]=_color[3]
		_dirty:|DIRTY_SHADER
		
		Validate
		drawbuf.Render
		
		_modelMatrix=tmp
		rs_globalColor[0]=1
		rs_globalColor[1]=1
		rs_globalColor[2]=1
		rs_globalColor[3]=1
		_dirty:|DIRTY_SHADER
	End Method
	
	Method RenderDrawListXYZ( drawList:TDrawList,tx:Float,ty:Float,rz:Float=0,sx:Float=1,sy:Float=1 )
		Super.PushMatrix
		Super.TranslateRotateScale tx,ty,rz,sx,sy
		RenderDrawList( drawList )
		Super.PopMatrix
	End Method

	Method Flush()
		FlushPrims
		
		If Not _texture Return
		
		If _texture.Flags() & TTexture.Managed
			Validate

			glDisable GL_SCISSOR_TEST
			glViewport 0,0,_twidth,_theight
			
			If _width=_twidth And _height=_theight
				glReadPixels 0,0,_twidth,_theight,GL_RGBA,GL_UNSIGNED_BYTE, _texture.Data().pixels
			Else
				For Local y:Int=0 Until _height
					glReadPixels _image._x,_image._y+y,_width,1,GL_RGBA,GL_UNSIGNED_BYTE,_texture.Data().pixels + (_image._y+y) * (_twidth*4) + (_image._x*4)
				Next
			EndIf

			_dirty:|DIRTY_VIEWPORT
		EndIf

		_texture.UpdateMipmaps
	End Method
	
	Global _tformInvProj:Float[16]
	Global _tformT:Float[]=[0.0,0.0,-1.0,1.0]
	Global _tformP:Float[4]
	
	Method TransformCoords( coords_in:Float[],coords_out:Float[],Mode:Int=0 )
	
		Mat4Inverse _projMatrix,_tformInvProj

		Select Mode
		Case 0
			_tformT[0]=(coords_in[0]-_viewport[0])/_viewport[2]*2-1
			_tformT[1]=(coords_in[1]-_viewport[1])/_viewport[3]*2-1
			Mat4Transform _tformInvProj,_tformT,_tformP
			_tformP[0]:/_tformP[3]
			_tformP[1]:/_tformP[3]
			_tformP[2]:/_tformP[3]
			_tformP[3]=1
			coords_out[0]=_tformP[0]
			coords_out[1]=_tformP[1]
			If coords_out.Length>2 coords_out[2]=_tformP[2]
		Default
			Throw "Invalid TransformCoords mode"
		End Select
	End Method
	
	'Private

	Const DIRTY_RENDERTARGET:Int=1
	Const DIRTY_VIEWPORT:Int=2
	Const DIRTY_SHADER:Int=4
	Const DIRTY_LINEWIDTH:Int=8
	Const DIRTY_COLORMASK:Int=16
		
	Field _seq:Int
	Field _dirty:Int=-1
	Field _image:TImage
	Field _texture:TTexture	
	Field _width:Int
	Field _height:Int
	Field _twidth:Int
	Field _theight:Int
	Field _shadowMap:TImage
	Field _colorMask:Int[]=[True,True,True,True]
	Field _viewport:Int[]=[0,0,640,480]
	Field _scissor:Int[]=[0,0,100000,100000]
	Field _vpx:Int,_vpy:Int,_vpw:Int,_vph:Int
	Field _scx:Int,_scy:Int,_scw:Int,_sch:Int
	Field _clsScissor:Int
	Field _projMatrix:Float[]=Mat4New()
	Field _invProjMatrix:Float[]=Mat4New()
	Field _viewMatrix:Float[]=Mat4New()
	Field _modelMatrix:Float[]=Mat4New()
	Field _ambientLight:Float[]=[0.0,0.0,0.0,1.0]
	Field _fogColor:Float[]=[0.0,0.0,0.0,0.0]
	Field _lights:TLightData[4]
	Field _lineWidth:Float=1

	Global _active:TCanvas
	
	Method Init()
		For Local i:Int=0 Until 4
			_lights[i]=New TLightData
		Next
		_dirty=-1
	End Method

	Method FlushPrims()
		If Super.IsEmpty() Return
		Validate
		Super.Flush
	End Method
	
	Method Validate()
		If _seq<>graphicsSeq	
			_seq=graphicsSeq
			InitVbos
			_dirty=-1
		EndIf
	
		If _active=Self
			If Not _dirty Return
		Else
			If _active _active.Flush
			_active=Self
			_dirty=-1
		EndIf

'		_dirty=-1
		
		If _dirty & DIRTY_RENDERTARGET

			If _texture
				glBindFramebuffer GL_FRAMEBUFFER,_texture.GLFramebuffer()
			Else
				glBindFramebuffer GL_FRAMEBUFFER,defaultFbo
			EndIf
		End If
		
		If _dirty & DIRTY_VIEWPORT
		
			_vpx=_viewport[0];_vpy=_viewport[1];_vpw=_viewport[2];_vph=_viewport[3]
			If _image
				_vpx:+_image._x
				_vpy:+_image._y
			EndIf
			
			_scx=_scissor[0];_scy=_scissor[1];_scw=_scissor[2];_sch=_scissor[3]
			
			If _scx<0 _scx=0 Else If _scx>_vpw _scx=_vpw
			If _scw<0 _scw=0 Else If _scx+_scw>_vpw _scw=_vpw-_scx
			
			If _scy<0 _scy=0 Else If _scy>_vph _scy=_vph
			If _sch<0 _sch=0 Else If _scy+_sch>_vph _sch=_vph-_scy
			
			_scx:+_vpx;_scy:+_vpy
		
			If Not _texture
				_vpy=_theight-_vpy-_vph
				_scy=_theight-_scy-_sch
			EndIf
			
			glViewport _vpx,_vpy,_vpw,_vph
			
			If _scx<>_vpx Or _scy<>_vpy Or _scw<>_vpw Or _sch<>_vph
				glEnable GL_SCISSOR_TEST
				glScissor _scx,_scy,_scw,_sch
				_clsScissor=False
			Else
				glDisable GL_SCISSOR_TEST
				_clsScissor=(_scx<>0 Or _scy<>0 Or _vpw<>_twidth Or _vph<>_theight)
			EndIf
			
		EndIf
		
		If _dirty & DIRTY_SHADER
		
			rs_program=Null
			
			If _texture
				rs_clipPosScale[1]=1
				Mat4Copy _projMatrix,rs_projMatrix
			Else
				rs_clipPosScale[1]=-1
				Mat4Multiply flipYMatrix,_projMatrix,rs_projMatrix
			EndIf
			
			Mat4Multiply _viewMatrix,_modelMatrix,rs_modelViewMatrix
			Mat4Multiply rs_projMatrix,rs_modelViewMatrix,rs_modelViewProjMatrix
			Vec4Copy _ambientLight,rs_ambientLight
			Vec4Copy _fogColor,rs_fogColor
			
			rs_numLights=0
			For Local i:Int=0 Until MAX_LIGHTS

				Local light:TLightData=_lights[i]
				If Not light.kind Continue
				
				Mat4Transform _viewMatrix,light.vector,light.tvector
				
				rs_lightColors[rs_numLights*4+0]=light.color[0]
				rs_lightColors[rs_numLights*4+1]=light.color[1]
				rs_lightColors[rs_numLights*4+2]=light.color[2]
				rs_lightColors[rs_numLights*4+3]=light.color[3]
				
				rs_lightVectors[rs_numLights*4+0]=light.tvector[0]
				rs_lightVectors[rs_numLights*4+1]=light.tvector[1]
				rs_lightVectors[rs_numLights*4+2]=light.tvector[2]
				rs_lightVectors[rs_numLights*4+3]=light.Range

				rs_numLights:+1
			Next
			
			If _shadowMap
				rs_shadowTexture=_shadowMap._material._colorTexture
			Else 
				rs_shadowTexture=Null
			EndIf
			
			rs_blend=-1

		End If
		
		If _dirty & DIRTY_LINEWIDTH
			glLineWidth _lineWidth
		EndIf
		
		If _dirty & DIRTY_COLORMASK
			glColorMask Byte(_colorMask[0]),Byte(_colorMask[1]),Byte(_colorMask[2]),Byte(_colorMask[3])
		End If
		
		_dirty=0
	End Method
	
End Type

' stacks

Type TFloatStack
	Field data:Float[]
	Field length:Int

	Method Push( value:Float )
		If length=data.Length
			data=data[..length*2+10]
		EndIf
		data[length]=value
		length:+1
	End Method

	Method Pop:Float()
		length:-1
		Local v:Float=data[length]
		data[length]=Null
		Return v
	End Method

	Method Top:Float()
		Return data[length-1]
	End Method

	Method Clear()
		For Local i:Int=0 Until length
			data[i]=Null
		Next
		length=0
	End Method

End Type

Type TDrawOpStack
	Field data:TDrawOp[]
	Field length:Int

	Method Push( value:TDrawOp )
		If length=data.Length
			data=data[..length*2+10]
		EndIf
		data[length]=value
		length:+1
	End Method

	Method Pop:TDrawOp()
		length:-1
		Local v:TDrawOp=data[length]
		data[length]=Null
		Return v
	End Method

	Method Top:TDrawOp()
		Return data[length-1]
	End Method

	Method Clear()
		For Local i:Int=0 Until length
			data[i]=Null
		Next
		length=0
	End Method

End Type


Type TShadowCasterStack
	Field data:TShadowCaster[]
	Field length:Int

	Method Push( value:TShadowCaster )
		If length=data.Length
			data=data[..length*2+10]
		EndIf
		data[length]=value
		length:+1
	End Method

	Method Pop:TShadowCaster()
		length:-1
		Local v:TShadowCaster=data[length]
		data[length]=Null
		Return v
	End Method

	Method Top:TShadowCaster()
		Return data[length-1]
	End Method

	Method Get:TShadowCaster(index:Int)
		Return data[index]
	End Method
	
	Method Clear()
		For Local i:Int=0 Until length
			data[i]=Null
		Next
		length=0
	End Method

End Type

Type TDrawListStack
	Field data:TDrawList[]
	Field length:Int

	Method Push( value:TDrawList )
		If length=data.Length
			data=data[..length*2+10]
		EndIf
		data[length]=value
		length:+1
	End Method

	Method Pop:TDrawList()
		length:-1
		Local v:TDrawList=data[length]
		data[length]=Null
		Return v
	End Method

	Method Top:TDrawList()
		Return data[length-1]
	End Method
	
	Method Get:TDrawList(index:Int)
		Return data[index]
	End Method

	Method Clear()
		For Local i:Int=0 Until length
			data[i]=Null
		Next
		length=0
	End Method

End Type

?Not bmxng
Type TIntVal
	Field value:Int
	Method Compare:Int(v:Object)
		Return value - TIntVal(v).value
	End Method
End Type
?

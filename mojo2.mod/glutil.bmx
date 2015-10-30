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

Import brl.standardio
?opengles
Import Pub.OpenGLES
?Not opengles
Import Pub.Glew
Import Pub.OpenGL
?

Private

Global tmpi:Int

Public

Function glCheck()
	Local err:Int=glGetError()
	If err=GL_NO_ERROR Return
	Throw "GL ERROR! err=" + err
End Function

Function glPushTexture2d( tex:Int )
	glGetIntegerv GL_TEXTURE_BINDING_2D, Varptr tmpi
	glBindTexture GL_TEXTURE_2D,tex
End Function

Function glPopTexture2d()
	glBindTexture GL_TEXTURE_2D, tmpi
End Function

Function glPushFramebuffer( framebuf:Int )
	glGetIntegerv GL_FRAMEBUFFER_BINDING, Varptr tmpi
	glBindFramebuffer GL_FRAMEBUFFER, framebuf
End Function

Function glPopFramebuffer()
	glBindFramebuffer GL_FRAMEBUFFER, tmpi
End Function

Function glCompile:Int( kind:Int,source:String )
	
?opengles
		source="precision mediump float;~n"+source
?
	
	Local shader:Int = glCreateShader( kind )
	Local s:Byte Ptr = source.ToCString()
	glShaderSource shader,1, Varptr s, Null
	MemFree(s)
	glCompileShader shader
	glGetShaderiv shader,GL_COMPILE_STATUS, Varptr tmpi
	If Not tmpi
		Local buf:Byte[1024]
		Local l:Int
		glGetShaderInfoLog( shader, 1024, Varptr l, buf)
		Print "Failed to compile fragment shader:"+ String.FromBytes(buf, l)
		Local LINES:String[]=source.Split( "~n" )
		For Local i:Int=0 Until LINES.Length
			Print (i+1)+":~t"+LINES[i]
		Next
		Throw "Compile fragment shader failed"
	EndIf
	Return shader

End Function

Function glLink( program:Int )
	glLinkProgram program
	glGetProgramiv program,GL_LINK_STATUS, Varptr tmpi
	If Not tmpi
		Local buf:Byte[1024]
		Local l:Int
		glGetProgramInfoLog( program, 1024, Varptr l, buf)
		Throw "Failed to link program:"+ String.FromBytes(buf, l)
	End If
End Function

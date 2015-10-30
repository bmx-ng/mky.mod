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


Const TOKE_EOF:Int=0
Const TOKE_IDENT:Int=1
Const TOKE_INTLIT:Int=2
Const TOKE_FLOATLIT:Int=3
Const TOKE_STRINGLIT:Int=4
Const TOKE_SYMBOL:Int=5
	
Const CHAR_QUOTE:Int=34
Const CHAR_PLUS:Int=43
Const CHAR_MINUS:Int=45
Const CHAR_PERIOD:Int=46
Const CHAR_UNDERSCORE:Int=95
Const CHAR_APOSTROPHE:Int=39

Function IsDigit:Int( ch:Int )
	Return (ch>=48 And ch<58)
End Function

Function IsAlpha:Int( ch:Int )
	Return (ch>=65 And ch<65+26) Or (ch>=97 And ch<97+26)
End Function

Function IsIdent:Int( ch:Int )
	Return (ch>=65 And ch<65+26) Or (ch>=97 And ch<97+26) Or (ch>=48 And ch<58) Or ch=CHAR_UNDERSCORE
End Function

Type TParser

	Method Create:TParser( Text:String )
		SetText Text
		Return Self
	End Method

	Method SetText( Text:String )
		_text=Text
		_pos=0
		_len=_text.Length
		Bump
	End Method
	
	Method Bump:String()

		While _pos<_len
			Local ch:Int=_text[_pos]
			If ch<=32
				_pos:+1
				Continue
			EndIf
			If ch<>CHAR_APOSTROPHE Exit
			_pos:+1
			While _pos<_len And _text[_pos]<>10
				_pos:+1
			Wend
		Wend
		
		If _pos=_len
			_toke=""
			_tokeType=TOKE_EOF
			Return _toke
		EndIf
		
		Local pos:Int=_pos
		Local ch:Int=_text[_pos]
		_pos:+1
		
		If IsAlpha( ch ) Or ch=CHAR_UNDERSCORE
		
			While _pos<_len
				Local ch:Int=_text[_pos]
				If Not IsIdent( ch ) Exit
				_pos:+1
			Wend
			_tokeType=TOKE_IDENT
			
		Else If IsDigit( ch ) 
		
			While _pos<_len
				If Not IsDigit( _text[_pos] ) Exit
				_pos:+1
			Wend
			_tokeType=TOKE_INTLIT
			
		Else If ch=CHAR_QUOTE
		
			While _pos<_len
				Local ch:Int=_text[_pos]
				If ch=CHAR_QUOTE Exit
				_pos:+1
			Wend
			If _pos=_len Throw "String literal missing closing quote"
			_tokeType=TOKE_STRINGLIT
			_pos:+1
			
		Else
			Local digraphs:String[]=[":="]
			If _pos<_len
				Local ch:Int=_text[_pos]
				For Local t:String=EachIn digraphs
					If ch=t[1]
						_pos:+1
						Exit
					EndIf
				Next
			EndIf
			_tokeType=TOKE_SYMBOL
		EndIf
		
		_toke=_text[pos.._pos]
		
		Return _toke
	End Method
	
	Method Toke:String()
		Return _toke
	End Method
	
	Method TokeType:Int()
		Return _tokeType
	End Method
	
	Method CParse:Int( toke:String )
		If _toke<>toke Return False
		Bump
		Return True
	End Method
	
	Method CParseIdent:String()
		If _tokeType<>TOKE_IDENT Return ""
		Local id:String=_toke
		Bump
		Return id
	End Method
	
	Method CParseLiteral:String()
		If _tokeType<>TOKE_INTLIT And _tokeType<>TOKE_FLOATLIT And _tokeType<>TOKE_STRINGLIT Return ""
		Local id:String=_toke
		Bump
		Return id
	End Method
	
	Method Parse:String()
		Local toke:String=_toke
		Bump
		Return toke
	End Method
	
	Method ParseToke( toke:String )
		If Not CParse( toke ) Throw "Expecting '"+toke+"'"
	End Method
	
	Method ParseIdent:String()
		Local id:String=CParseIdent()
		If Not id Throw "Expecting identifier"
		Return id
	End Method
	
	Method ParseLiteral:String()
		Local id:String=CParseLiteral()
		If Not id Throw "Expecting literal"
		Return id
	End Method

	Field _text:String
	Field _pos:Int
	Field _len:Int
	Field _toke:String
	Field _tokeType:Int
	
End Type

Type TGlslParser Extends TParser

	Method ParseType:String()
		Local id:String=ParseIdent()
		Return id
	End Method
	
End Type

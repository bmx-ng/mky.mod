' 
' Copyright (c) 2015 Bruce Henderson
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
Strict

Import "maps.c"

Extern
	Function bmx_map_stringfloatmap_clear(root:Byte Ptr Ptr)
	Function bmx_map_stringfloatmap_isempty:Int(root:Byte Ptr Ptr)
	Function bmx_map_stringfloatmap_insert(key:String, value:Float, root:Byte Ptr Ptr)
	Function bmx_map_stringfloatmap_contains:Int(key:String, root:Byte Ptr Ptr)
	Function bmx_map_stringfloatmap_valueforkey:Float(key:String, root:Byte Ptr Ptr)
	Function bmx_map_stringfloatmap_remove:Int(key:String, root:Byte Ptr Ptr)
	Function bmx_map_stringfloatmap_firstnode:Byte Ptr(root:Byte Ptr)
	Function bmx_map_stringfloatmap_nextnode:Byte Ptr(node:Byte Ptr)
	Function bmx_map_stringfloatmap_key:String(node:Byte Ptr)
	Function bmx_map_stringfloatmap_value:Float(node:Byte Ptr)
	Function bmx_map_stringfloatmap_hasnext:Int(node:Byte Ptr, root:Byte Ptr)
	Function bmx_map_stringfloatmap_copy(dst:Byte Ptr Ptr, _root:Byte Ptr)
End Extern

Type TStringFloatMap

	Method Delete()
		Clear
	End Method

	Method Clear()
?ngcmod
		If Not IsEmpty() Then
			_modCount :+ 1
		End If
?
		bmx_map_stringfloatmap_clear(Varptr _root)
	End Method
	
	Method IsEmpty()
		Return bmx_map_stringfloatmap_isempty(Varptr _root)
	End Method
	
	Method Insert( key:String,value:Float )
		bmx_map_stringfloatmap_insert(key, value, Varptr _root)
?ngcmod
		_modCount :+ 1
?
	End Method

	Method Contains:Int( key:String )
		Return bmx_map_stringfloatmap_contains(key, Varptr _root)
	End Method
	
	Method ValueForKey:Float( key:String )
		Return bmx_map_stringfloatmap_valueforkey(key, Varptr _root)
	End Method
	
	Method Remove( key:String )
?ngcmod
		_modCount :+ 1
?
		Return bmx_map_stringfloatmap_remove(key, Varptr _root)
	End Method

	Method _FirstNode:TStringNode()
		If Not IsEmpty() Then
			Local node:TStringNode= New TStringNode
			node._root = _root
			Return node
		Else
			Return Null
		End If
	End Method
	
	Method Keys:TStringFloatMapEnumerator()
		Local nodeenum:TStringNodeEnumerator
		If Not isEmpty() Then
			nodeenum=New TStringKeyEnumerator
			nodeenum._node=_FirstNode()
		Else
			nodeenum=New TStringEmptyEnumerator
		End If
		Local mapenum:TStringFloatMapEnumerator=New TStringFloatMapEnumerator
		mapenum._enumerator=nodeenum
		nodeenum._map = Self
?ngcmod
		nodeenum._expectedModCount = _modCount
?
		Return mapenum
	End Method
	
	Method Values:TStringFloatMapEnumerator()
		Local nodeenum:TStringNodeEnumerator
		If Not isEmpty() Then
			nodeenum=New TStringValueEnumerator
			nodeenum._node=_FirstNode()
		Else
			nodeenum=New TStringEmptyEnumerator
		End If
		Local mapenum:TStringFloatMapEnumerator=New TStringFloatMapEnumerator
		mapenum._enumerator=nodeenum
		nodeenum._map = Self
?ngcmod
		nodeenum._expectedModCount = _modCount
?
		Return mapenum
	End Method
	
	Method Copy:TStringFloatMap()
		Local map:TStringFloatMap=New TStringFloatMap
		bmx_map_stringfloatmap_copy(Varptr map._root, _root)
		Return map
	End Method
	
	Method ObjectEnumerator:TStringNodeEnumerator()
		Local nodeenum:TStringNodeEnumerator=New TStringNodeEnumerator
		nodeenum._node=_FirstNode()
		nodeenum._map = Self
?ngcmod
		nodeenum._expectedModCount = _modCount
?
		Return nodeenum
	End Method

	Field _root:Byte Ptr

?ngcmod
	Field _modCount:Int
?

End Type

Type TStringNode
	Field _root:Byte Ptr
	Field _nodePtr:Byte Ptr
	
	Method Key:String()
		Return bmx_map_stringfloatmap_key(_nodePtr)
	End Method
	
	Method Value:Float()
		Return bmx_map_stringfloatmap_value(_nodePtr)
	End Method

	Method HasNext()
		Return bmx_map_stringfloatmap_hasnext(_nodePtr, _root)
	End Method
	
	Method NextNode:TStringNode()
		If Not _nodePtr Then
			_nodePtr = bmx_map_stringfloatmap_firstnode(_root)
		Else
			_nodePtr = bmx_map_stringfloatmap_nextnode(_nodePtr)
		End If

		Return Self
	End Method
	
End Type

Type TStringNodeEnumerator
	Method HasNext()
		Local has:Int = _node.HasNext()
		If Not has Then
			_map = Null
		End If
		Return has
	End Method
	
	Method NextObject:Object()
?ngcmod
		Assert _expectedModCount = _map._modCount, "TStringFloatMap Concurrent Modification"
?
		Local node:TStringNode=_node
		_node=_node.NextNode()
		Return node
	End Method

	'***** PRIVATE *****
		
	Field _node:TStringNode	

	Field _map:TStringFloatMap
?ngcmod
	Field _expectedModCount:Int
?
End Type

Type TStringKeyEnumerator Extends TStringNodeEnumerator
	Method NextObject:Object()
?ngcmod
		Assert _expectedModCount = _map._modCount, "TStringFloatMap Concurrent Modification"
?
		Local node:TStringNode=_node
		_node=_node.NextNode()
		Return node.Key()
	End Method
End Type

Type TStringValueEnumerator Extends TStringNodeEnumerator
	Method NextObject:Object()
?ngcmod
		Assert _expectedModCount = _map._modCount, "TStringFloatMap Concurrent Modification"
?
		Local node:TStringNode=_node
		_node=_node.NextNode()
		_floatObj.value = node.Value()
		Return _floatObj
	End Method
	
	Field _floatObj:TFloat = New TFLoat
End Type

Type TFloat
	Field value:Float
End Type


Type TStringFloatMapEnumerator
	Method ObjectEnumerator:TStringNodeEnumerator()
		Return _enumerator
	End Method
	Field _enumerator:TStringNodeEnumerator
End Type

Type TStringEmptyEnumerator Extends TStringNodeEnumerator
	Method HasNext()
		_map = Null
		Return False
	End Method
End Type


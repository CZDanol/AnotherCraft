module ac.client.gl.gltypes;

import bindbc.opengl;

template GLType(BasicType) {
	static if (is(BasicType == ubyte))
		alias GLType = GL_UNSIGNED_BYTE;
	else static if (is(BasicType == int))
		alias GLType = GL_INT;
	else static if (is(BasicType == float))
		alias GLType = GL_FLOAT;
	else
		static assert(0, "Cannot convert " ~ BasicType.stringof ~ " to GLType");
}

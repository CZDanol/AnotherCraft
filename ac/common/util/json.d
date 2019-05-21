module ac.common.util.json;

import std.json;
import std.conv;

float float_(const ref JSONValue json) {
	if (json.type == JSONType.FLOAT)
		return json.floating;
	else if (json.type == JSONType.INTEGER)
		return cast(float) json.integer;
	else if (json.type == JSONType.UINTEGER) // I think it has this too
		return cast(float) json.uinteger;
	throw new Exception("not a numeric type, instead: " ~ to!string(json.type));
}

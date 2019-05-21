module ac.common.util.meta;

import std.algorithm;
import std.format;
import std.meta;
import std.range;

template staticArrayToTuple(alias array) {
	auto func(size_t i)() {
		return array[i];
	}

	mixin("alias staticArrayToTuple = AliasSeq!(%s);".format(iota(array.length).map!((ulong x) => "func!%s".format(x)).joiner(",")));
}

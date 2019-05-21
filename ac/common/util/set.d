module ac.common.util.set;

import std.container.array;

/// Set optimized for fast insert/remove and iteration
/// Based on hash table
struct Set(T_) {

public:
	alias T = T_;

public:
	pragma(inline) void insert(T val) {
		if (val in aa_)
			return;

		aa_[val] = arr_.length;
		arr_ ~= val;
	}

	/// Inserts the item, returns false if the item was already inserted
	pragma(inline) bool tryInsert(T val) {
		if (contains(val))
			return false;

		insert(val);
		return true;
	}

	pragma(inline) void remove(T val) {
		auto it = val in aa_;
		if (!it)
			return;

		// We put the last item in arr_ in place of the removed item
		const size_t pos = *it;
		T item = arr_[$ - 1];

		arr_[pos] = item;
		aa_[item] = pos;

		arr_.removeBack();
		aa_.remove(val);
	}

	void clear() {
		arr_.length = 0;
		aa_.clear();
	}

	pragma(inline) bool contains(T val) {
		return (val in aa_) !is null;
	}

	pragma(inline) bool isEmpty() {
		return arr_.length == 0;
	}

	pragma(inline) auto items() {
		return arr_[];
	}

	pragma(inline) size_t length() {
		return arr_.length;
	}

	pragma(inline) T randomItem() {
		return arr_[$ - 1];
	}

	pragma(inline) T takeRandomItem() {
		T result = randomItem;
		this.remove(result);
		return result;
	}

public:
	pragma(inline) bool opBinaryRight(string op : "in")(T val) {
		return this.contains(val);
	}

	pragma(inline) void opOpAssign(string op : "+")(T val) {
		this.insert(val);
	}

	pragma(inline) void opOpAssign(string op : "-")(T val) {
		this.remove(val);
	}

	pragma(inline) auto opIndex() {
		return arr_[];
	}

private:
	size_t[T] aa_;
	Array!T arr_;

}

module ac.common.util.ringbuffer;

struct RingBuffer(T, size_t capacity) {

public:
	pragma(inline) size_t length() {
		return length_;
	}

	pragma(inline) bool isEmpty() {
		return length_ == 0;
	}

	pragma(inline) bool isFull() {
		return length_ == capacity;
	}

	pragma(inline) ref T front() {
		assert(!isEmpty);
		return items_[start_];
	}

public:
	void insertBack(ref T item) {
		assert(!isFull);
		items_[(start_ + length_++) % capacity] = item;
	}

	void popFront() {
		assert(!isEmpty);
		start_ = (start_ + 1) % capacity;
		length_--;
	}

	T takeFront() {
		T result = front;
		popFront();
		return result;
	}

private:
	T[capacity] items_;
	size_t start_, length_;

}

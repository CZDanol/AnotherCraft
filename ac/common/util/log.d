module ac.common.util.log;

import core.atomic;
import core.sync.mutex;
import std.stdio;
import std.format;
import std.datetime.systime;

private __gshared Mutex mx;
private __gshared size_t ix = 0;

void writeLog(Args...)(Args args) {
	auto tm = Clock.currTime;
	synchronized (mx)
		writeln("%.6s [%.2s:%.2s:%.2s] ".format(ix++, tm.hour, tm.minute, tm.second), args);
}

shared static this() {
	mx = new Mutex();
}
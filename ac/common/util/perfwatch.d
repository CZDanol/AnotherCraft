module ac.common.util.perfwatch;

import std.format;
import std.range;
import std.algorithm;
import std.array;
import std.stdio;
import std.file;
import std.math;
import std.container.array;
import core.sync.mutex;

import ac.client.application;

private struct StackItem {
	string name, desc;
	float appTimeStart;
}

struct PerfStat {

public:
	string name;
	float timeSum = 0, minTime = float.max, maxTime = 0;
	ulong eventCount;

public:
	void accum(const ref PerfStat other) {
		timeSum += other.timeSum;
		eventCount += other.eventCount;
		minTime = other.minTime; //min(minTime, other.minTime);
		maxTime = other.maxTime; //max(maxTime, other.maxTime);
	}

}

private __gshared Array!StackItem stack;
private __gshared PerfStat[string] stats, allTimePerfStats;
private float lastReportTime;

private __gshared Mutex mx;
shared static this() {
	mx = new Mutex();
}

auto perfGuard(string name, string desc = null) {
	static struct Result {
		~this() {
			perfEnd();
		}
	}

	perfBegin(name, desc);
	return Result();
}

void perfBegin(string name, string desc = null) {
	synchronized (mx)
		stack ~= StackItem(name, desc, appTimeNow);
}

void customPerfReport(float duration, string name, string desc) {
	if (duration > 0.05)
		writefln("%s (%s) took %s s", name, desc, duration);

	synchronized (mx) {
		PerfStat* stat = &stats.require(name, PerfStat(name));
		stat.timeSum += duration;

		stat.minTime = min(stat.minTime, duration);
		stat.maxTime = max(stat.maxTime, duration);

		stat.eventCount++;
	}
}

void perfEnd() {
	StackItem si;

	synchronized (mx) {
		si = stack.back;
		stack.removeBack();
	}

	const float duration = appTimeNow - si.appTimeStart;
	customPerfReport(duration, si.name, si.desc);
}

string perfReport(float msDiv = 1) {
	string result;

	synchronized (mx) {
		float timeNow = appTimeNow;
		float reportDuration = timeNow - lastReportTime;
		lastReportTime = timeNow;

		PerfStat[] sstats = stats.byValue.array;
		sstats.sort!"a.timeSum > b.timeSum"();

		foreach (ref PerfStat stat; sstats) {
			result ~= "%24s  %5.2fms  %4sx\n".format(stat.name, stat.timeSum * 1000 / msDiv, stat.eventCount);
			//stat = PerfStat();
		}

		foreach (ref stat; stats)
			allTimePerfStats.require(stat.name, PerfStat(stat.name)).accum(stat);

		stats.clear();
	}

	return result;
}

PerfStat perfStat(string statName) {
	synchronized (mx) {
		return stats.get(statName, PerfStat());
	}
}

void savePerfLog() {
	PerfStat[] sstats = allTimePerfStats.byValue.array;
	sstats.sort!"a.timeSum > b.timeSum"();

	string result;

	foreach (ref PerfStat stat; sstats[0 .. min(5, $)]) {
		result ~= "%s\n=====\nTotal time: %.2f ms\nEvent count: %s\nAvg. time: %.2f ms\nMin/max time (last sampling): %.2f/%.2f ms\n\n\n".format(stat.name, stat.timeSum * 1000, stat.eventCount, stat.timeSum * 1000 / stat.eventCount, stat.minTime * 1000, stat.maxTime * 1000);
		//stat = PerfStat();
	}

	std.file.write("perfLog.txt", result);
}

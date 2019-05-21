module ac.common.util.aa;

auto merge(AA : Value[Key], Value, Key)(AA aa1, AA aa2) {
	foreach (key, value; aa2)
		aa1[key] = value;

	return aa1;
}
--_VALGRIND = true

--[===[
--]===]

--do return end

-- OK: well tested

Test { [[escape(1);]],
	run = 1,
}

Test {
	[[escape(2);]],
	[[escape(3);]],
	run = 5,
}

Test {
	[[escape(2);]],
	[[await 50ms; escape(3);]],
	run = 5,
}

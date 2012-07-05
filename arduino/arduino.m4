/*{-{*/

changequote(<,>)
changequote(`,´)

constant _INPUT, _INPUT_PULLUP, _OUTPUT, _LOW, _HIGH;

deterministic PIN00 with PIN01, PIN02, PIN03, PIN04, PIN05, PIN06, PIN07,
                         PIN08, PIN09, PIN10, PIN11, PIN12, PIN13;
deterministic PIN01 with PIN02, PIN03, PIN04, PIN05, PIN06, PIN07,
                         PIN08, PIN09, PIN10, PIN11, PIN12, PIN13;
deterministic PIN02 with PIN03, PIN04, PIN05, PIN06, PIN07, PIN08,
                         PIN09, PIN10, PIN11, PIN12, PIN13;
deterministic PIN03 with PIN04, PIN05, PIN06, PIN07, PIN08,
                         PIN09, PIN10, PIN11, PIN12, PIN13;
deterministic PIN04 with PIN05, PIN06, PIN07, PIN08, PIN09,
                         PIN10, PIN11, PIN12, PIN13;
deterministic PIN05 with PIN06, PIN07, PIN08, PIN09,
                         PIN10, PIN11, PIN12, PIN13;
deterministic PIN06 with PIN07, PIN08, PIN09, PIN10, PIN11, PIN12, PIN13;
deterministic PIN07 with PIN08, PIN09, PIN10, PIN11, PIN12, PIN13;
deterministic PIN08 with PIN09, PIN10, PIN11, PIN12, PIN13;
deterministic PIN09 with PIN10, PIN11, PIN12, PIN13;
deterministic PIN10 with PIN11, PIN12, PIN13;
deterministic PIN11 with PIN12, PIN13;
deterministic PIN12 with PIN13;

/*}-}*/dnl

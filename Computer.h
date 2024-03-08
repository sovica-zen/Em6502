#pragma once
#include "CPU.h"
#include "Mem.h"
#include "Clock.h"

class Computer {
	CPU cpu;
	Mem ram;
	Clock clock;

public:
	void run();
	void stop();
	Computer();
};
#include <iostream>
#include "CPU.h"
#include "testfile.h"

int cycles = 128;

unsigned char rawData[RAM_SIZE] = {

};




int main() {
	CPU cpu = CPU();
	Mem* ram = new Mem();
	cpu.ram = ram;
	
	ram->load(rawData, RAM_SIZE);
	
	cpu.PC = 0x0400;
	while (cycles--) {
		//ram->Print(cpu.PC, 0, 64);
		ram->Print(cpu.PC, 0x400, 0x400+500);
		byte instruction = ram->read(cpu.PC);
		cpu.execute(instruction);
		cpu.printRegisters();
		cpu.printSR();
		getchar();
	}
}

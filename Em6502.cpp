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
	
	ram->load(SNAKE, RAM_SIZE);
	

	cpu.PC = 0;
	while (cycles--) {
		ram->Print(cpu.PC, 0, 512);
		//ram->Print(cpu.PC, 0, 0x050f);
		byte instruction = ram->read(cpu.PC);
		cpu.execute(instruction);
		cpu.printRegisters();
		cpu.printSR();
		getchar();
	}
}

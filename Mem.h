#pragma once
#include "typedefs.h"
#include <string>



class Mem {
	byte ram[RAM_SIZE] = {};

public:
	void write(word address, byte value);
	byte read(word address);
	word readAddress(word address);
	void load(std::string binary);
	void load(byte binary[], int count);
	void Print();
	void Print(word PC, int begin, int end);

	void PrintRelative(word PC, int begin, int end);

	Mem() {};
};
 

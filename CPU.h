#pragma once
#include "typedefs.h"
#include "Mem.h"

class CPU {
public:
	enum AddrMode {
		Imp, Accum, Imm, Abs, ZP, ZPX, ZPY, 
		ABSX, ABSY, Rel, INDX, INDY, Ind
	};

	Mem* ram;


	/*  REGISTERS  */

	// accumulator, X and Y index registers, stack pointer
	byte A = 0, X = 0, Y = 0, SP = 0xff; 

	// program counter
	word PC = 0;


	// status register / status flags
	// N - negative
	// V - overflow
	// - - expansion
	// B - break command
	// D - decimal mode
	// I - disable interrupt
	// Z - zero
	// C - carry
	
	//		    NV-BDIZC	
	byte SR = 0b00000000; 

	struct SR {
		unsigned int N : 1, V : 1, B : 1, D : 1, I : 1, Z : 1, C : 1;
	};

	bool N = false, V = false, B = false, D = false, I = false, Z = false, C = false;

	CPU();
	byte statusFlagsToByte();
	void byteToStatusFlags(byte b);
	void LDA(byte n);
	void LDX(byte data);
	void LDY(byte data);

	void STA(byte data);
	void STX(byte data);
	void STY(byte data);

	void TAX(); 
	void TAY();
	void TSX();
	void TXA();
	void TXS();
	void TYA();

	void PHA();
	void PHP();
	void PLA();
	void PLP();

	byte ASL(byte data);
	byte LSR(byte data);
	byte ROL(byte data);
	byte ROR(byte data);

	void AND(byte data);
	void BIT(byte data);
	void EOR(byte data);
	void ORA(byte data);

	void ADC(byte data);
	void CMP(byte data);
	void CPX(byte data);
	void CPY(byte data);
	void SBC(byte data);

	byte DEC(byte data);
	void DEX();
	void DEY();
	byte INC(byte data);
	void INX();
	void INY();

	void BRK();
	void JMP(word addr);
	void JSR(word addr);
	void RTI();
	void RTS();

	void BCC();
	void BCS();
	void BEQ();
	void BMI();
	void BNE();
	void BPL();
	void BVS();
	void BVC();

	void CLC();
	void CLD();
	void CLI();
	void CLV();
	void SEC();
	void SED();
	void SEI();

	void NOP();


	void execute(byte opcode);
	void printRegisters();
	void printSR();

	void modifyZflag(byte r);
	void modifyNflag(byte r); 
	void modifyVflag(byte r, byte data, byte sum);
	void modifyCflag(byte r); 

	void push(byte data);
	byte pop();

	word bytesToWord(byte low, byte high);
	byte wordLow(word word);
	byte wordHigh(word word);

	void branch(byte offset);
};


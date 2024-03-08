#include "CPU.h"
#include <iostream>

void CPU::LDA(byte data) {
	A = data;
	if (A == 0) Z = 1; 
	else Z = 0;

	if ((1 << 7) & A) N = 1; 
	else N = 0;
}

void CPU::LDX(byte data) {
	X = data;
	if (X == 0) Z = 1;
	else Z = 0;

	if ((1 << 7) & X) N = 1;
	else N = 0;
}

void CPU::LDY(byte data) {
	Y = data;
	if (Y == 0) Z = 1;
	else Z = 0;

	if ((1 << 7) & Y) N = 1;
	else N = 0;
}

void CPU::STA(byte adr) {
	ram->write(adr, A);
}

void CPU::STX(byte adr) {
	ram->write(adr, X);
}

void CPU::STY(byte adr) {
	ram->write(adr, Y);
}

void CPU::TAX() {
	X = A;
	if (X == 0) Z = 1;
	else Z = 0;

	if ((1 << 7) & X) N = 1;
	else N = 0;
}

void CPU::TAY() {
	Y = A;
	if (Y == 0) Z = 1;
	else Z = 0;

	if ((1 << 7) & Y) N = 1;
	else N = 0;
}

void CPU::TSX() {
	X = SP;
	if (X == 0) Z = 1;
	else Z = 0;

	if ((1 << 7) & X) N = 1;
	else N = 0;
}

void CPU::TXA() {
	A = X;
	if (A == 0) Z = 1;
	else Z = 0;

	if ((1 << 7) & A) N = 1;
	else N = 0;
}

void CPU::TXS() {
	SP = X;
}

void CPU::TYA() {
	A = Y;
	if (A == 0) Z = 1;
	else Z = 0;

	if ((1 << 7) & A) N = 1;
	else N = 0;
}

void CPU::PHA() { 
	ram->write(SP, A);
	SP--;
}

void CPU::PHP() {
	ram->write(SP, statusFlagsToByte());
	SP--;
}

void CPU::PLA() {
	SP++;
	A = ram->read(SP);
	if (A == 0) Z = 1;
	else Z = 0;

	if ((1 << 7) & A) N = 1;
	else N = 0;
}

void CPU::PLP() {
	SP++;
	byte stack_value = ram->read(SP);
	byteToStatusFlags(stack_value);
}

byte CPU::ASL(byte data) {
	C = data >> 7 & 1;
	N = data >> 6 & 1;
	if (data << 1 == 0) Z = 1;
	else Z = 0;
	return data << 1;
}

byte CPU::LSR(byte data) {
	C = data & 1;
	N = 0;
	if (data >> 1 == 0) Z = 1;
	else Z = 0;
	return data >> 1;
}

byte CPU::ROL(byte data) {
	byte result = data;
	C = data >> 7 & 1;
	N = data >> 6 & 1;
	result = result << 1;
	if (C) result += C;
	if (result == 0) Z = 1;
	else Z = 0;
	return result;
}

byte CPU::ROR(byte data) {
	byte result = data;
	C = data & 1;
	result = result >> 1;
	result += C << 7;
	if (C) N = 1;
	else N = 0;
	if (result == 0) Z = 1;
	else Z = 0;
	return result;
}

void CPU::AND(byte data) {
	A = A & data;
	if (A == 0) Z = 1;
	else Z = 0;
	if ((1 << 7) & A) N = 1;
	else N = 0;
}

void CPU::BIT(byte data) {
	byte result = A & data;
	if (result == 0) Z = 1;
	else Z = 0;
	if ((1 << 7) & data) N = 1;
	else N = 0;
	if ((1 << 6) & data) V = 1;
}

void CPU::EOR(byte data) {
	A = A ^ data;
	if (A == 0) Z = 1;
	else Z = 0;
	if ((1 << 7) & A) N = 1;
	else N = 0;
}

void CPU::ORA(byte data) {
	A = A | data;
	if (A == 0) Z = 1;
	else Z = 0;
	if ((1 << 7) & A) N = 1;
	else N = 0;
}

void CPU::ADC(byte data) {
	bool setCarry = false;
	int sum = A + data + C;
	if (sum > 255) setCarry = true;
	modifyVflag(A, data, sum);
	modifyZflag(A);
	modifyNflag(A);
	A += data + C;
	C = setCarry;
}

void CPU::CMP(byte data) {
	byte result = A - data;
	modifyZflag(result);
	modifyNflag(result);
	if (data <= A) C = 1;
	else C = 0;
}

void CPU::CPX(byte data) {
	byte result = X - data;
	modifyZflag(result);
	modifyNflag(result);
	if (data <= X) C = 1;
	else C = 0;
}

void CPU::CPY(byte data) {
	byte result = Y - data;
	modifyZflag(result);
	modifyNflag(result);
	if (data <= Y) C = 1;
	else C = 0;
}

void CPU::SBC(byte data) {
	byte result = A - data;
	if (!C) result--;
	modifyZflag(result);
	modifyNflag(result);
	modifyVflag(A, data, result);
	if (A >= data + !C) C = 1;
	else C = 0;
	A = result;
}

byte CPU::DEC(byte data) {
	byte result = data--;
	modifyZflag(result);
	modifyNflag(result);
	return result;
}

void CPU::DEX() {
	X--;
	modifyZflag(X);
	modifyNflag(X);
}

void CPU::DEY() {
	Y--;
	modifyZflag(Y);
	modifyNflag(Y);
}

byte CPU::INC(byte data) {
	byte result = data++;
	modifyZflag(result);
	modifyNflag(result);
	return result;
}

void CPU::INX() {
	X++;
	modifyZflag(X);
	modifyNflag(X);
}

void CPU::INY() {
	Y++;
	modifyZflag(Y);
	modifyNflag(Y);
}

void CPU::JMP(word addr) {
	PC = addr;
}

void CPU::execute(byte opcode) {
	switch (opcode) { 
	case 0xA9: { // LDA imm
		byte data = ram->read(++PC);
		LDA(data);
		PC++;
		break;
	}
	case 0xAD: { // LDA abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		LDA(data);
		PC += 2;
		break;
	}
	case 0xBD: { // LDA absX
		word address = ram->readAddress(++PC);
		byte data = ram->read(address + X);
		LDA(data);
		PC += 2;
		break;
	}
	case 0xB9: { // LDA absY
		word address = ram->readAddress(++PC);
		byte data = ram->read(address + Y);
		LDA(data);
		PC += 2;
		break;
	}
	case 0xA5: { // LDA zero
		byte address = ram->read(++PC); // read only lower byte of address
		byte data = ram->read(address);
		LDA(data);
		PC++;
		break;
	}
	case 0xB5: { // LDA zeroX
		byte address = ram->read(++PC); 
		byte data = ram->read(address);
		LDA(data + X);
		PC++;
		break;
	}
	case 0xA1: { // LDA zeroXind
		byte indirect_address = ram->read(++PC);
		byte address = ram->read(indirect_address + X);
		byte data = ram->read(address);
		LDA(data);
		PC++;
		break;
	}
	case 0xB1: { // LDA zeroIndY
		byte indirect_address = ram->read(++PC);
		byte address = ram->read(indirect_address);
		byte data = ram->read(address + Y);
		LDA(data);
		PC++;
		break;
	}


	case 0xA2: { // LDX imm
		byte data = ram->read(++PC);
		LDX(data);
		PC++;
		break;
	}
	case 0xAE: { // LDX abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		LDX(data);
		PC += 2;
		break;
	}
	case 0xBE: { // LDX absY
		word address = ram->readAddress(++PC);
		byte data = ram->read(address + Y);
		LDX(data);
		PC += 2;
		break;
	}
	case 0xA6: { // LDX zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		LDX(data);
		PC++;
		break;
	}
	case 0xB6: { // LDX zeroY
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		LDX(data + Y);
		PC++;
		break;
	}


	case 0xA0: { // LDY imm
		byte data = ram->read(++PC);
		LDY(data);
		PC++;
		break;
	}
	case 0xAC: { // LDY abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		LDY(data);
		PC += 2;
		break;
	}
	case 0xBC: { // LDY absX
		word address = ram->readAddress(++PC);
		byte data = ram->read(address + X);
		LDY(data);
		PC += 2;
		break;
	}
	case 0xA4: { // LDY zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		LDY(data);
		PC++;
		break;
	}
	case 0xB4: { // LDY zeroX
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		LDY(data + X);
		PC++;
		break;
	}

	
	case 0x8D: { //STA abs
		word addr = ram->readAddress(++PC);
		ram->write(addr, A);
		PC += 2;
		break;
	}
	case 0x9D: { //STA absX
		word addr = ram->readAddress(++PC) + X;
		ram->write(addr, A);
		PC += 2;
		break;
	}
	case 0x99: { //STA absY
		word addr = ram->readAddress(++PC) + Y;
		ram->write(addr, A);
		PC += 2;
		break;
	}
	case 0x85: { //STA zero
		byte addr = ram->read(++PC);
		ram->write(addr, A);
		PC++;
		break;
	}
	case 0x95: { //STA zeroX
		byte addr = ram->read(++PC) + X;
		ram->write(addr, A);
		PC++;
		break;
	}
	case 0x81: { //STA zeroXind
		byte indirect_address = ram->read(++PC) + X;
		word address = ram->readAddress(indirect_address);
		ram->write(address, A);
		PC++;
		break;
	}
	case 0x91: { //STA zeroIndY
		word indirect_address = ram->readAddress(++PC);
		word address = indirect_address + Y;
		ram->write(address, A);
		PC++;
		break;
	}


	case 0x8E: { //STX abs
		word addr = ram->readAddress(++PC);
		ram->write(addr, X);
		PC++;
		PC++;
		break;
	}
	case 0x86: { //STX zero
		byte addr = ram->read(++PC);
		ram->write(addr, X);
		PC++;
		break;
	}
	case 0x96: { //STX zeroY
		byte addr = ram->read(++PC) + Y;
		ram->write(addr, X);
		PC++;
		break;
	}


	case 0x8C: { //STY abs
		word addr = ram->readAddress(++PC);
		ram->write(addr, Y);
		PC++;
		PC++;
		break;
	}
	case 0x84: { //STY zero
		byte addr = ram->read(++PC);
		ram->write(addr, Y);
		PC++;
		break;
	}
	case 0x94: { //STY zeroX
		byte addr = ram->read(++PC) + X;
		ram->write(addr, Y);
		PC++;
		break;
	}
	

	case 0xAA: { // TAX
		TAX();
		PC++;
		break;
	}
	case 0xA8: { // TAY
		TAY();
		PC++;
		break;
	}
	case 0xBA: { // TSX
		TSX();
		PC++;
		break;
	}
	case 0x8A: { // TXA
		TXA();
		PC++;
		break;
	}
	case 0x9A: { // TXS
		TXS();
		PC++;
		break;
	}
	case 0x98: { // TYA
		TYA();
		PC++;
		break;
	}


	case 0x48: { // PHA
		PHA();
		PC++;
		break;
	}
	case 0x08: { // PHP
		PHP();
		PC++;
		break;
	}
	case 0x68: { // PLA
		PLA();
		PC++;
		break;
	}
	case 0x28: { // PLP
		PLP();
		PC++;
		break;
	}


	case 0x0A: { // ASL acc
		A = ASL(A);
		PC++;
		break;
	}
	case 0x0E: { // ASL abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		ram->write(address, ASL(data));
		PC += 2;
		break;
	}
	case 0x1E: { // ASL absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, ASL(data));
		PC += 2;
		break;
	}
	case 0x06: { // ASL zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		ram->write(address, ASL(data));
		PC++;
		break;
	}
	case 0x16: { // ASL zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, ASL(data));
		PC++;
		break;
	}


	case 0x4A: { // LSR acc
		A = LSR(A);
		PC++;
		break;
	} 
	case 0x4E: { // LSR abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		ram->write(address, LSR(data));
		PC += 2;
		break;
	}
	case 0x5E: { // LSR absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, LSR(data));
		PC += 2;
		break;
	}
	case 0x46: { // LSR zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		ram->write(address, LSR(data));
		PC++;
		break;
	}
	case 0x56: { // LSR zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, LSR(data));
		PC++;
		break;
	}


	case 0x2A: { // ROL acc
		A = ROL(A);
		PC++;
		break;
	}
	case 0x2E: { // ROL abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		ram->write(address, ROL(data));
		PC += 2;
		break;
	}
	case 0x3E: { // ROL absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, ROL(data));
		PC += 2;
		break;
	}
	case 0x26: { // ROL zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		ram->write(address, ROL(data));
		PC++;
		break;
	}
	case 0x36: { // ROL zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, ROL(data));
		PC++;
		break;
	}


	case 0x6A: { // ROR acc
		A = ROR(A);
		PC++;
		break;
	}
	case 0x6E: { // ROR abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		ram->write(address, ROR(data));
		PC += 2;
		break;
	}
	case 0x7E: { // ROR absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, ROR(data));
		PC += 2;
		break;
	}
	case 0x66: { // ROR zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		ram->write(address, ROR(data));
		PC++;
		break;
	}
	case 0x76: { // ROR zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, ROR(data));
		PC++;
		break;
	}


	case 0x29: { // AND imm
		byte data = ram->read(++PC);
		AND(data);
		PC++;
		break;
	}
	case 0x2D: { // AND abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		AND(data);
		PC += 2;
		break;
	}
	case 0x3D: { // AND absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		AND(data);
		PC += 2;
		break;
	}
	case 0x39: { // AND absY
		word address = ram->readAddress(++PC) + Y;
		byte data = ram->read(address);
		AND(data);
		PC += 2;
		break;
	}
	case 0x25: { // AND zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		AND(data);
		PC++;
		break;
	}
	case 0x35: { // AND zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		AND(data);
		PC++;
		break;
	}
	case 0x21: { // AND zeroXind
		byte indirect_address = ram->read(++PC) + X;
		word address = ram->readAddress(indirect_address);
		byte data = ram->read(address);
		AND(data);
		PC++;
		break;
	}
	case 0x31: { // AND zeroIndY
		word indirect_address = ram->readAddress(++PC);
		word address = indirect_address + Y;
		byte data = ram->read(address);
		AND(data);
		PC++;
		break;
	}


	case 0x2C: { // BIT abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		BIT(data);
		PC++;
		break;
	}
	case 0x24: { // BIT zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		BIT(data);
		PC++;
		break;
	}


	case 0x49: { // EOR imm
		byte data = ram->read(++PC);
		EOR(data);
		PC++;
		break;
	}
	case 0x4D: { // EOR abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		EOR(data);
		PC += 2;
		break;
	}
	case 0x5D: { // EOR absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		EOR(data);
		PC += 2;
		break;
	}
	case 0x59: { // EOR absY
		word address = ram->readAddress(++PC) + Y;
		byte data = ram->read(address);
		EOR(data);
		PC += 2;
		break;
	}
	case 0x45: { // EOR zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		EOR(data);
		PC++;
		break;
	}
	case 0x55: { // EOR zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		EOR(data);
		PC++;
		break;
	}
	case 0x41: { // EOR zeroXind
		byte indirect_address = ram->read(++PC) + X;
		word address = ram->readAddress(indirect_address);
		byte data = ram->read(address);
		EOR(data);
		PC++;
		break;
	}
	case 0x51: { // EOR zeroIndY
		word indirect_address = ram->readAddress(++PC);
		word address = indirect_address + Y;
		byte data = ram->read(address);
		EOR(data);
		PC++;
		break;
	}


	case 0x09: { // ORA imm
		byte data = ram->read(++PC);
		ORA(data);
		PC++;
		break;
	}
	case 0x0D: { // ORA abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		ORA(data);
		PC += 2;
		break;
	}
	case 0x1D: { // ORA absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		ORA(data);
		PC += 2;
		break;
	}
	case 0x19: { // ORA absY
		word address = ram->readAddress(++PC) + Y;
		byte data = ram->read(address);
		ORA(data);
		PC += 2;
		break;
	}
	case 0x05: { // ORA zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		ORA(data);
		PC++;
		break;
	}
	case 0x15: { // ORA zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		ORA(data);
		PC++;
		break;
	}
	case 0x01: { // ORA zeroXind
		byte indirect_address = ram->read(++PC) + X;
		word address = ram->readAddress(indirect_address);
		byte data = ram->read(address);
		ORA(data);
		PC++;
		break;
	}
	case 0x11: { // ORA zeroIndY
		word indirect_address = ram->readAddress(++PC);
		word address = indirect_address + Y;
		byte data = ram->read(address);
		ORA(data);
		PC++;
		break;
	}


	case 0x69: { // ADC imm
		byte data = ram->read(++PC);
		ADC(data);
		PC++;
		break;
	}
	case 0x6D: { // ADC abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		ADC(data);
		PC += 2;
		break;
	}
	case 0x7D: { // ADC absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		ADC(data);
		PC += 2;
		break;
	}
	case 0x79: { // ADC absY
		word address = ram->readAddress(++PC) + Y;
		byte data = ram->read(address);
		ADC(data);
		PC += 2;
		break;
	}
	case 0x65: { // ADC zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		ADC(data);
		PC++;
		break;
	}
	case 0x75: { // ADC zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		ADC(data);
		PC++;
		break;
	}
	case 0x61: { // ADC zeroXind
		byte indirect_address = ram->read(++PC) + X;
		word address = ram->readAddress(indirect_address);
		byte data = ram->read(address);
		ADC(data);
		PC++;
		break;
	}
	case 0x71: { // ADC zeroIndY
		word indirect_address = ram->readAddress(++PC);
		word address = indirect_address + Y;
		byte data = ram->read(address);
		ADC(data);
		PC++;
		break;
	}


	case 0xC9: { // CMP imm
		byte data = ram->read(++PC);
		CMP(data);
		PC++;
		break;
	}
	case 0xCD: { // CMP abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		CMP(data);
		PC += 2;
		break;
	}
	case 0xDD: { // CMP absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		CMP(data);
		PC += 2;
		break;
	}
	case 0xD9: { // CMP absY
		word address = ram->readAddress(++PC) + Y;
		byte data = ram->read(address);
		CMP(data);
		PC += 2;
		break;
	}
	case 0xC5: { // CMP zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		CMP(data);
		PC++;
		break;
	}
	case 0xD5: { // CMP zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		CMP(data);
		PC++;
		break;
	}
	case 0xC1: { // CMP zeroXind
		byte indirect_address = ram->read(++PC) + X;
		word address = ram->readAddress(indirect_address);
		byte data = ram->read(address);
		CMP(data);
		PC++;
		break;
	}
	case 0xD1: { // CMP zeroIndY
		word indirect_address = ram->readAddress(++PC);
		word address = indirect_address + Y;
		byte data = ram->read(address);
		CMP(data);
		PC++;
		break;
	}


	case 0xE0: { // CPX imm
		byte data = ram->read(++PC);
		CPX(data);
		PC++;
		break;
	}
	case 0xEC: { // CPX abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		CPX(data);
		PC += 2;
		break;
	}
	case 0xE4: { // CPX zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		CPX(data);
		PC++;
		break;
	}


	case 0xC0: { // CPY imm
		byte data = ram->read(++PC);
		CPY(data);
		PC++;
		break;
	}
	case 0xCC: { // CPY abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		CPY(data);
		PC += 2;
		break;
	}
	case 0xC4: { // CPY zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		CPY(data);
		PC++;
		break;
	}


	case 0xE9: { // SBC imm
		byte data = ram->read(++PC);
		SBC(data);
		PC++;
		break;
	}
	case 0xED: { // SBC abs
		word address = ram->readAddress(++PC);
		byte data = ram->read(address);
		SBC(data);
		PC += 2;
		break;
	}
	case 0xFD: { // SBC absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		SBC(data);
		PC += 2;
		break;
	}
	case 0xF9: { // SBC absY
		word address = ram->readAddress(++PC) + Y;
		byte data = ram->read(address);
		SBC(data);
		PC += 2;
		break;
	}
	case 0xE5: { // SBC zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		SBC(data);
		PC++;
		break;
	}
	case 0xF5: { // SBC zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		SBC(data);
		PC++;
		break;
	}
	case 0xE1: { // SBC zeroXind
		byte indirect_address = ram->read(++PC) + X;
		word address = ram->readAddress(indirect_address);
		byte data = ram->read(address);
		SBC(data);
		PC++;
		break;
	}
	case 0xF1: { // SBC zeroIndY
		word indirect_address = ram->readAddress(++PC);
		word address = indirect_address + Y;
		byte data = ram->read(address);
		SBC(data);
		PC++;
		break;
	}


	case 0xCE: { // DEC abs
		word addr = ram->readAddress(++PC);
		byte data = ram->read(addr);
		ram->write(addr, DEC(data));
		PC += 2;
		break;
	}
	case 0xDE: { // DEC absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, DEC(data));
		PC += 2;
		break;
	}
	case 0xC6: { // DEC zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		ram->write(address, DEC(data));
		PC++;
		break;
	}
	case 0xD6: { // DEC zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, DEC(data));
		PC++;
		break;
	}


	case 0xCA: { // DEX 
		DEX();
		PC++;
		break;
	}
	case 0x88: { // DEY
		DEY();
		PC++;
		break;
	}


	case 0xEE: { // INC abs
		word addr = ram->readAddress(++PC);
		byte data = ram->read(addr);
		ram->write(addr, INC(data));
		PC += 2;
		break;
	}
	case 0xFE: { // INC absX
		word address = ram->readAddress(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, INC(data));
		PC += 2;
		break;
	}
	case 0xE6: { // INC zero
		byte address = ram->read(++PC);
		byte data = ram->read(address);
		ram->write(address, INC(data));
		PC++;
		break;
	}
	case 0xF6: { // INC zeroX
		byte address = ram->read(++PC) + X;
		byte data = ram->read(address);
		ram->write(address, INC(data));
		PC++;
		break;
		break;
	}


	case 0xE8: { // INX 
		INX();
		PC++;
		break;
	}
	case 0xC8: { // INY
		INY();
		PC++;
		break;
	}


	case 0x4C: { // JMP abs
		word addr = ram->readAddress(++PC);
		JMP(addr);
		break;
	}
	case 0x6C: { // JMP absInd
		word indirect = ram->readAddress(++PC);
		word address = ram->readAddress(indirect);
		JMP(address);
		break;
	}


	case 0x20: { // JSR abs
		word addr = ram->readAddress(++PC);
		PC++;
		push(wordHigh(PC));
		push(wordLow(PC));
		PC = addr;
		break;
	}
	case 0x40: { // RTI abs
		
	}

	case 0x60: { // RTS abs
		byte low = pop();
		byte high = pop();
		PC = bytesToWord(low, high);
		PC++;
		break;
	}
	case 0x00: { // BRK

		break;
	}
	case 0x90: { // BCC rel
		byte offset = ram->read(++PC);
		if (!C) {
			branch(offset);
		} else PC++;
		break;
	}
	case 0xB0: { // BCS rel
		signed_byte offset = ram->read(++PC);
		if (C) {
			branch(offset);
		} else PC++;
		break;
	}
	case 0xF0: { // BEQ rel
		signed_byte offset = ram->read(++PC);
		if (Z) {
			branch(offset);
		}
		else PC++;
		break;
	}
	case 0x30: { // BMI rel
		signed_byte offset = ram->read(++PC);
		if (N) {
			branch(offset);
		}
		else PC++;
		break;
	}
	case 0xD0: { // BNE rel
		signed_byte offset = ram->read(++PC);
		if (!Z) {
			branch(offset);
		}
		else PC++;
		break;
	}
	case 0x10: { // BPL rel
		signed_byte offset = ram->read(++PC);
		if (!N) {
			branch(offset);
		}
		else PC++;
		break;
	}
	case 0x50: { // BVC rel
		signed_byte offset = ram->read(++PC);
		if (!V) {
			branch(offset);
		}
		else PC++;
		break;
	}
	case 0x70: { // BVS rel
		signed_byte offset = ram->read(++PC);
		if (V) {
			branch(offset);
		}
		else PC++;
		break;
	}
	case 0x18: { // CLC
		C = 0;
		PC++;
		break;
	}
	case 0xD8: { // CLD
		D = 0;
		PC++;
		break;
	}
	case 0x58: { // CLI
		I = 0;
		PC++;
		break;
	}
	case 0xB8: { // CLV
		V = 0;
		PC++;
		break;
	}
	case 0x38: { // SEC
		C = 1;
		PC++;
		break;
	}
	case 0xF8: { // SED
		D = 1;
		PC++;
		break;
	}
	case 0x78: { // SEI
		I = 1;
		PC++;
		break;
	}
	case 0xEA: { // NOP
		PC++;
		break;
	}
	default:{
		PC++;
		break;
	}

	}
}

void CPU::printRegisters() {
	printf(
		"\nA: %02x | X: %02x | Y: %02x | SP: %02x | PC: %04x \n", 
		A & 0xff, X & 0xff, Y & 0xff, SP & 0xff, PC & 0xffff
	);
}

void CPU::printSR() {
	printf(
		"\n NV-BDIZC \n %d%d0%d%d%d%d%d \n",
		(int)N, (int)V, (int)B, (int)D, (int)I, (int)Z, (int)C
	);
}

byte CPU::statusFlagsToByte() {
	byte result = 0b00110000;
	result += N << 7;
	result += V << 6;
	result += B << 4;
	result += D << 3;
	result += I << 2;
	result += Z << 1;
	result += C << 0;
	return result;
}

void CPU::byteToStatusFlags(byte b) {
	N = (1 << 7) & b;
	V = (1 << 6) & b;
	B = (1 << 4) & b;
	D = (1 << 3) & b;
	I = (1 << 2) & b;
	Z = (1 << 1) & b;
	C = (1 << 0) & b;
}

void CPU::modifyZflag(byte r) {
	if (r == 0) Z = 1;
	else Z = 0;
}

void CPU::modifyNflag(byte r) {
	if ((1 << 7) & r) N = 1;
	else N = 0;
}

void CPU::modifyVflag(byte r, byte data, byte sum) {
	if ((r ^ sum) & (data ^ sum) & 0x80) V = 1;
	else V = 0;
}

void CPU::push(byte data) {
	ram->write(SP, data);
	SP--;
}

byte CPU::pop() {
	byte b = ram->read(SP);
	SP++;
	return b;
}

byte CPU::wordLow(word w) {
	byte low = (w & 0xff00) >> 8;
	return low;
}

byte CPU::wordHigh(word w) {
	byte high = (w & 0x00ff);
	return high;
}

word CPU::bytesToWord(byte low, byte high) {
	word h = high;
	word l = low << 8;
	return l + h;
}


void CPU::branch(byte offset) {
	PC += offset;
}




CPU::CPU() {
	
}


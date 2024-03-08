#include "Mem.h"
#include <iostream>
#include <sstream>

void Mem::write(word address, byte value) {
    ram[address] = value;
}

byte Mem::read(word address) {
    return ram[address];
}

word Mem::readAddress(word address) {
    byte low = read(address);
    byte high = read(address + 1);
    word addr = 0;
    addr |= high;
    addr <<= 8;
    addr |= low;
    return addr;
}


void Mem::load(std::string binary) {
    std::stringstream stream;
    std::string curr_byte;
    stream << binary;
    for (int i = 0; i < binary.length(); i++) {
        stream >> curr_byte;
        // todo
    }
}

void Mem::load(byte binary[], int count) {
    memcpy(&ram, binary, count);
}


void Mem::Print() {
    int counter = 0;
    for (auto a : ram) {
        if (counter % 16 == 0) std::cout << "\n";
        std::cout << std::hex << (int)a;
    }
}

void Mem::Print(word PC, int begin = 0, int end = 65536) {
    std::cout << "   " << "\x1B[32m";
    for (int i = 0; i < 16; i++) {
        printf("%02x ", i);
    }
    std::cout << " " << "\u001b[0m";

    for (int i = begin; i < end; i++) {
        if (i % 16 == 0) {
            std::cout << "\n";
            std::cout << "\x1B[32m"; printf("%02x", i / (16 * 16)); std::cout << "\u001b[0m" << " ";
        }
        if (i == PC) std::cout << "\x1B[31m";
        printf("%02x", ram[i] & 0xff);
        std::cout << " " << "\u001b[0m";
    }
}





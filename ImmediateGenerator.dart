class ImmGen {
  static int gerar(int instruction) {
    int opcode = instruction & 0x7F;

    switch (opcode) {
      // Tipo-I: Loads (0x03), Aritmético (0x13), JALR (0x67)
      case 0x03:
      case 0x13:
      case 0x67:
        int imm12 = (instruction >> 20) & 0xFFF;
        return imm12.toSigned(12); // Estende o bit 11 para 32 bits

      // Tipo-S: Stores (0x23)
      case 0x23:
        int imm11_5 = (instruction >> 25) & 0x7F;
        int imm4_0  = (instruction >> 7) & 0x1F;
        int imm12   = (imm11_5 << 5) | imm4_0;
        return imm12.toSigned(12);

      // Tipo-B: Branches (0x63)
      case 0x63:
        int imm12   = (instruction >> 31) & 0x01;
        int imm10_5 = (instruction >> 25) & 0x3F;
        int imm4_1  = (instruction >> 8) & 0x0F;
        int imm11   = (instruction >> 7) & 0x01;
        int imm13   = (imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1);
        return imm13.toSigned(13);

      // Tipo-U: LUI (0x37), AUIPC (0x17)
      case 0x37:
      case 0x17:
        return (instruction & 0xFFFFF000).toSigned(32);

      // Tipo-J: JAL (0x6F)
      case 0x6F:
        int imm20    = (instruction >> 31) & 0x01;
        int imm10_1  = (instruction >> 21) & 0x3FF;
        int imm11    = (instruction >> 20) & 0x01;
        int imm19_12 = (instruction >> 12) & 0xFF;
        int imm21    = (imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1);
        return imm21.toSigned(21);

      default:
        return 0;
    }
  }
}


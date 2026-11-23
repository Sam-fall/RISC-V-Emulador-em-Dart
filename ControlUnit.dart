import 'Ula.dart';

class ControlUnit {
  
  // Sinais de entrada mux de escrita para o banco de registradores
  static const int RESULT_ULA = 0;
  static const int RESULT_MEM = 1;
  static const int RESULT_PC4 = 2;
  static const int RESULT_IMM = 3;
  static const int RESULT_RS1 = 4; // Leva rs1 direto para rd (usado no CMOV)

  bool ulaSrcA = false;   // false = rs1 | true = PC (para AUIPC)
  bool ulaSrcB = false;   // false = rs2 | true = Imediato (seu antigo ulaSrc)
  bool regWrite = false;  // Permissão para gravar no rd
  bool memRead = false;   // Permissão para ler da RAM
  bool memWrite = false;  // Permissão para gravar na RAM
  bool branch = false;    // Instrução de salto condicional (Tipo-B)
  bool jump = false;      // Salto incondicional (JAL / JALR)
  bool isJalr = false;    // Diferencia JAL (PC + imm) de JALR (rs1 + imm)
  bool isCmov = false;    // Habilita escrita condicional no rd (apenas se rs2 != 0)

  int resultSrc = RESULT_ULA;
  int ulaOp     = Ula.OP_ADD; // Exposto para a ULA avaliar qual operação realizar
  int funct3    = 0;          // Exposto para a CPU avaliar Branch e tamanho de Load/Store

  void _resetarSinais() {
    ulaSrcB = false;
    regWrite = false;
    ulaSrcA = false;
    memRead = false;
    memWrite = false;
    branch = false;
    jump = false;
    isJalr = false;
    isCmov = false;
    resultSrc = RESULT_ULA;
    ulaOp = Ula.OP_ADD;
    funct3 = 0;
  }

  void Opcode(int instruction) {  
    _resetarSinais();
    int opcode = instruction & 0x7F;

    switch (opcode) {

      case 0x0B: // Instrução escolhida pelo Prof. CMOV
        tipoR_CMOV();
        break;

      case 0x37: { // Tipo-U LUI (Load Upper Immediate)
        tipoU_LUI();
        break;
      }

      case 0x17: { // Tipo-U AUIPC (Add Upper Immediate to PC)
        tipoU_AUIPC();
        break;
      }

      case 0x6F: { // Tipo-J JAL (Jump and Link)
        tipoJ();
        break;
      }

      case 0x67: { // Tipo-I JALR (Jump and Link Register)
        this.funct3 = (instruction >> 12) & 0x7;
        tipoI_JALR(funct3);
        break;
      }

      case 0x03: { // Tipo-I LOADS (LB, LH, LW, LBU, LHU)
        this.funct3 = (instruction >> 12) & 0x7;
        tipoI_LOADS(funct3);
        break;
      }

      case 0x13: { // TIPO-I ARITMÉTICO/LÓGICO
        this.funct3 = (instruction >> 12) & 0x7;
        int funct7 = (instruction >> 25) & 0x7F;
        tipoI_ARITHMETIC_LOGIC(funct7, funct3);
        break;
      }

      case 0x0F: { // Tipo-I FENCE (Sincronização)
        this.funct3 = (instruction >> 12) & 0x7;
        tipoI_FENCE(funct3);
        break;
      }

      case 0x73: { // Tipo-I ENVIRONMENT / CSR
        this.funct3 = (instruction >> 12) & 0x7;
        int funct12 = (instruction >> 20) & 0xFFF;
        tipoI_EVERINMENT_CSR(funct12, funct3);
        break;
      }

      case 0x63: { // Tipo-B BRANCHES (BEQ, BNE, BLT, etc.)
        this.funct3 = (instruction >> 12) & 0x7;
        tipoB(funct3);
        break;
      }

      case 0x23: { // Tipo-S STORES (SB, SH, SW)
        this.funct3 = (instruction >> 12) & 0x7;
        tipoS(funct3);
        break;
      }

      case 0x33: { // TIPO-R ARITMÉTICO/LÓGICO (ADD, SUB, etc.)
        this.funct3 = (instruction >> 12) & 0x7;
        int funct7 = (instruction >> 25) & 0x7F;
        tipoR(funct3, funct7);
        break;
      }

      default:
        throw Exception("Opcode Desconhecido ou Instrução Inválida: ${instruction.toRadixString(16)}");
    }
  }   

  void tipoR_CMOV() {
    // Copia rs1 para rd somente se rs2 != 0
    print("CMOV");
    regWrite  = true;       // Intenção de gravar no rd (filtrada pela condição na CPU)
    isCmov    = true;       // Avisa a CPU para checar se rs2 != 0 antes de gravar
    resultSrc = RESULT_RS1; // MUX de Write-Back seleciona o valor de rs1 direto
  }

  void tipoU_LUI() {
    // Carrega um imediato de 20 bits na parte superior de rd
    print("LUI");
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_IMM; // MUX de Write-Back seleciona o imediato puro do ImmGen
  }

  void tipoU_AUIPC() {
    // Soma o imediato de 20 bits ao PC e salva em rd
    print("AUIPC");
    ulaSrcA = true;         // Entrada A da ULA recebe o PC (em vez de rs1)
    ulaSrcB = true;         // Entrada B da ULA recebe o imediato
    regWrite = true;        // Libera gravação no rd
    ulaOp = Ula.OP_ADD;     // ULA calcula PC + imm
    resultSrc = RESULT_ULA; // MUX de Write-Back seleciona o resultado da ULA
  }

  void tipoJ() {
    // Salta para PC + imm e salva PC + 4 em rd
    print("JAL");
    jump = true;            // Salto incondicional (novo PC será PC + imm)
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_PC4; // MUX de Write-Back seleciona PC + 4
  }

  void tipoI_JALR(int funct3) {
    switch (funct3) {
      case 0x00: {
        // Salta para (rs1 + imm) & ~1 e salva PC + 4 em rd
        print("JALR");
        jump = true;            // Salto incondicional
        isJalr = true;          // Avisa a CPU que o novo PC vem da ULA, não de PC + imm
        ulaSrcB = true;         // Entrada B da ULA recebe o imediato (Entrada A já é rs1)
        ulaOp = Ula.OP_ADD;     // ULA calcula rs1 + imm
        regWrite = true;        // Libera gravação no rd
        resultSrc = RESULT_PC4; // MUX de Write-Back seleciona PC + 4
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I JALR: $funct3");
    }
  }
  
  void tipoI_LOADS(int funct3) {
    ulaSrcB = true;         // Entrada B da ULA recebe o imediato (calcula endereço: rs1 + imm)
    ulaOp = Ula.OP_ADD;     // ULA soma base + deslocamento
    memRead = true;         // Libera leitura da Memória RAM
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_MEM; // MUX de Write-Back seleciona o dado vindo da RAM

    // switch opcional, implementação do mesmo em: Barramento metodo read
    switch (funct3) {
      case 0x0: {
        // Lê 1 byte da RAM com extensão de sinal e salva em rd
        print("LB");
        break;
      }

      case 0x1: {
        // Lê 2 bytes da RAM com extensão de sinal e salva em rd
        print("LH");
        break;
      }

      case 0x2: {
        // Lê 4 bytes (word) da RAM e salva em rd
        print("LW");
        break;
      }

      case 0x4: {
        // Lê 1 byte da RAM sem sinal (zero-extended) e salva em rd
        print("LBU");
        break;
      }

      case 0x5: {
        // Lê 2 bytes da RAM sem sinal (zero-extended) e salva em rd
        print("LHU");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Loads: $funct3");
    }
  }

  void tipoI_ARITHMETIC_LOGIC(int funct7, int funct3) {
    ulaSrcB = true;         // Entrada B da ULA recebe o imediato (Entrada A já é rs1)
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_ULA; // MUX de Write-Back seleciona o resultado da ULA

    switch (funct3) {
      case 0x0: {
        // Soma rs1 com imediato e salva em rd
        print("ADDI");
        ulaOp = Ula.OP_ADD; // ULA calcula rs1 + imm
        break;
      }

      case 0x1: {
        // Desloca rs1 à esquerda pelos 5 bits inferiores do imediato
        print("SLLI");
        ulaOp = Ula.OP_SLL; // ULA calcula rs1 << (imm & 0x1F)
        break;
      }

      case 0x2: {
        // Compara rs1 < imediato (com sinal) e salva 1 ou 0 em rd
        print("SLTI");
        ulaOp = Ula.OP_SLT; // ULA compara com sinal
        break;
      }

      case 0x3: {
        // Compara rs1 < imediato (sem sinal) e salva 1 ou 0 em rd
        print("SLTIU");
        ulaOp = Ula.OP_SLTU; // ULA compara sem sinal
        break;
      }

      case 0x4: {
        // XOR bit a bit entre rs1 e imediato
        print("XORI");
        ulaOp = Ula.OP_XOR; // ULA calcula rs1 ^ imm
        break;
      }

      case 0x5: {
        if (funct7 == 0x00) {
          // Deslocamento lógico à direita (preenche com 0)
          print("SRLI");
          ulaOp = Ula.OP_SRL; // ULA calcula rs1 >>> (imm & 0x1F)
          break;
        } else if (funct7 == 0x20) {
          // Deslocamento aritmético à direita (mantém sinal)
          print("SRAI");
          ulaOp = Ula.OP_SRA; // ULA calcula rs1 >> (imm & 0x1F)
          break;
        }

        throw Exception("Instrução de shift inválida. Funct7_imm incorreto: 0x${funct7.toRadixString(16)}");
      }

      case 0x6: {
        // OR bit a bit entre rs1 e imediato
        print("ORI");
        ulaOp = Ula.OP_OR; // ULA calcula rs1 | imm
        break;
      }

      case 0x7: {
        // AND bit a bit entre rs1 e imediato
        print("ANDI");
        ulaOp = Ula.OP_AND; // ULA calcula rs1 & imm
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Aritmético: $funct3");
    }
  }

  void tipoI_FENCE(int funct3) {
    // Em um emulador single-cycle/single-core, FENCE atua como NOP (nenhum sinal ativado)
    switch (funct3) {
      case 0x0: {
        // Sincroniza acessos à memória (NOP em single-core)
        print("FENCE");
        break;
      }

      case 0x1: {
        // Sincroniza cache de instruções (NOP em single-core)
        print("FENCE.I");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Fence: $funct3");
    }
  }

  void tipoI_EVERINMENT_CSR(int funct12, int funct3) {
    // Sinais permanecem desligados até que um banco de registradores CSR/Syscalls seja implementado
    switch (funct3) {
      case 0x00: {
        if (funct12 == 0x000) {
          // Chamada de sistema ao ambiente (OS/Syscall)
          print("ECALL");
          break;
        } else if (funct12 == 0x001) {
          // Pausa a execução para o depurador (breakpoint)
          print("EBREAK");
          break;
        }

        throw Exception("Instrução de ambiente inválida. funct12 incorreto: 0x${funct12.toRadixString(16)}");
      }

      case 0x01: {
        // Lê CSR para rd e grava rs1 no CSR
        print("CSRRW");
        break;
      }

      case 0x02: {
        // Lê CSR para rd e ativa bits usando máscara de rs1
        print("CSRRS");
        break;
      }

      case 0x03: {
        // Lê CSR para rd e limpa bits usando máscara de rs1
        print("CSRRC");
        break;
      }

      case 0x05: {
        // Lê CSR para rd e grava imediato de 5 bits no CSR
        print("CSRRWI");
        break;
      }

      case 0x06: {
        // Lê CSR para rd e ativa bits usando imediato de 5 bits
        print("CSRRSI");
        break;
      }

      case 0x07: {
        // Lê CSR para rd e limpa bits usando imediato de 5 bits
        print("CSRRCI");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Environment/CSR: $funct3");
    }
  }

  void tipoB(int funct3) {
    branch = true;    // Habilita salto condicional (CPU avalia o resultado da ULA + funct3)
    ulaSrcB = false;  // Entrada B da ULA recebe rs2 (compara rs1 com rs2)
    regWrite = false; // Branches não gravam em registradores

    switch (funct3) {
      case 0x0: {
        // Salta para PC + imm se rs1 == rs2
        print("BEQ");
        ulaOp = Ula.OP_SUB; // ULA calcula rs1 - rs2 (bitflag == true se forem iguais)
        break;
      }

      case 0x1: {
        // Salta para PC + imm se rs1 != rs2
        print("BNE");
        ulaOp = Ula.OP_SUB; // ULA calcula rs1 - rs2 (bitflag == false se forem diferentes)
        break;
      }

      case 0x4: {
        // Salta para PC + imm se rs1 < rs2 (com sinal)
        print("BLT");
        ulaOp = Ula.OP_SLT; // ULA retorna 1 se rs1 < rs2
        break;
      }

      case 0x5: {
        // Salta para PC + imm se rs1 >= rs2 (com sinal)
        print("BGE");
        ulaOp = Ula.OP_SLT; // ULA retorna 0 se rs1 >= rs2
        break;
      }

      case 0x6: {
        // Salta para PC + imm se rs1 < rs2 (sem sinal)
        print("BLTU");
        ulaOp = Ula.OP_SLTU; // ULA retorna 1 se rs1 < rs2 (unsigned)
        break;
      }

      case 0x7: {
        // Salta para PC + imm se rs1 >= rs2 (sem sinal)
        print("BGEU");
        ulaOp = Ula.OP_SLTU; // ULA retorna 0 se rs1 >= rs2 (unsigned)
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-B (Branches): $funct3");
    }
  }

  void tipoS(int funct3) {
    ulaSrcB = true;     // Entrada B da ULA recebe o imediato (calcula endereço: rs1 + imm)
    ulaOp = Ula.OP_ADD; // ULA soma base + deslocamento
    memWrite = true;    // Libera escrita na Memória RAM (grava o valor de rs2)
    regWrite = false;   // Stores não gravam no Banco de Registradores

    switch (funct3) {
      case 0x0: {
        // Grava o byte inferior (8 bits) de rs2 na RAM (rs1 + imm)
        print("SB");
        break;
      }

      case 0x1: {
        // Grava a halfword inferior (16 bits) de rs2 na RAM (rs1 + imm)
        print("SH");
        break;
      }

      case 0x2: {
        // Grava a word inteira (32 bits) de rs2 na RAM (rs1 + imm)
        print("SW");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-S: $funct3");
    }
  }

  void tipoR(int funct3, int funct7) {
    ulaSrcB = false;        // Entrada B da ULA recebe rs2 (Entrada A já é rs1)
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_ULA; // MUX de Write-Back seleciona o resultado da ULA

    switch (funct3) {
      case 0x00: {
        if (funct7 == 0x20) {
          // Subtrai rs2 de rs1 e salva em rd
          print("SUB");
          ulaOp = Ula.OP_SUB; // ULA calcula rs1 - rs2
          break;
        } else if (funct7 == 0x00) {
          // Soma rs1 com rs2 e salva em rd
          print("ADD");
          ulaOp = Ula.OP_ADD; // ULA calcula rs1 + rs2
          break;
        }

        throw Exception("funct7 desconhecido ou instrução inválida para Tipo-R: ${funct7.toRadixString(16)}");
      }

      case 0x01: {
        // Desloca rs1 à esquerda pelos 5 bits inferiores de rs2
        print("SLL");
        ulaOp = Ula.OP_SLL; // ULA calcula rs1 << (rs2 & 0x1F)
        break;
      }

      case 0x02: {
        // Compara rs1 < rs2 (com sinal) e salva 1 ou 0 em rd
        print("SLT");
        ulaOp = Ula.OP_SLT; // ULA compara com sinal
        break;
      }

      case 0x03: {
        // Compara rs1 < rs2 (sem sinal) e salva 1 ou 0 em rd
        print("SLTU");
        ulaOp = Ula.OP_SLTU; // ULA compara sem sinal
        break;
      }

      case 0x04: {
        // XOR bit a bit entre rs1 e rs2
        print("XOR");
        ulaOp = Ula.OP_XOR; // ULA calcula rs1 ^ rs2
        break;
      }

      case 0x05: {
        if (funct7 == 0x20) {
          // Deslocamento aritmético à direita (mantém sinal)
          print("SRA");
          ulaOp = Ula.OP_SRA; // ULA calcula rs1 >> (rs2 & 0x1F)
          break;
        } else if (funct7 == 0x00) {
          // Deslocamento lógico à direita (preenche com 0)
          print("SRL");
          ulaOp = Ula.OP_SRL; // ULA calcula rs1 >>> (rs2 & 0x1F)
          break;
        }
        throw Exception("funct7 desconhecido ou instrução inválida para Tipo-R: ${funct7.toRadixString(16)}");
      }

      case 0x06: {
        // OR bit a bit entre rs1 e rs2
        print("OR");
        ulaOp = Ula.OP_OR; // ULA calcula rs1 | rs2
        break;
      }

      case 0x07: {
        // AND bit a bit entre rs1 e rs2
        print("AND");
        ulaOp = Ula.OP_AND; // ULA calcula rs1 & rs2
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-R: ${funct3.toRadixString(16)}");
    }
  }
}
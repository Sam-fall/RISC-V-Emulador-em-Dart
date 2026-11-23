import 'Memory.dart';

class Barramento{
  final MemoryRAM ram = MemoryRAM();
  final MemoryVRAM vram = MemoryVRAM();
  final MemoryExpansao memExpansao = MemoryExpansao();
  final MemoryIO memIO = MemoryIO();

  int barramentoEnderecos = 0; // 32 bits: endereço alvo
  int barramentoDados = 0;     // 32 bits: dado trafegando (leitura/escrita)

  // Barramento de Controle
  bool sinalLeitura = false;     // MemRead
  bool sinalEscrita = false;     // MemWrite

  // Decodificar endereço  
  int _readByte(int endereco) {
    if (endereco >= 0x00000 && endereco <= 0x7FFFF) {
      return ram.read(endereco);
    } else if (endereco >= 0x80000 && endereco <= 0x8FFFF) {
      return vram.read(endereco);
    } else if (endereco >= 0x90000 && endereco <= 0x9FBFF) {
      return memExpansao.read(endereco);
    } else if (endereco >= 0x9FC00 && endereco <= 0x9FFFF) {
      return memIO.read(endereco);
    } else {
      throw Exception("Erro no barramento (Leitura): Endereço fora da memoria: 0x${endereco.toRadixString(16)}");
    }
  }

  void _writeByte(int endereco, int valor) {
    int byte = valor & 0xFF; // Garante 8 bits

    if (endereco >= 0x00000 && endereco <= 0x7FFFF) {
      ram.write(endereco, byte);
    } else if (endereco >= 0x80000 && endereco <= 0x8FFFF) {
      vram.write(endereco, byte);
    } else if (endereco >= 0x90000 && endereco <= 0x9FBFF) {
      memExpansao.write(endereco, byte);
    } else if (endereco >= 0x9FC00 && endereco <= 0x9FFFF) {
      memIO.write(endereco, byte);
    } else {
      throw Exception("Erro no barramento (Escrita): Endereço fora da memoria: 0x${endereco.toRadixString(16)}");
    }
  }

  // Interface de leitura e escrita da CPU (Little Endian)
  // Executa leitura (LB, LH, LW, LBU, LHU) atualizando os barramentos
  int read(int endereco, int funct3) {
    barramentoEnderecos = endereco.toUnsigned(32);
    sinalLeitura = true;
    sinalEscrita = false;

    int resultado = 0;

    switch (funct3) {
      case 0x0: // lb (1 byte com sinal)
        resultado = _readByte(endereco).toSigned(8);
        break;

      case 0x1: // lh (2 bytes com sinal - Little Endian)
        int b0 = _readByte(endereco);
        int b1 = _readByte(endereco + 1);
        resultado = (b0 | (b1 << 8)).toSigned(16);
        break;

      case 0x2: // lw (4 bytes - Little Endian)
        int b0 = _readByte(endereco);
        int b1 = _readByte(endereco + 1);
        int b2 = _readByte(endereco + 2);
        int b3 = _readByte(endereco + 3);
        resultado = (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)).toSigned(32);
        break;

      case 0x4: // lbu (1 byte sem sinal)
        resultado = _readByte(endereco);
        break;

      case 0x5: // lhu (2 bytes sem sinal - Little Endian)
        int b0 = _readByte(endereco);
        int b1 = _readByte(endereco + 1);
        resultado = b0 | (b1 << 8);
        break;

      default:
        sinalLeitura = false;
        throw Exception("Erro no barramento (Leitura): funct3 inválido para leitura: 0x${funct3.toRadixString(16)}");
    }

    barramentoDados = resultado;
    sinalLeitura = false;
    return resultado;
  }

  // Executa escrita (SB, SH, SW) atualizando os barramentos
  void write(int endereco, int valor, int funct3) {
    barramentoEnderecos = endereco.toUnsigned(32);
    barramentoDados = valor.toSigned(32);
    sinalLeitura = false;
    sinalEscrita = true;

    switch (funct3) {
      case 0x0: // sb (1 byte)
        _writeByte(endereco, valor);
        break;

      case 0x1: // sh (2 bytes - Little Endian)
        _writeByte(endereco, valor);
        _writeByte(endereco + 1, valor >> 8);
        break;

      case 0x2: // sw (4 bytes - Little Endian)
        _writeByte(endereco, valor);
        _writeByte(endereco + 1, valor >> 8);
        _writeByte(endereco + 2, valor >> 16);
        _writeByte(endereco + 3, valor >> 24);
        break;

      default:
        sinalEscrita = false;
        throw Exception("Erro no barramento (Escrita): funct3 inválido para escrita: 0x${funct3.toRadixString(16)}");
    }

    sinalEscrita = false;
  }

  // Busca de instrução de 32 bits (Fetch) no endereço apontado pelo PC
  int lerInstrucao(int pc) {
    return read(pc, 0x2);
  }

  // Carrega uma lista de instruções (32 bits) na RAM a partir do endereço 0x00000
  void carregarPrograma(List<int> instrucoes, {int enderecoInicial = 0x00000}) {
    for (int i = 0; i < instrucoes.length; i++) {
      write(enderecoInicial + (i * 4), instrucoes[i], 0x2);
    }
  }

  // E/S Programada: imprime no terminal os caracteres ASCII gravados na VRAM
  void imprimirVRAM({int limiteBytes = 256}) {
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < limiteBytes; i++) {
      int byte = vram.read(0x80000 + i);
      if (byte == 0) continue; // Ignora posições vazias (NUL)
      buffer.writeCharCode(byte);
    }

    if (buffer.isNotEmpty) {
      print("SAÍDA VRAM (ASCII)");
      print(buffer.toString());
      print("--------------------------");
    }
  }

  
}
import 'dart:typed_data';

class MemoryRAM {
  
  static const int tamanho_MemoriaRAM = 0x80000;
  final Uint8List _memoriaRam = Uint8List(tamanho_MemoriaRAM);

  int read(int endereco) {
    if(endereco < 0 || endereco >= tamanho_MemoriaRAM) {
      throw Exception("Tentativa de ler endereço inválido: 0x${endereco.toRadixString(16)}");
    } else {
      return _memoriaRam[endereco];
    }
  }

  void write(int endereco, int valor) {
    if(endereco < 0 || endereco >= tamanho_MemoriaRAM) {
      throw Exception("Tentativa de escrever endereço inválido: 0x${endereco.toRadixString(16)}");
    } else {
      _memoriaRam[endereco] = valor;
    }
  }

}

class MemoryVRAM {
  static const int tamanho_MemoriaVRAM = 0x10000;
  final Uint8List _memoriaVram = Uint8List(tamanho_MemoriaVRAM);

  int read(int endereco) {
    int idx = endereco - 0x80000;

    if(idx < 0 || idx >= tamanho_MemoriaVRAM) {
      throw Exception("Tentativa de ler endereço inválido: 0x${endereco.toRadixString(16)}");
    } else {
      return _memoriaVram[idx];
    }
  }

  void write(int endereco, int valor) {
    int idx = endereco - 0x80000;

    if(idx < 0 || idx >= tamanho_MemoriaVRAM) {
      throw Exception("Tentativa de escrever endereço inválido: 0x${endereco.toRadixString(16)}");
    } else {
      _memoriaVram[idx] = valor;
    }
  }
}

class MemoryExpansao {
  static const int tamanho_MemoriaExpansao = 0xFC00;
  final Uint8List _memoriaExpansao = Uint8List(tamanho_MemoriaExpansao);

  int read(int endereco) {
    int idx = endereco - 0x90000;

    if(idx < 0 || idx >= tamanho_MemoriaExpansao) {
      throw Exception("Tentativa de ler endereço inválido: 0x${endereco.toRadixString(16)}");
    } else {
      return _memoriaExpansao[idx];
    }
  }

  void write(int endereco, int valor) {
    int idx = endereco - 0x90000;

    if(idx < 0 || idx >= tamanho_MemoriaExpansao) {
      throw Exception("Tentativa de escrever endereço inválido: 0x${endereco.toRadixString(16)}");
    } else {
      _memoriaExpansao[idx] = valor;
    }
  }
}

class MemoryIO {
  static const int tamanho_MemoriaIO = 0x400;
  final Uint8List _memoriaIO = Uint8List(tamanho_MemoriaIO);

  int read(int endereco) {
    int idx = endereco - 0x9FC00;

    if(idx < 0 || idx >= tamanho_MemoriaIO) {
      throw Exception("Tentativa de ler endereço inválido: 0x${endereco.toRadixString(16)}");
    } else {
      return _memoriaIO[idx];
    }
  }

  void write(int endereco, int valor) {
    int idx = endereco - 0x9FC00;

    if(idx < 0 || idx >= tamanho_MemoriaIO) {
      throw Exception("Tentativa de escrever endereço inválido: 0x${endereco.toRadixString(16)}");
    } else {
      _memoriaIO[idx] = valor;
    }
  }
}
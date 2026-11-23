import 'dart:typed_data';

class Register {
  final Int32List _registradores = Int32List(32);

  int read(int endereco) {
    if(endereco < 0 || endereco > 31){
      throw Exception("Tentativa de ler registrador inválido: x$endereco");
    } else {
      return _registradores[endereco];
    }
  }

  void write(int endereco, int valor) {
    if (endereco < 0 || endereco > 31) {
      throw Exception("Tentativa de escrever em registrador inválido: x$endereco");
    }
    if (endereco != 0) {
      _registradores[endereco] = valor;
  }
}

}

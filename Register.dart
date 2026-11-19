import 'dart:typed_data';

class Register() {
  final Int32List _registradores = Int32List(32);

  int read(int endereco) {
    if(endereco < 0 || endereco > 31){
      throw Exception("Tentativa de ler registrador inválido: x$endereco");
    } else {
      return _registradores[endereco];
    }
  }

  void write(int endereco, int valor){
    if(endereco < 0 || endereco > 31){
      throw Exception("Tentativa de escrever em registrador inválido: x$endereco");
    } else if(endereco !=0) {
      _registradores[endereco] = valor;
    } else throw Exception("Tentativa de escrever no registrador x0-zero");
  }

}

void main(List<String> args) {
  var reg = Register();
  reg.write(2, 11);
  print(reg.read(2));
}

/// Em qual prateleira o livro está.
enum ReadingStatus {
  wantToRead('Quero ler'),
  reading('Lendo'),
  read('Lido');

  const ReadingStatus(this.label);

  final String label;
}

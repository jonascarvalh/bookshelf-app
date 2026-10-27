import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_response_dto.freezed.dart';
part 'search_response_dto.g.dart';

/// Resposta de `GET /search.json`.
@freezed
abstract class SearchResponseDto with _$SearchResponseDto {
  const factory SearchResponseDto({
    @JsonKey(name: 'numFound') @Default(0) int numFound,
    @Default(0) int start,
    @Default(<SearchDocDto>[]) List<SearchDocDto> docs,
  }) = _SearchResponseDto;

  factory SearchResponseDto.fromJson(Map<String, dynamic> json) =>
      _$SearchResponseDtoFromJson(json);
}

/// Um documento do índice de busca da Open Library.
@freezed
abstract class SearchDocDto with _$SearchDocDto {
  const factory SearchDocDto({
    /// Ex.: `/works/OL1003040W`.
    required String key,
    required String title,
    @JsonKey(name: 'author_name') @Default(<String>[]) List<String> authorNames,
    @JsonKey(name: 'cover_i') int? coverId,
    @JsonKey(name: 'first_publish_year') int? firstPublishYear,
    @JsonKey(name: 'number_of_pages_median') int? pageCount,
    @JsonKey(name: 'isbn') @Default(<String>[]) List<String> isbns,
    @JsonKey(name: 'subject') @Default(<String>[]) List<String> subjects,
  }) = _SearchDocDto;

  const SearchDocDto._();

  factory SearchDocDto.fromJson(Map<String, dynamic> json) => _$SearchDocDtoFromJson(json);

  /// Campos pedidos à API, para não baixar o documento inteiro.
  static const fields =
      'key,title,author_name,cover_i,first_publish_year,number_of_pages_median,isbn,subject';

  Book toEntity() => Book(
    id: workIdFromKey(key),
    title: title.trim(),
    // A API às vezes repete o autor com grafias diferentes.
    authors: {for (final a in authorNames) a.trim()}.toList(),
    coverId: coverId,
    firstPublishYear: firstPublishYear,
    pageCount: pageCount,
    isbns: isbns,
    subjects: subjects.take(8).toList(),
  );
}

/// `/works/OL1003040W` → `OL1003040W`.
String workIdFromKey(String key) => key.split('/').last;

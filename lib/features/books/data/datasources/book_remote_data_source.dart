import 'package:book_app/core/error/exceptions.dart';
import 'package:book_app/core/network/dio_factory.dart';
import 'package:book_app/features/books/data/models/search_response_dto.dart';
import 'package:book_app/features/books/data/models/work_dto.dart';
import 'package:book_app/features/books/domain/entities/search_page.dart';
import 'package:dio/dio.dart';

abstract interface class BookRemoteDataSource {
  Future<SearchResponseDto> search(String query, {required int page});

  /// Retorna `null` quando o ISBN não está catalogado.
  Future<SearchDocDto?> findByIsbn(String isbn);

  Future<WorkDto> getWork(String id);
}

/// Cliente da API pública da Open Library (sem chave, sem cadastro).
class OpenLibraryRemoteDataSource implements BookRemoteDataSource {
  OpenLibraryRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<SearchResponseDto> search(String query, {required int page}) {
    return _get(
      '/search.json',
      {
        'q': query,
        'page': page,
        'limit': SearchPage.pageSize,
        'fields': SearchDocDto.fields,
      },
      SearchResponseDto.fromJson,
    );
  }

  @override
  Future<SearchDocDto?> findByIsbn(String isbn) async {
    final response = await _get(
      '/search.json',
      {'isbn': isbn, 'limit': 1, 'fields': SearchDocDto.fields},
      SearchResponseDto.fromJson,
    );
    return response.docs.firstOrNull;
  }

  @override
  Future<WorkDto> getWork(String id) => _get('/works/$id.json', null, WorkDto.fromJson);

  Future<T> _get<T>(
    String path,
    Map<String, Object?>? query,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      final data = response.data;
      if (data == null) throw const ApiException(ApiErrorKind.invalidResponse);
      return parse(data);
    } on DioException catch (e) {
      throw DioFactory.mapError(e);
    } on TypeError {
      // JSON com formato diferente do esperado.
      throw const ApiException(ApiErrorKind.invalidResponse);
    } on FormatException {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
  }
}

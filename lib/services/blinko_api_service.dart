import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutterclaw/services/blinko_auth_service.dart';

class BlinkoNote {
  const BlinkoNote({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    required this.isRecycle,
    required this.isTop,
    required this.tags,
    required this.attachmentCount,
    required this.commentCount,
  });

  final int id;
  final int type;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isArchived;
  final bool isRecycle;
  final bool isTop;
  final List<String> tags;
  final int attachmentCount;
  final int commentCount;

  factory BlinkoNote.fromJson(Map<String, dynamic> json) {
    final tagsJson = json['tags'];
    final tags = <String>[];
    if (tagsJson is List) {
      for (final item in tagsJson) {
        if (item is String && item.isNotEmpty) {
          tags.add(item);
        } else if (item is Map<String, dynamic>) {
          final tag = item['tag'];
          if (tag is Map<String, dynamic>) {
            final name = tag['name']?.toString();
            if (name != null && name.isNotEmpty) tags.add(name);
          } else {
            final name = item['name']?.toString();
            if (name != null && name.isNotEmpty) tags.add(name);
          }
        }
      }
    }

    final attachments = json['attachments'];
    final count = json['_count'];

    return BlinkoNote(
      id: _asInt(json['id']),
      type: _asInt(json['type']),
      content: json['content']?.toString() ?? '',
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
      isArchived: json['isArchived'] == true,
      isRecycle: json['isRecycle'] == true,
      isTop: json['isTop'] == true,
      tags: tags,
      attachmentCount: attachments is List
          ? attachments.length
          : count is Map<String, dynamic>
          ? _asInt(count['attachments'])
          : 0,
      commentCount: count is Map<String, dynamic>
          ? _asInt(count['comments'])
          : 0,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      final milliseconds = value > 9999999999 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    if (value is num) {
      final integer = value.toInt();
      final milliseconds = integer > 9999999999 ? integer : integer * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return DateTime.tryParse(value.toString());
  }
}

class BlinkoTag {
  const BlinkoTag({
    required this.id,
    required this.name,
    required this.icon,
    required this.parent,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String icon;
  final int parent;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BlinkoTag.fromJson(Map<String, dynamic> json) {
    return BlinkoTag(
      id: BlinkoNote._asInt(json['id']),
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      parent: BlinkoNote._asInt(json['parent']),
      sortOrder: BlinkoNote._asInt(json['sortOrder']),
      createdAt: BlinkoNote._asDateTime(json['createdAt']),
      updatedAt: BlinkoNote._asDateTime(json['updatedAt']),
    );
  }
}

class BlinkoNoteListQuery {
  const BlinkoNoteListQuery({
    this.page = 1,
    this.size = 30,
    this.searchText = '',
    this.orderBy = 'desc',
    this.type = -1,
    this.isArchived = false,
    this.isRecycle = false,
    this.withFile = false,
    this.withLink = false,
    this.hasTodo = false,
  });

  final int page;
  final int size;
  final String searchText;
  final String orderBy;
  final int type;
  final bool? isArchived;
  final bool isRecycle;
  final bool withFile;
  final bool withLink;
  final bool hasTodo;

  Map<String, dynamic> toJson() => {
    'tagId': null,
    'page': page,
    'size': size,
    'orderBy': orderBy,
    'type': type,
    'isArchived': isArchived,
    'isShare': null,
    'isRecycle': isRecycle,
    'searchText': searchText,
    'withoutTag': false,
    'withFile': withFile,
    'withLink': withLink,
    'isUseAiQuery': false,
    'startDate': null,
    'endDate': null,
    'hasTodo': hasTodo,
  };
}

class BlinkoNoteUpsertRequest {
  const BlinkoNoteUpsertRequest({
    this.id,
    required this.content,
    this.type = -1,
    this.isArchived,
    this.isTop,
    this.isShare,
    this.isRecycle,
    this.references = const [],
    this.attachments = const [],
    this.metadata,
  });

  final int? id;
  final String content;
  final int type;
  final bool? isArchived;
  final bool? isTop;
  final bool? isShare;
  final bool? isRecycle;
  final List<int> references;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
    'content': content,
    'type': type,
    'attachments': attachments,
    if (id != null) 'id': id,
    if (isArchived != null) 'isArchived': isArchived,
    if (isTop != null) 'isTop': isTop,
    if (isShare != null) 'isShare': isShare,
    if (isRecycle != null) 'isRecycle': isRecycle,
    if (references.isNotEmpty) 'references': references,
    if (metadata != null) 'metadata': metadata,
  };
}

class BlinkoApiService {
  BlinkoApiService({Dio? dio, required String baseUrl, required String token})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      _baseUrl = BlinkoAuthService.normalizeBaseUrl(baseUrl),
      _token = token;

  final Dio _dio;
  final String _baseUrl;
  final String _token;

  Future<List<BlinkoNote>> listNotes(BlinkoNoteListQuery query) async {
    final body = await _post('/v1/note/list', query.toJson());

    final rawList = _extractList(body);
    if (rawList == null) {
      throw const BlinkoApiException('Note list response format is invalid');
    }

    return [
      for (final item in rawList)
        if (item is Map<String, dynamic>) BlinkoNote.fromJson(item),
    ];
  }

  Future<BlinkoNote?> noteDetail(int id) async {
    final body = await _post('/v1/note/detail', {'id': id});
    if (body == null) return null;
    if (body is Map<String, dynamic>) return BlinkoNote.fromJson(body);
    throw const BlinkoApiException('Note detail response format is invalid');
  }

  Future<void> upsertNote(BlinkoNoteUpsertRequest request) async {
    await _post('/v1/note/upsert', request.toJson());
  }

  Future<void> trashNotes(List<int> ids) async {
    if (ids.isEmpty) return;
    await _post('/v1/note/batch-trash', {'ids': ids});
  }

  Future<void> deleteNotes(List<int> ids) async {
    if (ids.isEmpty) return;
    await _post('/v1/note/batch-delete', {'ids': ids});
  }

  Future<List<BlinkoTag>> listTags() async {
    final body = await _get('/v1/tags/list');
    final rawList = _extractList(body);
    if (rawList == null) {
      throw const BlinkoApiException('Tag list response format is invalid');
    }
    return [
      for (final item in rawList)
        if (item is Map<String, dynamic>) BlinkoTag.fromJson(item),
    ];
  }

  Future<dynamic> _get(String path) async {
    final url = _url(path);
    if (kDebugMode) {
      debugPrint('[BlinkoApi] GET $url');
    }

    final Response<dynamic> response;
    try {
      response = await _dio.get(
        url,
        options: Options(headers: _headers(), validateStatus: (_) => true),
      );
    } on DioException catch (e) {
      throw BlinkoApiException(_formatDioError(e, url));
    }

    return _parseResponse(response, url);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final url = _url(path);
    if (kDebugMode) {
      debugPrint('[BlinkoApi] POST $url');
      debugPrint('[BlinkoApi] request: $data');
    }

    final Response<dynamic> response;
    try {
      response = await _dio.post(
        url,
        data: data,
        options: Options(headers: _headers(), validateStatus: (_) => true),
      );
    } on DioException catch (e) {
      throw BlinkoApiException(_formatDioError(e, url));
    }

    return _parseResponse(response, url);
  }

  dynamic _parseResponse(Response<dynamic> response, String url) {
    final status = response.statusCode ?? 0;
    final body = response.data;
    if (kDebugMode) {
      debugPrint('[BlinkoApi] response status: $status');
      debugPrint('[BlinkoApi] response body: $body');
    }

    if (status < 200 || status >= 300) {
      final message = body is Map<String, dynamic>
          ? (body['message'] ?? body['error'] ?? 'Request failed')
          : 'Request failed';
      throw BlinkoApiException('$message (HTTP $status)');
    }

    return body;
  }

  String _url(String path) => '$_baseUrl/api$path';

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  List<dynamic>? _extractList(dynamic body) {
    if (body is List<dynamic>) return body;
    if (body is! Map<String, dynamic>) return null;

    for (final key in const ['items', 'list', 'notes', 'records', 'rows']) {
      final value = body[key];
      if (value is List<dynamic>) return value;
    }

    for (final key in const ['data', 'result', 'response']) {
      final value = body[key];
      if (value is List<dynamic>) return value;
      if (value is Map<String, dynamic>) {
        final nested = _extractList(value);
        if (nested != null) return nested;
      }
    }

    return null;
  }

  String _formatDioError(DioException e, String url) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final statusText = status == null ? '' : ' HTTP $status.';
    final bodyText = body == null ? '' : ' Response: $body';
    return 'Request failed: ${e.message ?? e.type.name}.$statusText URL: $url.$bodyText';
  }
}

class BlinkoApiException implements Exception {
  const BlinkoApiException(this.message);

  final String message;

  @override
  String toString() => 'BlinkoApiException: $message';
}

import 'dart:convert';

import 'package:drift_odoo/src/odoo_client.dart';
import 'package:drift_odoo/src/odoo_exception.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

// ── Stub ──────────────────────────────────────────────────────────────────────

class _CaptureClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final http.Response Function(http.BaseRequest) handler;
  _CaptureClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final r = handler(request);
    return http.StreamedResponse(
      Stream.value(r.bodyBytes),
      r.statusCode,
      headers: r.headers,
    );
  }
}

http.Response _json(dynamic body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  late _CaptureClient httpStub;
  late OdooClient client;

  setUp(() {
    httpStub = _CaptureClient((_) => _json(null));
    client = OdooClient(
      baseUrl: 'https://demo.odoo.com',
      apiKey: 'secret',
      httpClient: httpStub,
    );
  });

  group('request shape', () {
    test('searchRead posts to correct URL with Bearer token', () async {
      httpStub = _CaptureClient(
          (_) => _json([{'id': 1, 'name': 'Alice', 'write_date': '2026-01-01 00:00:00'}]));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      await client.searchRead('res.partner', fields: ['name', 'write_date']);

      expect(httpStub.requests, hasLength(1));
      final req = httpStub.requests.first as http.Request;
      expect(req.url.toString(), 'https://demo.odoo.com/json/2/res.partner/search_read');
      expect(req.headers['Authorization'], 'Bearer secret');
      expect(req.headers['Content-Type'], 'application/json');
    });

    test('searchRead sends domain and fields in body', () async {
      httpStub = _CaptureClient((_) => _json([]));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      await client.searchRead(
        'res.partner',
        domain: [
          ['active', '=', true]
        ],
        fields: ['name'],
        limit: 10,
        offset: 5,
        order: 'name asc',
      );

      final body = jsonDecode((httpStub.requests.first as http.Request).body) as Map;
      expect(body['domain'], [
        ['active', '=', true]
      ]);
      expect(body['fields'], ['name']);
      expect(body['limit'], 10);
      expect(body['offset'], 5);
      expect(body['order'], 'name asc');
    });

    test('database header is set when provided', () async {
      httpStub = _CaptureClient((_) => _json([]));
      client = OdooClient(
        baseUrl: 'https://demo.odoo.com',
        apiKey: 'secret',
        database: 'mydb',
        httpClient: httpStub,
      );

      await client.searchRead('res.partner');

      expect(
        (httpStub.requests.first as http.Request).headers['X-Odoo-Database'],
        'mydb',
      );
    });
  });

  group('searchRead', () {
    test('returns parsed records', () async {
      final records = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];
      httpStub = _CaptureClient((_) => _json(records));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      final result = await client.searchRead('res.partner');

      expect(result, hasLength(2));
      expect(result.first['name'], 'Alice');
    });
  });

  group('create', () {
    test('returns list of created IDs', () async {
      httpStub = _CaptureClient((_) => _json([10, 11]));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      final ids = await client.create('res.partner', [
        {'name': 'ACME'},
        {'name': 'Corp'},
      ]);

      expect(ids, [10, 11]);
    });

    test('wraps single int response in list', () async {
      httpStub = _CaptureClient((_) => _json(42));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      final ids = await client.create('res.partner', [{'name': 'Solo'}]);

      expect(ids, [42]);
    });
  });

  group('write', () {
    test('returns true on success', () async {
      httpStub = _CaptureClient((_) => _json(true));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      final ok = await client.write('res.partner', [1], {'name': 'Updated'});

      expect(ok, isTrue);

      final body =
          jsonDecode((httpStub.requests.first as http.Request).body) as Map;
      expect(body['ids'], [1]);
      expect(body['vals'], {'name': 'Updated'});
    });
  });

  group('unlink', () {
    test('returns true on success', () async {
      httpStub = _CaptureClient((_) => _json(true));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      final ok = await client.unlink('res.partner', [5]);

      expect(ok, isTrue);
      final body =
          jsonDecode((httpStub.requests.first as http.Request).body) as Map;
      expect(body['ids'], [5]);
    });
  });

  group('error handling', () {
    test('throws OdooException on 4xx response', () async {
      httpStub = _CaptureClient((_) => _json({'error': 'Forbidden'}, status: 403));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      expect(
        () => client.searchRead('res.partner'),
        throwsA(isA<OdooException>()),
      );
    });

    test('throws OdooException on 5xx response', () async {
      httpStub = _CaptureClient(
          (_) => _json({'error': 'Server Error'}, status: 500));
      client = OdooClient(
          baseUrl: 'https://demo.odoo.com', apiKey: 'secret', httpClient: httpStub);

      expect(
        () => client.searchRead('res.partner'),
        throwsA(isA<OdooException>()),
      );
    });
  });
}

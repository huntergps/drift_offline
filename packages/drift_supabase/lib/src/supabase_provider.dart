import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:logging/logging.dart';
import 'package:supabase/supabase.dart';

import 'supabase_adapter.dart';
import 'supabase_model.dart';
import 'supabase_model_dictionary.dart';

/// Wraps [SupabaseClient] and translates CRUD requests using model adapters.
///
/// Construct via [OfflineFirstWithSupabaseRepository] or directly for testing.
/// The [client] is usually a [SupabaseClient] initialised with a
/// [SupabaseOfflineQueueClient]-wrapped http.Client for offline support.
class SupabaseProvider {
  final SupabaseClient client;
  final SupabaseModelDictionary modelDictionary;

  final Logger _logger;

  SupabaseProvider(
    this.client, {
    required this.modelDictionary,
    String? loggerName,
  }) : _logger = Logger(loggerName ?? 'SupabaseProvider');

  SupabaseAdapter<TModel> _adapterFor<TModel extends SupabaseModel>() {
    final adapter = modelDictionary.adapterFor[TModel];
    if (adapter == null) throw StateError('No adapter registered for $TModel');
    return adapter as SupabaseAdapter<TModel>;
  }

  /// Fetch rows from Supabase for [TModel], optionally filtered by [filter]
  /// and/or a structured [Query].
  ///
  /// [filter] is a callback that receives a [PostgrestFilterBuilder] and can
  /// chain `.eq()`, `.in_()`, `.gt()`, etc. It is applied AFTER any conditions
  /// derived from [query], for backward compatibility and to allow extra filters.
  ///
  /// [query] is a structured [Query] object whose [Query.where] conditions are
  /// automatically translated to PostgREST filter calls. Ordering, limit, and
  /// offset are also applied from the [Query] when present.
  Future<List<TModel>> get<TModel extends SupabaseModel>({
    String? selectQuery,
    PostgrestFilterBuilder Function(PostgrestFilterBuilder)? filter,
    Query? query,
    Object? repository,
  }) async {
    final adapter = _adapterFor<TModel>();
    _logger.finest('#get ${adapter.supabaseTableName}');

    // Determine select query: providerArgs override → explicit param → build from adapter
    final effectiveSelectQuery = query?.providerArgs['selectQuery'] as String?
        ?? selectQuery
        ?? _buildSelectQuery(adapter);

    var baseQuery = client
        .from(adapter.supabaseTableName)
        .select(effectiveSelectQuery);

    PostgrestFilterBuilder filterBuilder = baseQuery;

    // Apply structured Where conditions from Query
    if (query != null && query.hasWhere) {
      filterBuilder = _applyWhereConditions(
        filterBuilder,
        query.where,
        adapter.fieldsToSupabaseColumns,
      );
    }

    // Apply caller-supplied filter callback (backward compat + extra filters)
    if (filter != null) {
      filterBuilder = filter(filterBuilder);
    }

    // Apply ordering from Query
    if (query?.orderBy != null) {
      for (final cond in query!.orderBy!.conditions) {
        final colDef = adapter.fieldsToSupabaseColumns[cond.evaluatedField];
        final column = colDef?.columnName ?? cond.evaluatedField;
        filterBuilder = filterBuilder.order(column, ascending: cond.ascending);
      }
    }

    // Apply limit/offset from Query
    if (query?.limitBy != null) {
      final lb = query!.limitBy!;
      filterBuilder = filterBuilder.limit(lb.amount);
      if ((lb.offset ?? 0) > 0) {
        filterBuilder = filterBuilder.range(lb.offset!, lb.offset! + lb.amount - 1);
      }
    }

    final List<Map<String, dynamic>> rows = await filterBuilder;

    return Future.wait(rows.map(
      (r) => adapter.fromSupabase(r, provider: this, repository: repository),
    ));
  }

  /// Insert or update [instance] in Supabase.
  Future<TModel> upsert<TModel extends SupabaseModel>(
    TModel instance, {
    Object? repository,
  }) async {
    final adapter = _adapterFor<TModel>();

    _logger.finest('#upsert ${adapter.supabaseTableName}');

    final data = await adapter.toSupabase(instance, provider: this, repository: repository);
    final result = await client
        .from(adapter.supabaseTableName)
        .upsert(
          data,
          onConflict: adapter.onConflict,
          ignoreDuplicates: adapter.ignoreDuplicates,
          defaultToNull: adapter.defaultToNull,
        )
        .select(_buildSelectQuery(adapter))
        .single();

    return adapter.fromSupabase(result, provider: this, repository: repository);
  }

  /// Delete [instance] from Supabase using its unique fields.
  Future<void> delete<TModel extends SupabaseModel>(
    TModel instance, {
    Object? repository,
  }) async {
    final adapter = _adapterFor<TModel>();

    _logger.finest('#delete ${adapter.supabaseTableName}');

    final data = await adapter.toSupabase(instance, provider: this, repository: repository);
    var query = client.from(adapter.supabaseTableName).delete();

    PostgrestFilterBuilder filter = query;
    for (final unique in adapter.uniqueFields) {
      final col = adapter.fieldsToSupabaseColumns[unique]?.columnName ?? unique;
      final value = data[col];
      if (value != null) filter = filter.eq(col, value);
    }

    await filter;
  }

  /// Check whether any rows matching [filter] exist.
  Future<bool> exists<TModel extends SupabaseModel>({
    PostgrestFilterBuilder Function(PostgrestFilterBuilder)? filter,
  }) async {
    final adapter = _adapterFor<TModel>();
    var query = client.from(adapter.supabaseTableName).select('id').limit(1);

    PostgrestFilterBuilder filterQuery = query;
    if (filter != null) filterQuery = filter(filterQuery);

    final rows = await filterQuery;
    return (rows as List).isNotEmpty;
  }

  // ---------------------------------------------------------------------------

  /// Translates [Query.where] conditions to PostgREST filter calls.
  ///
  /// Each [Where] condition maps to a PostgREST method:
  /// - [Compare.exact]                → `.eq(column, value)`
  /// - [Compare.notEqual]             → `.neq(column, value)`
  /// - [Compare.contains]             → `.like(column, '%$value%')`
  /// - [Compare.doesNotContain]       → `.not(column, 'like', '%$value%')`
  /// - [Compare.greaterThan]          → `.gt(column, value)`
  /// - [Compare.greaterThanOrEqualTo] → `.gte(column, value)`
  /// - [Compare.lessThan]             → `.lt(column, value)`
  /// - [Compare.lessThanOrEqualTo]    → `.lte(column, value)`
  /// - [Compare.between]              → `.gte(lower).lte(upper)` (value is [lower, upper])
  ///
  /// [WherePhrase] with `isRequired=true` is AND (applied sequentially).
  /// [WherePhrase] with `isRequired=false` is OR (uses `.or(filter_string)`).
  ///
  /// The [fieldsToColumns] map translates Dart field names to Supabase column names.
  PostgrestFilterBuilder _applyWhereConditions(
    PostgrestFilterBuilder builder,
    List<WhereCondition> conditions,
    Map<String, RuntimeSupabaseColumnDefinition> fieldsToColumns,
  ) {
    for (final condition in conditions) {
      if (condition is Where) {
        builder = _applyWhere(builder, condition, fieldsToColumns);
      } else if (condition is WherePhrase) {
        if (condition.isRequired) {
          // AND: apply each sub-condition sequentially
          builder = _applyWhereConditions(
            builder,
            condition.conditions,
            fieldsToColumns,
          );
        } else {
          // OR: build a filter string and pass to .or()
          final orParts = <String>[];
          for (final c in condition.conditions) {
            if (c is Where) {
              final part = _whereToFilterString(c, fieldsToColumns);
              if (part != null) orParts.add(part);
            }
          }
          if (orParts.isNotEmpty) {
            builder = builder.or(orParts.join(','));
          }
        }
      }
    }
    return builder;
  }

  PostgrestFilterBuilder _applyWhere(
    PostgrestFilterBuilder builder,
    Where where,
    Map<String, RuntimeSupabaseColumnDefinition> fieldsToColumns,
  ) {
    final colDef = fieldsToColumns[where.evaluatedField];
    final column = colDef?.columnName ?? where.evaluatedField;
    final value = where.value;

    switch (where.compare) {
      case Compare.exact:
        return builder.eq(column, value);
      case Compare.notEqual:
        return builder.neq(column, value);
      case Compare.contains:
        return builder.like(column, '%$value%');
      case Compare.doesNotContain:
        return builder.not(column, 'like', '%$value%');
      case Compare.greaterThan:
        return builder.gt(column, value);
      case Compare.greaterThanOrEqualTo:
        return builder.gte(column, value);
      case Compare.lessThan:
        return builder.lt(column, value);
      case Compare.lessThanOrEqualTo:
        return builder.lte(column, value);
      case Compare.between:
        final list = value as List;
        return builder.gte(column, list[0]).lte(column, list[1]);
      case Compare.inIterable:
        return builder.in_(column, value as List);
    }
  }

  /// Converts a [Where] condition to a PostgREST filter string for use in `.or()`.
  String? _whereToFilterString(
    Where where,
    Map<String, RuntimeSupabaseColumnDefinition> fieldsToColumns,
  ) {
    final colDef = fieldsToColumns[where.evaluatedField];
    final column = colDef?.columnName ?? where.evaluatedField;
    final value = where.value;

    switch (where.compare) {
      case Compare.exact:
        return '$column.eq.$value';
      case Compare.notEqual:
        return '$column.neq.$value';
      case Compare.contains:
        return '$column.like.%$value%';
      case Compare.greaterThan:
        return '$column.gt.$value';
      case Compare.greaterThanOrEqualTo:
        return '$column.gte.$value';
      case Compare.lessThan:
        return '$column.lt.$value';
      case Compare.lessThanOrEqualTo:
        return '$column.lte.$value';
      case Compare.doesNotContain:
      case Compare.between:
      case Compare.inIterable:
        return null; // Not expressible as simple or() string
    }
  }

  String _buildSelectQuery(SupabaseAdapter adapter, {int depth = 0}) {
    final parts = <String>[];
    for (final entry in adapter.fieldsToSupabaseColumns.entries) {
      final col = entry.value;
      if (col.query != null) {
        // Developer-provided raw query string — use as-is at all depths.
        parts.add(col.query!);
      } else if (col.association) {
        if (depth >= 1) {
          // Stop recursion: include only the FK column, no nested select.
          // This avoids infinite recursion for circular or deep associations.
          final fk = col.foreignKey ?? col.columnName;
          parts.add(fk);
        } else {
          final fk = col.foreignKey != null ? '!${col.foreignKey}' : '';
          parts.add('${col.columnName}$fk(*)');
        }
      } else {
        parts.add(col.columnName);
      }
    }
    return parts.isEmpty ? '*' : parts.join(',');
  }
}

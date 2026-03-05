import 'offline_first_model.dart';

/// Opt-in in-memory L1 cache for frequently-accessed models.
///
/// Sits between the repository and local Drift storage: if a model is cached,
/// the repository returns it immediately without hitting the database.
///
/// Register each type you want cached with [manage], providing a key extractor:
///
/// ```dart
/// final cache = MemoryCacheProvider<OfflineFirstModel>();
/// cache.manage<User>((u) => u.id);
/// cache.manage<Order>((o) => o.orderId);
/// ```
///
/// The repository integrates the cache automatically when
/// `OfflineFirstRepository.memoryCacheProvider` is set.
class MemoryCacheProvider<TModel extends OfflineFirstModel> {
  final Map<Type, Object Function(Object)> _keyExtractors = {};
  final Map<Type, Map<Object, Object>> _cache = {};

  /// Register [T] for caching. [keyExtractor] must return a unique,
  /// comparable key (e.g. the primary key integer or UUID string).
  void manage<T extends TModel>(Object Function(T instance) keyExtractor) {
    _keyExtractors[T] = (obj) => keyExtractor(obj as T);
  }

  /// Returns `true` if [T] is registered for caching.
  bool manages(Type type) => _keyExtractors.containsKey(type);

  /// Returns all cached instances of [T], or `null` if [T] is not managed
  /// or no instances have been cached yet.
  List<T>? getAll<T extends TModel>() {
    if (!manages(T)) return null;
    final entries = _cache[T];
    if (entries == null || entries.isEmpty) return null;
    return entries.values.cast<T>().toList();
  }

  /// Returns a cached instance by [key], or `null` if absent.
  T? getById<T extends TModel>(Object key) {
    return _cache[T]?[key] as T?;
  }

  /// Add or replace [instance] in the cache.
  /// No-op if [T] is not managed.
  void upsert<T extends TModel>(T instance) {
    if (!manages(T)) return;
    final key = _keyExtractors[T]!(instance);
    (_cache[T] ??= {})[key] = instance;
  }

  /// Remove [instance] from the cache.
  /// No-op if [T] is not managed or instance is not cached.
  void delete<T extends TModel>(T instance) {
    if (!manages(T)) return;
    final key = _keyExtractors[T]!(instance);
    _cache[T]?.remove(key);
  }

  /// Remove all cached instances of [T].
  void clear<T extends TModel>() => _cache.remove(T);

  /// Remove ALL cached instances across all managed types.
  void clearAll() => _cache.clear();
}

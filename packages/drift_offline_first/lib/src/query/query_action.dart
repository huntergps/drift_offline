/// Describes the intended operation of a [Query].
///
/// Allows [RestRequestTransformer] and other provider-specific components to
/// behave differently depending on whether they are serving a read, write, or
/// subscription request.
enum QueryAction {
  /// Fetch one or more records.
  get,

  /// Insert a new record (fail if exists).
  insert,

  /// Update an existing record (fail if absent).
  update,

  /// Insert or update (upsert semantics).
  upsert,

  /// Remove a record.
  delete,

  /// Establish a long-lived subscription (e.g. Supabase Realtime).
  subscribe,
}

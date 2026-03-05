/// Commands for One2many and Many2many field manipulation in Odoo.
///
/// Via the JSON-2 API, relational fields accept a list of command tuples:
/// `(command_id, record_id, values)`
///
/// Example:
/// ```dart
/// 'tag_ids': [
///   OdooCommand.link(5),
///   OdooCommand.create({'name': 'New Tag'}),
/// ]
/// ```
abstract class OdooCommand {
  const OdooCommand();

  /// Create a new related record and link it.
  /// Tuple: `(0, 0, values)`
  static List<dynamic> create(Map<String, dynamic> values) => [0, 0, values];

  /// Update an existing related record.
  /// Tuple: `(1, id, values)`
  static List<dynamic> update(int id, Map<String, dynamic> values) => [1, id, values];

  /// Delete a related record from the database.
  /// Tuple: `(2, id, 0)`
  static List<dynamic> delete(int id) => [2, id, 0];

  /// Remove the link to a related record (does NOT delete the record).
  /// Tuple: `(3, id, 0)`
  static List<dynamic> unlink(int id) => [3, id, 0];

  /// Link an existing record without modifying it.
  /// Tuple: `(4, id, 0)`
  static List<dynamic> link(int id) => [4, id, 0];

  /// Remove all links (does NOT delete the records).
  /// Tuple: `(5, 0, 0)`
  static List<dynamic> clear() => [5, 0, 0];

  /// Replace the entire set of linked records.
  /// Tuple: `(6, 0, [ids])`
  static List<dynamic> set(List<int> ids) => [6, 0, ids];
}

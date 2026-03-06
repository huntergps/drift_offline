# CHANGELOG

## 0.1.0

- Initial release.
- `@Odoo` field annotation (name, ignore, ignoreFrom, ignoreTo, enumAsString, fromGenerator, toGenerator).
- `@OdooSerializable` class annotation (odooModel, fieldRename).
- `OdooModel`, `OdooAdapter<T>`, `OdooModelDictionary` interfaces.
- `OdooDomain` typedef + `OdooDomainBuilder` helpers (field, and, or, writtenAfter, includeArchived).
- `OdooOperator` enum with all Odoo comparison operators.

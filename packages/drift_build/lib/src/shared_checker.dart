import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

/// Inspects a [DartType] to determine its characteristics for code generation.
///
/// [TModel] is a phantom type parameter used only for documentation — it does
/// NOT affect runtime behaviour. Actual sibling detection is done via
/// [siblingsChecker], which callers must provide.
class SharedChecker<TModel> {
  final DartType type;

  /// Used to determine if a type is a "sibling" (subtype of the model base).
  final TypeChecker siblingsChecker;

  const SharedChecker(this.type, this.siblingsChecker);

  bool get isNullable => type.nullabilitySuffix != NullabilitySuffix.none;

  /// Unwrap `Future<T>` → `T`. Returns [type] unchanged if not a Future.
  DartType get unFuturedType {
    final t = type;
    if (t is InterfaceType &&
        t.element.name == 'Future' &&
        t.typeArguments.isNotEmpty) {
      return t.typeArguments.first;
    }
    return t;
  }

  bool get isDateTime {
    final t = unFuturedType;
    return t is InterfaceType &&
        t.element.name == 'DateTime' &&
        t.element.library.isDartCore;
  }

  bool get isBool {
    final t = unFuturedType;
    return t is InterfaceType &&
        t.element.name == 'bool' &&
        t.element.library.isDartCore;
  }

  /// True for `int`, `double`, `num`, `String`.
  bool get isDartCoreType {
    final t = unFuturedType;
    if (t is! InterfaceType) return false;
    if (!t.element.library.isDartCore) return false;
    return const {'int', 'double', 'num', 'String'}.contains(t.element.name);
  }

  bool get isEnum {
    final t = unFuturedType;
    return t is InterfaceType && t.element is EnumElement;
  }

  bool get isMap {
    final t = unFuturedType;
    return t is InterfaceType &&
        t.element.name == 'Map' &&
        t.element.library.isDartCore;
  }

  /// True for `List`, `Set`, `Iterable` (but not `Map`).
  bool get isIterable {
    final t = unFuturedType;
    if (t is! InterfaceType) return false;
    if (isMap) return false;
    const names = {'List', 'Set', 'Iterable'};
    if (names.contains(t.element.name) && t.element.library.isDartCore) {
      return true;
    }
    return t.allSupertypes.any(
      (s) => names.contains(s.element.name) && s.element.library.isDartCore,
    );
  }

  /// The first type argument of an `Iterable`/`List`/`Map`, unwrapped from
  /// Future. Returns [unFuturedType] if there are no type arguments.
  DartType get unFuturedArgType {
    final t = unFuturedType;
    if (t is InterfaceType && t.typeArguments.isNotEmpty) {
      return t.typeArguments.first;
    }
    return t;
  }

  /// True when the type itself is a subtype of the model base class.
  bool get isSibling {
    final t = unFuturedType;
    if (t is! InterfaceType) return false;
    return siblingsChecker.isAssignableFrom(t.element);
  }

  /// True when the iterable's type argument is a subtype of the model base.
  bool get isArgTypeASibling {
    final t = unFuturedArgType;
    if (t is! InterfaceType) return false;
    return siblingsChecker.isAssignableFrom(t.element);
  }
}

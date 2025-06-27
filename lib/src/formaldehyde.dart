// ignore_for_file: lines_longer_than_80_chars
/// A library for managing form state, validation, and data parsing in Dart.
///
/// Provides classes and utilities to define form fields, handle input changes,
/// validate data, and parse values into their expected types.
library formaldehyde;

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Represents a form with a set of defined fields, their current values,
/// pending changes, and validation errors.
///
/// `FK` is an enum type that uniquely identifies each field in the form.
///
/// Example:
/// ```dart
/// enum MyFormKeys { name, email, age }
///
/// final nameField = FieldDefinition.string(name: MyFormKeys.name, isRequired: true);
/// final ageField = FieldDefinition.integer(name: MyFormKeys.age);
///
/// var form = Form<MyFormKeys>(fields: {nameField, ageField});
/// form = form.change(field: MyFormKeys.name, value: 'John Doe');
/// form = await form.apply();
///
/// if (form.errors.isEmpty) {
///   print('Valid values: ${form.values}');
/// } else {
///   print('Validation errors: ${form.errors}');
/// }
/// ```
class Form<FK extends Enum> extends Equatable {
  // Ensure error sets are unmodifiable

  /// Creates a new form instance with the given field definitions.
  ///
  /// Initially, the form has no changes, values, or errors.
  ///
  /// - [fields]: A `Set` of [FieldDefinition] objects that define the
  ///   structure, validation rules, and parsing logic for each field.
  Form({
    required Set<FieldDefinition<dynamic, FK>> fields,
  }) : this.internal(
          fields: fields,
          changes: const {},
          values: const {},
          errors: const {},
        );

  /// Internal constructor for creating form instances.
  @visibleForTesting
  Form.internal({
    required Set<FieldDefinition<dynamic, FK>> fields,
    required Map<FK, dynamic> changes,
    required Map<FK, dynamic> values,
    required Map<FK, Set<ValidationError<FK>>> errors,
  })  : assert(
          fields.isNotEmpty,
          'Fields should not be empty,'
          ' a form depends on its fields',
        ),
        _fields = Set.unmodifiable(fields),
        _changes = Map.unmodifiable(changes),
        // Ensure changes are unmodifiable
        _values = Map.unmodifiable(values),
        // Ensure values are unmodifiable
        _errors = Map.unmodifiable(
          errors.map(
            (key, value) => MapEntry(
              key,
              Set.unmodifiable(value),
            ),
          ),
        );

  /// The set of field definitions for this form.
  final Set<FieldDefinition<dynamic, FK>> _fields;

  /// A map of pending changes, where keys are field identifiers (`FK`)
  /// and values are the raw input values. These changes have not yet been
  /// validated or parsed.
  final Map<FK, dynamic> _changes;

  /// A map of validated and parsed field values.
  /// Populated after a successful [apply] operation.
  final Map<FK, dynamic> _values;

  /// A map of validation errors. Keys are field identifiers (`FK`), and
  /// values are sets of [ValidationError] objects for that field.
  /// Populated after an [apply] operation if validation fails.
  final Map<FK, Set<ValidationError<FK>>> _errors;

  /// Returns the set of field definitions for this form.
  Set<FieldDefinition<dynamic, FK>> get fieldDefinitions => _fields;

  /// Returns a map of pending changes.
  Map<FK, dynamic> get changes => _changes;

  /// Returns a map of validated and parsed field values.
  Map<FK, dynamic> get values => _values;

  /// Returns a map of validation errors.
  Map<FK, Set<ValidationError<FK>>> get errors => _errors;

  /// Returns an indicator if the form contains any errors;
  bool get hasErrors => _errors.isNotEmpty;

  /// Returns an indicator if the form is valid.
  bool get isValid => !hasErrors && _values.isNotEmpty;

  /// Updates the form with a new value for a specific field.
  ///
  /// This method records the change but does not immediately validate or apply it.
  /// Returns a new [Form] instance with the updated changes.
  ///
  /// - [change]: The change to be added to the form.
  ///
  /// Example:
  /// ```dart
  /// enum MyFormKeys { name }
  /// final nameField = FieldDefinition.string(name: MyFormKeys.name);
  /// var form = Form<MyFormKeys>(fields: {nameField});
  /// form = form.change(FieldChange(MyFormKeys.name, 'Jane Doe'));
  /// print(form.changes[MyFormKeys.name]); // Output: Jane Doe
  /// ```
  Form<FK> addChange(FieldChange<FK> change) {
    final newChanges = Map<FK, dynamic>.from(_changes);
    newChanges[change.field] = _fields
        .firstWhere((f) => f.name == change.field)
        .parser(change.value); // Parse the value immediately

    return Form.internal(
      fields: _fields,
      changes: newChanges, // Will be made unmodifiable by Form.internal
      values: const {}, // Reset values on change
      errors: _errors,
    );
  }

  /// Updates the form with multiple changes at once.
  /// See [addChange] for details on how changes are applied.
  Form<FK> addChanges(List<FieldChange<FK>> changes) {
    assert(changes.isNotEmpty, 'Changes should not be empty');
    return changes.fold(this, (form, change) => this.addChange(change));
  }

  /// Returns the current change value of the specified field.
  ///
  /// This method returns the value that the field [field] is being changed to.
  /// Use this method to access the new value of a field during a validation or
  /// before the change is committed.
  ///
  /// Example:
  /// ```dart
  /// final newValue = changeOf<String>(MyFormFields.name);
  /// ```
  ///
  /// Type parameter [T] should match the type of the field's value.
  ///
  /// Returns the current change value for the specified field.
  T changeOf<T>(FK field) {
    final value = changeOfNullable<T>(field);
    if (value == null) {
      throw ArgumentError('$field is not a nullable type');
    } else {
      return value as T;
    }
  }

  /// Returns the latest value of the nullable field identified by the given field key.
  ///
  /// This method retrieves the current value of a nullable field from the form state.
  /// It's useful for accessing the most recent value of a field that may be null.
  ///
  /// Example:
  /// ```dart
  /// final email = form.changeOfNullable(FormFields.email);
  /// if (email != null) {
  ///   // Use the email value
  /// }
  /// ```
  ///
  /// - Parameter [field]: The key that identifies the form field.
  /// - Returns: The current value of the field, or null if the field is not set or is explicitly null.
  T? changeOfNullable<T>(FK field) {
    return _changes[field] as T?;
  }

  /// Validates all pending changes against their respective [FieldDefinition] rules
  /// and parses them into typed values if validation passes.
  ///
  /// Returns a new [Form] instance reflecting the outcome:
  /// - If validation fails for any field, the `errors` map in the returned [Form]
  ///   will be populated.
  /// - If validation passes for all fields, the `values` map will be populated
  ///   with the parsed, typed values, and `errors` will be empty.
  ///
  /// Asserts that `_fields` is not empty. If `_changes` is empty, returns `this`.
  ///
  /// Example:
  /// ```dart
  /// enum MyFormKeys { age }
  /// // Validator that checks if age is 18 or older
  /// Future<Set<ValidationError<MyFormKeys>>> validateAge(int? age) async {
  ///   if (age != null && age < 18) {
  ///     return {MinAgeError(field: MyFormKeys.age, minAge: 18)};
  ///   }
  ///   return {};
  /// }
  /// final ageField = FieldDefinition.integer(name: MyFormKeys.age, validator: validateAge);
  /// var form = Form<MyFormKeys>(fields: {ageField});
  /// form = form.change(field: MyFormKeys.age, value: '17');
  /// form = await form.apply();
  /// if (form.errors.isNotEmpty) {
  ///   print(form.errors[MyFormKeys.age]); // Output: {Instance of 'MinAgeError'}
  /// }
  /// ```
  Future<Form<FK>> apply() async {
    if (_changes.isEmpty) {
      return this;
    }
    final errors = <FK, Set<ValidationError<FK>>>{};
    final values = <FK, dynamic>{};

    // Validate each field definition against the corresponding change (if any)
    for (final fieldDef in _fields) {
      final fieldName = fieldDef.name;
      // Get the raw value from changes, or null if not present (field.validate handles this)
      final rawValue = _changes[fieldName] ?? fieldDef.defaultValue?.call();
      try {
        final fieldErrors = await fieldDef.validate(rawValue, this);

        if (fieldErrors.isNotEmpty) {
          errors.update(
            fieldName,
            (existingErrors) => existingErrors..addAll(fieldErrors),
            ifAbsent: () => fieldErrors,
          );
        } else {
          // If no errors and the field was changed, parse it.
          // If the field was not changed but has a default value,
          // the validation step would have used the default value.
          // Here, we only parse if there was an explicit change that validated successfully.
          // Or, if the field has a default and wasn't in changes, but we want to populate it.
          // The current logic in `fieldDef.validate` uses `change ?? defaultValue?.call()`
          // for validation. If validation passes, we parse that same effective value.
          if (rawValue != null || _changes.containsKey(fieldName)) {
            // Ensure we parse if it was an explicit null change or has a value
            final parsedValue = fieldDef.parser(rawValue);
            values[fieldName] = parsedValue;
          }
        }
      } catch (e) {
        errors.update(
          fieldName,
          (existingErrors) => existingErrors
            ..add(GenericParsingError(field: fieldName, cause: e.toString())),
          ifAbsent: () =>
              {GenericParsingError(field: fieldName, cause: e.toString())},
        );
      }
    }
    // If after processing all fields, any field that was in `_changes`
    // did not result in an error OR a value (e.g. a nullable field changed to null,
    // and parser returned null), we should ensure it's represented in `values` if no errors.
    if (errors.isEmpty) {
      _changes.forEach((key, value) {
        if (!values.containsKey(key)) {
          // This handles cases where a field was explicitly set to null
          // and the parser correctly returned null, and there were no validation errors.
          // If the field definition's parser can return null, it should be in values.
          final fieldDef = _fields.firstWhere((f) => f.name == key);
          values[key] = fieldDef.parser(value);
        }
      });
    }

    final result = _getResult(errors, values);
    // This assertion might be too strict if a field can have a valid parsed value
    // but also informational "warnings" (which would be a type of ValidationError).
    // For now, it assumes any error means the value is not considered "validly parsed".
    // However, if a field has an error, its value should not be in `result._values`.
    // The `_getResult` logic already handles this: if errors is not empty, values are cleared.
    // The main concern is if `errors` map has entries but `values` map also has entries for *different* fields.
    // The current logic: if ANY error exists, ALL values are discarded for the `_getResult`.
    // This assertion should hold based on `_getResult`.
    assert(
      !(result._errors.isNotEmpty && result._values.isNotEmpty),
      'Invalid state: errors map should be empty if values map is populated, and vice-versa based on _getResult.',
    );
    return result;
  }

  /// Internal helper to construct the final Form state after [apply].
  /// If [errors] is not empty, the returned Form will have these errors and
  /// the original `_values` (or empty if no prior values).
  /// If [errors] is empty, the returned Form will have the new [values]
  /// and an empty error map.
  Form<FK> _getResult(
    Map<FK, Set<ValidationError<FK>>> errors,
    Map<FK, dynamic> newValues,
  ) {
    if (errors.values.any((fieldErrors) => fieldErrors.isNotEmpty)) {
      // Check if any field actually has errors
      return Form.internal(
        fields: _fields,
        changes: _changes, // Keep original changes that led to this state
        values: _values, // Revert to original values if there were errors
        errors: errors, // Populate with the new errors
      );
    } else {
      // No errors, so update values and clear errors
      final allValues = Map<FK, dynamic>.from(_values)..addAll(newValues);
      return Form.internal(
        fields: _fields,
        changes: _changes, // Keep original changes
        values: allValues, // Populate with the new successfully parsed values
        errors: const {}, // Clear errors
      );
    }
  }

  @override
  List<Object?> get props => [
        _fields,
        _changes,
        _values,
        _errors,
      ];

  @override
  String toString() {
    return 'Form{fields: $_fields, changes: $_changes, values: $_values, errors: $_errors}';
  }
}

/// Represents a change to a specific field in the form.
class FieldChange<FK> extends Equatable {
  /// Creates a [FieldChange] for the given [field] and [value].
  const FieldChange(this.field, this.value);

  /// The field key (`FK`) that this change applies to.
  final FK field;

  /// The new value for the field.
  final dynamic value;

  @override
  List<Object?> get props => [field, value];
}

/// A validation error indicating that a required field is missing a value.
class IsRequired<FK extends Enum> extends ValidationError<FK> {
  /// Creates an [IsRequired] error for the given [field].
  const IsRequired({required super.field});

  @override
  String printable() {
    return '$fieldName is required.';
  }

  @override
  List<Object?> get props => [super.field];
}

/// A generic validation error for parsing issues.
class GenericParsingError<FK extends Enum> extends ValidationError<FK> {
  /// Creates a [GenericParsingError].
  const GenericParsingError({required super.field, required this.cause});

  /// The cause of the parsing error (e.g., exception message).
  final String cause;

  @override
  String printable() {
    final fieldName = super.field.toString().split('.').last;
    return 'Invalid format for $fieldName: $cause';
  }

  @override
  List<Object?> get props => [super.field, cause];
}

/// An abstract class for representing validation errors.
///
/// Custom validation errors should extends this class to provide
/// specific error details and user-friendly messages. As well as
/// providing compile-time type safety for all cases handled.
///
/// For this reason, we don't provide built-in error types.
///
/// Example:
/// ```dart
/// enum SignupKeys { email, password }
/// sealed abstract class SignupFormErrors extends ValidationError<SignupKeys> {}
/// class EmailFormatError extends SignupFormErrors {
///  EmailFormatError() : super(field: SignupKeys.email);
/// }
///
/// class PasswordTooShortError extends SignupFormErrors {
/// PasswordTooShortError() : super(field: SignupKeys.password);
/// }
/// ...
///
/// final message = swtich (error) {
///  case EmailFormatError => print('handle email format error');
///  case PasswordTooShortError => print('handle password too short error');
///  // no default case needed, all cases are handled
///  // compiler will ensure all cases are covered
/// }
/// ```
///
/// `FK` is an enum type that identifies the field associated with the error.
///
/// Example:
/// ```dart
/// enum MyFormKeys { password }
///
/// class MinLengthError<FK extends Enum> extends ValidationError<FK> {
///   final int minLength;
///   MinLengthError({required FK field, required this.minLength}) : super(field: field);
///
///   @override
///   String printable() =>
///       '${field.toString().split('.').last} must be at least $minLength characters long.';
/// }
///
/// final error = MinLengthError(field: MyFormKeys.password, minLength: 8);
/// print(error.printable()); // Output: password must be at least 8 characters long.
/// ```
abstract class ValidationError<FK extends Enum> extends Equatable {
  /// Creates a base validation error.
  /// - [field]: The field key (`FK`) associated with this error.
  const ValidationError({required this.field});

  /// The identifier of the field to which this error pertains.
  final FK field;

  /// Extracts a more friendly name for the field from its enum value.
  String get fieldName => field.toString().split('.').last;

  /// Returns a human-readable string representation of the validation error.
  ///
  /// By default, it returns the runtime type of the error class.
  /// It's recommended to override this in subclasses for more descriptive messages.
  String printable() {
    return runtimeType.toString();
  }

  @override
  String toString() {
    return printable();
  }
}

/// A function type that validates a value of type [T] and returns a
/// `Future<Set<ValidationError<FK>>>`.
///
/// The returned set should be empty if validation passes, or contain one or
/// more [ValidationError] instances if it fails.
///
/// - [T]: The type of the value to validate.
/// - [FK]: The enum type used for field keys.
///
/// Example:
/// ```dart
/// enum MyFormKeys { age }
///
/// // Custom error
/// class TooYoungError<FK extends Enum> extends ValidationError<FK> {
///   TooYoungError({required FK field}) : super(field: field);
///   @override
///   String printable() => 'Must be 18 or older.';
/// }
///
/// // Validator function
/// Validator<int?, MyFormKeys> validateAdultAge = (int? age, Form<MyFormKeys> form) async {
///   if (age != null && age < 18) {
///     return {TooYoungError(field: MyFormKeys.age)};
///   }
///   return {}; // Empty set means validation passed
/// };
///
/// // Usage (e.g., with FieldDefinition)
/// final ageField = FieldDefinition.nullableInteger(
///   name: MyFormKeys.age,
///   validator: validateAdultAge,
/// );
/// ```
typedef Validator<T, FK extends Enum> = Future<Set<ValidationError<FK>>>
    Function(T value, Form<FK> form);

/// Combines multiple validators of the same type [T] into a single validator function.
///
/// It runs all provided [validators] and aggregates their errors.
///
/// - [validators]: A `Set` of [Validator<T, FK>] functions.
///
/// Returns a new [Validator<T, FK>] that executes each validator in the set
/// and collects all reported [ValidationError]s.
///
/// Example:
/// ```dart
/// enum MyFormKeys { username }
///
/// // Individual validators
/// Future<Set<ValidationError<MyFormKeys>>> validateMinLength(String value, Form<MyFormKeys> form) async {
///   if (value.length < 3) return {MinLengthError(field: MyFormKeys.username, minLength: 3)};
///   return {};
/// }
/// Future<Set<ValidationError<MyFormKeys>>> validateNoSpecialChars(String value, Form<MyFormKeys> form) async {
///   if (value.contains('!')) return {SpecialCharError(field: MyFormKeys.username)};
///   return {};
/// }
///
/// // Combined validator
/// final combinedUsernameValidator = validateMany<String, MyFormKeys>({
///   validateMinLength,
///   validateNoSpecialChars,
/// });
///
/// // Usage
/// final usernameField = FieldDefinition.string(
///   name: MyFormKeys.username,
///   validator: combinedUsernameValidator,
/// );
/// ```
Validator<T, FK> validateMany<T, FK extends Enum>(
  Set<Validator<T, FK>> validators,
) {
  return (T value, Form<FK> form) async {
    final errors = <ValidationError<FK>>{};
    for (final validator in validators) {
      final errorSet = await validator(value, form);
      errors.addAll(errorSet);
    }
    return errors;
  };
}

/// Defines the properties, validation logic, and parsing behavior for a single field
/// in a [Form].
///
/// - [T]: The expected type of the field's value after parsing.
/// - [FK]: The enum type used for field keys, uniquely identifying this field.
///
/// Use the static factory methods like [FieldDefinition.string],
/// [FieldDefinition.integer], etc., to create instances for common types.
class FieldDefinition<T, FK extends Enum> extends Equatable {
  /// The raw constructor for creating a [FieldDefinition].
  /// It's generally recommended to use the typed factory constructors
  /// (e.g., [FieldDefinition.string], [FieldDefinition.integer]) instead.
  ///
  /// - [name]: The unique key (`FK`) for this field.
  /// - [isRequired]: Whether this field must have a value. If `true`, and
  ///   both the input `change` and `defaultValue` are `null`, an [IsRequired]
  ///   error is generated.
  /// - [defaultValue]: A function that provides a default value for this field
  ///   if no input is given. This default value is used during validation if
  ///   the input `change` is `null`.
  /// - [parser]: A function that converts a raw dynamic input value (typically
  ///   from user input) into the expected typed value `T`. This function is
  ///   called by validation and and when the form is applied.
  /// - [validator]: An optional [Validator] function that performs custom
  ///   validation on the (potentially defaulted) parsed value.
  const FieldDefinition.raw({
    required this.name,
    required this.isRequired,
    required this.defaultValue,
    required this.parser,
    this.validator,
  });

  /// The unique key/name of this field.
  final FK name;

  /// Whether this field is required.
  /// If true, a value must be provided either directly or via [defaultValue].
  final bool isRequired;

  /// A function that returns a default value for the field if no explicit
  /// value is provided. Can be null if no default value is applicable.
  final T Function()? defaultValue;

  /// A function that parses a raw dynamic value (e.g., a string from a text input)
  /// into the field's target type [T].
  final T Function(dynamic rawValue) parser;

  /// An optional asynchronous validator function for this field.
  /// It receives the parsed value (or default value if input was null)
  /// and should return a set of [ValidationError]s.
  final Validator<T, FK>? validator;

  /// Validates a given [change] (raw input value) for this field.
  ///
  /// 1. Checks for `isRequired` if [change] and [defaultValue] are both null.
  /// 2. If a [validator] is provided, it parses the [change] (or uses
  ///    [defaultValue] if [change] is null) and then runs the [validator]
  ///    on the parsed value.
  ///
  /// Returns a `Future<Set<ValidationError<FK>>>` which is empty if validation
  /// passes, or contains errors if it fails.
  ///
  /// This method is typically called by [Form.apply].
  @visibleForTesting
  Future<Set<ValidationError<FK>>> validate(
    dynamic change,
    Form<FK> parent,
  ) async {
    final errors = <ValidationError<FK>>{};

    // Step 1: Handle isRequired constraint
    if (isRequired && change == null && defaultValue == null) {
      errors.add(IsRequired(field: name));
      return errors; // Early exit if required field is missing and no default
    }

    // Step 2: Prepare value for validation (use change or default)
    // The rawValue is what will be parsed if validation proceeds.
    // If `change` is null, `defaultValue?.call()` is used.
    // If `change` is not null, `change` is used.
    final rawValueForValidation = change ?? defaultValue?.call();

    // Step 3: Perform validation using the validator, if one exists
    if (validator != null) {
      // We need to parse the rawValueForValidation before passing it to the typed validator
      // However, the validator itself expects the *parsed* type T.
      // The parser should handle the rawValueForValidation.
      // If rawValueForValidation is null and the type T is nullable, parser should handle it.
      // If rawValueForValidation is null and type T is non-nullable, parser might throw or handle.

      // Let's assume the value passed to the validator should be of type T.
      // So, we must parse first.
      final valueForTypedValidator = parser(rawValueForValidation);

      final validationErrors = await validator!(valueForTypedValidator, parent);
      errors.addAll(validationErrors);
    }
    return errors;
  }

  @override
  String toString() {
    return 'FieldDefinition{name: $name, isRequired: $isRequired, '
        'hasDefaultValue: ${defaultValue != null}, '
        'hasValidator: ${validator != null}}';
  }

  // ---- Factories ----

  /// Creates a [FieldDefinition] for a [String] value.
  ///
  /// - [name]: The field's unique key.
  /// - [isRequired]: Defaults to `false`.
  /// - [validator]: Optional custom validator for the string.
  /// - [defaultValue]: Optional function to provide a default string value.
  /// The parser trims whitespace from the input string.
  ///
  /// Example:
  /// ```dart
  /// enum MyFormKeys { username }
  /// final usernameField = FieldDefinition.string(
  ///   name: MyFormKeys.username,
  ///   isRequired: true,
  ///   validator: (value, form) async => value.length < 3 ? {MinLengthError(field: MyFormKeys.username, minLength:3)} : {},
  /// );
  /// ```
  static FieldDefinition<String, K> string<K extends Enum>({
    required K name,
    bool isRequired = false,
    Validator<String, K>? validator,
    String Function()? defaultValue,
  }) {
    return FieldDefinition.raw(
      name: name,
      isRequired: isRequired,
      validator: validator,
      defaultValue: defaultValue,
      parser: (rawValue) {
        if (rawValue is String) {
          return rawValue.trim();
        }
        if (rawValue == null) {
          // If a non-nullable string field is not required and has no default,
          // and rawValue is null, this parser would throw on .toString().
          // This case should ideally be caught by `isRequired` or a `defaultValue`.
          // If `isRequired` is false and `defaultValue` is null, `rawValue` could be null.
          // A non-nullable String field definition should typically have `isRequired: true` or a `defaultValue`.
          // For robustness, if rawValue is null for a non-nullable String, we might throw
          // or return an empty string, depending on desired behavior.
          // Given `isRequired` and `defaultValue` handle presence, if we reach here with null
          // for a non-nullable String, it implies a configuration that might lead to issues.
          // However, `FieldDefinition.string` is for `String`, not `String?`.
          // If `rawValue` is `null` and `defaultValue` is also `null`,
          // and `isRequired` is `false`, then `parser(null)` will be called.
          // `null.toString()` is "null". `trim()` works.
          // This seems acceptable; the validator would receive "null".
          return rawValue?.toString().trim() ?? (defaultValue?.call() ?? '');
        }
        return rawValue.toString().trim();
      },
    );
  }

  /// Creates a [FieldDefinition] for an [int] value.
  ///
  /// - [name]: The field's unique key.
  /// - [isRequired]: Defaults to `false`.
  /// - [validator]: Optional custom validator for the integer.
  /// - [defaultValue]: Optional function to provide a default int value.
  /// The parser attempts to parse the input string as an integer.
  /// Throws [FormatException] if parsing fails and no `defaultValue` can be used.
  ///
  /// Example:
  /// ```dart
  /// enum MyFormKeys { age }
  /// final ageField = FieldDefinition.integer(
  ///   name: MyFormKeys.age,
  ///   defaultValue: () => 18,
  /// );
  /// ```
  static FieldDefinition<int, K> integer<K extends Enum>({
    required K name,
    bool isRequired = false,
    Validator<int, K>? validator,
    int Function()? defaultValue,
  }) {
    return FieldDefinition.raw(
      name: name,
      isRequired: isRequired,
      validator: validator,
      defaultValue: defaultValue,
      parser: (rawValue) {
        if (rawValue == null) {
          if (defaultValue != null) return defaultValue();
          // This case should ideally be handled by `isRequired` if T is non-nullable.
          // If int is non-nullable, rawValue being null here implies isRequired=false and no default.
          // int.tryParse(null.toString()) would be int.tryParse("null") -> null.
          throw const FormatException(
            'Invalid integer value: null provided for non-nullable int without default.',
          );
        }
        if (rawValue is int) {
          return rawValue; // Already an int
        }
        final trimmedValue = rawValue.toString().trim();
        final maybeInt = int.tryParse(trimmedValue);
        if (maybeInt != null) return maybeInt;
        if (defaultValue != null) return defaultValue();
        throw FormatException('Invalid integer value: $rawValue');
      },
    );
  }

  /// Creates a [FieldDefinition] for a [double] value (float point).
  ///
  /// - [name]: The field's unique key.
  /// - [isRequired]: Defaults to `false`.
  /// - [validator]: Optional custom validator for the double.
  /// - [defaultValue]: Optional function to provide a default double value.
  /// The parser attempts to parse the input string as a double.
  /// Throws [FormatException] if parsing fails and no `defaultValue` can be used.
  ///
  /// Example:
  /// ```dart
  /// enum MyFormKeys { price }
  /// final priceField = FieldDefinition.floatPoint(
  ///   name: MyFormKeys.price,
  ///   isRequired: true,
  /// );
  /// ```
  static FieldDefinition<double, K> floatPoint<K extends Enum>({
    required K name,
    bool isRequired = false,
    Validator<double, K>? validator,
    double Function()? defaultValue,
  }) {
    return FieldDefinition.raw(
      name: name,
      isRequired: isRequired,
      validator: validator,
      defaultValue: defaultValue,
      parser: (rawValue) {
        if (rawValue == null) {
          if (defaultValue != null) return defaultValue();
          throw const FormatException(
            'Invalid double value: null provided for non-nullable double without default.',
          );
        }
        if (rawValue is double) {
          return rawValue; // Already a double
        }
        final trimmedValue = rawValue.toString().trim();
        final maybeDouble = double.tryParse(trimmedValue);
        if (maybeDouble != null) return maybeDouble;
        if (defaultValue != null) return defaultValue();
        throw FormatException('Invalid double value: $rawValue');
      },
    );
  }

  /// Creates a [FieldDefinition] for a boolean value.
  /// - [name]: The field's unique key.
  /// - [isRequired]: Defaults to `false`.
  /// - [validator]: Optional custom validator for the boolean.
  /// - [defaultValue]: Optional function to provide a default boolean value.
  /// The parser converts the input to a boolean value.
  /// Example:
  /// ```dart
  /// enum MyFormKeys { isActive }
  /// final isActiveField = FieldDefinition.boolean(
  ///   name: MyFormKeys.isActive,
  ///   isRequired: true,
  ///   defaultValue: () => false,
  /// );
  /// ```
  static FieldDefinition<bool, K> boolean<K extends Enum>({
    required K name,
    bool isRequired = false,
    Validator<bool, K>? validator,
    bool Function()? defaultValue,
  }) {
    return FieldDefinition.raw(
      name: name,
      isRequired: isRequired,
      validator: validator,
      defaultValue: defaultValue,
      parser: (rawValue) {
        if (rawValue == null) {
          if (defaultValue != null) return defaultValue();
          throw const FormatException(
            'Invalid boolean value: null provided for non-nullable bool without default.',
          );
        }
        if (rawValue is bool) {
          return rawValue; // Already a boolean
        }
        // Convert to boolean
        final trimmedValue = rawValue.toString().trim().toLowerCase();
        if (trimmedValue == 'true' || trimmedValue == '1') {
          return true;
        } else if (trimmedValue == 'false' || trimmedValue == '0') {
          return false;
        }
        throw FormatException('Invalid boolean value: $rawValue');
      },
    );
  }

  /// Creates a [FieldDefinition] for a nullable [String] value (`String?`).
  ///
  /// - [name]: The field's unique key.
  /// - [isRequired]: Defaults to `false`. Note: for a nullable type, `isRequired`
  ///   typically means a value (even if `null`) must be explicitly provided if the
  ///   field itself is part of the form submission process. However, the current
  ///   `validate` logic for `isRequired` checks `change == null && defaultValue == null`.
  ///   For nullable fields, `null` is a valid value.
  /// - [validator]: Optional custom validator for the `String?`.
  /// The parser trims whitespace if the input is not null. Returns `null` if input is `null`.
  ///
  /// Example:
  /// ```dart
  /// enum MyFormKeys { middleName }
  /// final middleNameField = FieldDefinition.nullableString(
  ///   name: MyFormKeys.middleName,
  /// );
  /// ```
  static FieldDefinition<String?, K> nullableString<K extends Enum>({
    required K name,
    bool isRequired =
        false, // For nullable, isRequired might mean "presence in form" vs "non-null value"
    Validator<String?, K>? validator,
    // No defaultValue parameter here, it defaults to `() => null` internally.
  }) {
    return FieldDefinition.raw(
      name: name,
      isRequired: isRequired,
      // Be mindful of `isRequired` interpretation for nullable types.
      validator: validator,
      defaultValue: () => null,
      // Explicitly default to null for nullable type
      parser: (rawValue) {
        if (rawValue == null) return null;
        // If rawValue is an empty string, it should become an empty string, not null.
        // If rawValue is "  ", it becomes "".
        return rawValue.toString().trim();
      },
    );
  }

  /// Creates a [FieldDefinition] for a nullable [int] value (`int?`).
  ///
  /// - [name]: The field's unique key.
  /// - [isRequired]: Defaults to `false`. (See note on `nullableString` for `isRequired`).
  /// - [validator]: Optional custom validator for the `int?`.
  /// The parser attempts to parse the input string as an int if not null.
  /// Returns `null` if input is `null` or parsing fails.
  ///
  /// Example:
  /// ```dart
  /// enum MyFormKeys { optionalScore }
  /// final scoreField = FieldDefinition.nullableInteger(
  ///   name: MyFormKeys.optionalScore,
  /// );
  /// ```
  static FieldDefinition<int?, K> nullableInteger<K extends Enum>({
    required K name,
    bool isRequired = false,
    Validator<int?, K>? validator,
  }) {
    return FieldDefinition.raw(
      name: name,
      isRequired: isRequired,
      defaultValue: () => null,
      validator: validator,
      parser: (rawValue) {
        if (rawValue == null) return null;
        // Treat empty string as null for nullable int
        if (rawValue.toString().trim().isEmpty) return null;
        return int.tryParse(rawValue.toString().trim());
      },
    );
  }

  /// Creates a [FieldDefinition] for a nullable [double] value (`double?`).
  ///
  /// - [name]: The field's unique key.
  /// - [isRequired]: Defaults to `false`. (See note on `nullableString` for `isRequired`).
  /// - [validator]: Optional custom validator for the `double?`.
  /// The parser attempts to parse the input string as a double if not null.
  /// Returns `null` if input is `null` or parsing fails.
  ///
  /// Example:
  /// ```dart
  /// enum MyFormKeys { optionalMeasurement }
  /// final measurementField = FieldDefinition.nullableDouble(
  ///   name: MyFormKeys.optionalMeasurement,
  /// );
  /// ```
  static FieldDefinition<double?, K> nullableDouble<K extends Enum>({
    required K name,
    bool isRequired = false,
    Validator<double?, K>? validator,
  }) {
    return FieldDefinition.raw(
      name: name,
      isRequired: isRequired,
      defaultValue: () => null,
      validator: validator,
      parser: (rawValue) {
        if (rawValue == null) return null;
        // Treat empty string as null for nullable double
        if (rawValue.toString().trim().isEmpty) return null;
        return double.tryParse(rawValue.toString().trim());
      },
    );
  }

  @override
  List<Object?> get props => [
        name,
        isRequired,
      ];
}
